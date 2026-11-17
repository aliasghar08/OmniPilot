package com.dartnexuslab.omnipilot

import android.accessibilityservice.AccessibilityButtonController
import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Path
import android.graphics.Rect
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.ContactsContract
import android.provider.Settings
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import android.widget.Toast
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class AttendanceAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "AttendanceA11y"

        @Volatile
        var instance: AttendanceAccessibilityService? = null
            private set

        val isRunning: Boolean
            get() = instance != null

        @Volatile
        var lastExternalPackage: String? = null
            private set
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var buttonCallback: Any? = null

    private val ignoredPackages = setOf(
        "com.dartnexuslab.omnipilot",
        "com.android.systemui",
        "com.google.android.inputmethod.latin",
        "com.samsung.android.honeyboard",
        "com.touchtype.swiftkey",
        "com.sohu.inputmethod.sogou",
        "com.baidu.input",
        "com.sec.android.app.launcher",
        "com.miui.home",
        "com.oppo.launcher",
        "com.vivo.launcher",
        "com.huawei.android.launcher",
        "com.transsion.XOSLauncher",
        "com.transsion.hilauncher",
        "com.android.inputmethod.latin"
    )

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d(TAG, "AttendanceAccessibilityService Connected")

        try {
            // Programmatically enforce accessibility flags on OEM skins (Infinix XOS / Transsion)
            val info = serviceInfo ?: android.accessibilityservice.AccessibilityServiceInfo()
            info.eventTypes = AccessibilityEvent.TYPES_ALL_MASK
            info.feedbackType = android.accessibilityservice.AccessibilityServiceInfo.FEEDBACK_GENERIC
            var flags = android.accessibilityservice.AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or
                         android.accessibilityservice.AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                         android.accessibilityservice.AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                         android.accessibilityservice.AccessibilityServiceInfo.FLAG_REQUEST_ENHANCED_WEB_ACCESSIBILITY
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                flags = flags or android.accessibilityservice.AccessibilityServiceInfo.FLAG_REQUEST_ACCESSIBILITY_BUTTON
            }
            info.flags = flags
            info.notificationTimeout = 50L
            this.serviceInfo = info
        } catch (e: Exception) {
            Log.w(TAG, "Failed to apply programmatic serviceInfo: ${e.message}")
        }

        // Register hardware / navigation accessibility button & shortcut callback
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val cb = object : AccessibilityButtonController.AccessibilityButtonCallback() {
                    override fun onClicked(controller: AccessibilityButtonController) {
                        super.onClicked(controller)
                        Log.d(TAG, "Accessibility button / shortcut triggered")
                        handleAccessibilityShortcutTriggered()
                    }

                    override fun onAvailabilityChanged(
                        controller: AccessibilityButtonController,
                        available: Boolean
                    ) {
                        super.onAvailabilityChanged(controller, available)
                        Log.d(TAG, "Accessibility button availability changed: $available")
                    }
                }
                accessibilityButtonController.registerAccessibilityButtonCallback(cb)
                buttonCallback = cb
                Log.d(TAG, "Registered AccessibilityButtonCallback successfully")
            } catch (e: Exception) {
                Log.w(TAG, "Failed to register AccessibilityButtonCallback: ${e.message}")
            }
        }

    /**
     * Responds immediately when the user taps the Android system accessibility button
     * or triggers the Accessibility Shortcut.
     */
    fun handleAccessibilityShortcutTriggered() {
        mainHandler.post {
            try {
                val intent = Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                }
                startActivity(intent)
            } catch (e: Exception) {
                Log.e(TAG, "Error handling accessibility shortcut trigger: ${e.message}", e)
            }
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val pkg = event?.packageName?.toString() ?: return
        if (pkg.contains("permissioncontroller", ignoreCase = true)) {
            sendBotFeedback("⚠️ System permission prompt detected—please tap Allow on screen to continue")
            return
        }
        if (pkg.isNotEmpty() && !ignoredPackages.contains(pkg)) {
            lastExternalPackage = pkg
        }
    }

    override fun onInterrupt() {
        Log.w(TAG, "AttendanceAccessibilityService Interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && buttonCallback != null) {
            try {
                val cb = buttonCallback as? AccessibilityButtonController.AccessibilityButtonCallback
                if (cb != null) {
                    accessibilityButtonController.unregisterAccessibilityButtonCallback(cb)
                }
            } catch (_: Exception) {}
            buttonCallback = null
        }
        if (instance == this) {
            instance = null
        }
        Log.d(TAG, "AttendanceAccessibilityService Destroyed")
    }

    /**
     * Collects root nodes, prioritizing external apps over our own app when [preferExternal] is true.
     */
    private fun getTargetRoots(preferExternal: Boolean = true): List<AccessibilityNodeInfo> {
        return getTargetRootsInternal(preferExternal, retry = true)
    }

    private fun getTargetRootsInternal(preferExternal: Boolean, retry: Boolean): List<AccessibilityNodeInfo> {
        val externalRoots = mutableListOf<AccessibilityNodeInfo>()
        val selfRoots = mutableListOf<AccessibilityNodeInfo>()
        val myPkg = packageName

        try {
            for (window in windows) {
                if (window.type == AccessibilityWindowInfo.TYPE_SYSTEM ||
                    window.type == AccessibilityWindowInfo.TYPE_INPUT_METHOD
                ) {
                    continue
                }
                val r = window.root ?: continue
                val pkg = r.packageName?.toString() ?: ""
                if (pkg == myPkg) {
                    selfRoots.add(r)
                } else if (!ignoredPackages.contains(pkg)) {
                    externalRoots.add(r)
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error reading interactive windows: ${e.message}")
        }

        rootInActiveWindow?.let { activeRoot ->
            val pkg = activeRoot.packageName?.toString() ?: ""
            if (pkg == myPkg) {
                if (!selfRoots.contains(activeRoot)) selfRoots.add(0, activeRoot)
            } else if (!ignoredPackages.contains(pkg)) {
                if (!externalRoots.contains(activeRoot)) externalRoots.add(0, activeRoot)
            }
        }

        if (preferExternal && externalRoots.isEmpty() && retry && Looper.myLooper() != Looper.getMainLooper()) {
            try {
                Thread.sleep(120)
            } catch (_: InterruptedException) {}
            return getTargetRootsInternal(preferExternal, retry = false)
        }

        return if (preferExternal) {
            if (externalRoots.isNotEmpty()) externalRoots else selfRoots
        } else {
            externalRoots + selfRoots
        }
    }

    /**
     * Switches back to the last known external app if our own app is currently covering the screen.
     */
    fun ensureExternalAppFocused(): Boolean {
        val roots = getTargetRoots(preferExternal = true)
        val hasExternal = roots.any { it.packageName?.toString() != packageName }
        if (hasExternal) return true

        val targetPkg = lastExternalPackage
        if (!targetPkg.isNullOrEmpty() && targetPkg != packageName) {
            val launched = launchAppByPackageOrName(targetPkg, broadcastFeedback = false)
            if (launched) {
                try {
                    Thread.sleep(650)
                } catch (_: InterruptedException) {}
                return true
            }
        }

        // Fallback: navigate BACK once to dismiss our activity and reveal the previous app
        val backSuccess = performGlobalAction(GLOBAL_ACTION_BACK)
        if (backSuccess) {
            try {
                Thread.sleep(500)
            } catch (_: InterruptedException) {}
        }
        return backSuccess
    }

    /**
     * Legacy helper returning editable fields list for backward compatibility.
     */
    fun inspectActiveWindow(): List<Map<String, Any>> {
        val snapshot = getScreenSnapshot(preferExternal = true)
        @Suppress("UNCHECKED_CAST")
        return (snapshot["editableFields"] as? List<Map<String, Any>>) ?: emptyList()
    }

    /**
     * Full comprehensive snapshot of the active screen:
     * - activePackage, windowTitle, lastExternalPackage
     * - editableFields (with index, id, shortId, label, hint, text, actualValue, isShowingHint, isFocused, bounds)
     * - clickableElements (buttons, checkboxes, tabs, switches with index, label, id, isCheckable, isChecked, bounds)
     * - screenTexts (all readable static text on screen to check existing writes/confirmations/labels)
     */
    fun getScreenSnapshot(preferExternal: Boolean = true): Map<String, Any> {
        val roots = getTargetRoots(preferExternal = preferExternal)
        if (roots.isEmpty()) {
            return mapOf(
                "activePackage" to "",
                "lastExternalPackage" to (lastExternalPackage ?: ""),
                "windowTitle" to "",
                "editableFields" to emptyList<Map<String, Any>>(),
                "clickableElements" to emptyList<Map<String, Any>>(),
                "screenTexts" to emptyList<String>()
            )
        }

        val primaryRoot = roots.first()
        val activePackage = primaryRoot.packageName?.toString() ?: ""
        var windowTitle = ""
        try {
            windowTitle = windows.firstOrNull { it.root == primaryRoot }?.title?.toString() ?: ""
        } catch (_: Exception) {}

        val editableFields = mutableListOf<Map<String, Any>>()
        val clickableElements = mutableListOf<Map<String, Any>>()
        val screenTexts = mutableListOf<String>()

        for (root in roots) {
            // If we have external roots, skip our own overlay/app windows
            if (preferExternal && roots.size > 1 && root.packageName?.toString() == packageName) {
                continue
            }
            collectScreenSnapshot(root, editableFields, clickableElements, screenTexts)
        }

        return mapOf(
            "activePackage" to activePackage,
            "lastExternalPackage" to (lastExternalPackage ?: ""),
            "windowTitle" to windowTitle,
            "editableFields" to editableFields,
            "clickableElements" to clickableElements,
            "screenTexts" to screenTexts.distinct()
        )
    }

    private fun isNodeEditableInThirdPartyApps(node: AccessibilityNodeInfo): Boolean {
        if (node.isEditable) return true
        val className = node.className?.toString() ?: ""
        if (className.contains("EditText", ignoreCase = true) ||
            className.contains("AutoComplete", ignoreCase = true) ||
            className.contains("TextInput", ignoreCase = true) ||
            className.contains("SearchView", ignoreCase = true) ||
            className.contains("ComposeEditable", ignoreCase = true) ||
            className.contains("SearchAutoComplete", ignoreCase = true)
        ) {
            return true
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT && node.inputType != 0) {
            return true
        }
        val actions = node.actionList
        if (actions.any { it.id == AccessibilityNodeInfo.ACTION_SET_TEXT }) {
            return true
        }
        if (node.isFocused && (node.isFocusable || node.isClickable) &&
            (actions.any { it.id == AccessibilityNodeInfo.ACTION_PASTE } ||
             actions.any { it.id == AccessibilityNodeInfo.ACTION_SET_TEXT })
        ) {
            return true
        }
        return false
    }

    private fun collectScreenSnapshot(
        node: AccessibilityNodeInfo,
        editableList: MutableList<Map<String, Any>>,
        clickableList: MutableList<Map<String, Any>>,
        textList: MutableList<String>
    ) {
        val bounds = Rect()
        node.getBoundsInScreen(bounds)
        val hasValidBounds = bounds.width() > 0 && bounds.height() > 0

        val className = node.className?.toString() ?: ""
        val shortClass = className.substringAfterLast('.')
        val viewId = node.viewIdResourceName ?: ""
        val shortId = viewId.substringAfterLast('/')
        val isEditable = isNodeEditableInThirdPartyApps(node)

        val showingHint = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            node.isShowingHintText
        } else {
            false
        }

        val rawText = node.text?.toString()?.trim() ?: ""
        val hintText = node.hintText?.toString()?.trim() ?: ""
        val contentDesc = node.contentDescription?.toString()?.trim() ?: ""

        // Actual written value in an EditText (empty if Android is only displaying placeholder hintText)
        val actualValue = if (isEditable && showingHint) "" else rawText
        val resolvedLabel = resolveNodeLabel(node, hintText, contentDesc, shortId, showingHint, rawText)

        val boundsStr = "[${bounds.left},${bounds.top}][${bounds.right},${bounds.bottom}]"

        if (hasValidBounds && isEditable) {
            val idx = editableList.size
            val fieldMap = mutableMapOf<String, Any>(
                "index" to idx,
                "id" to viewId,
                "shortId" to shortId,
                "label" to resolvedLabel,
                "hint" to (if (hintText.isNotEmpty()) hintText else resolvedLabel),
                "text" to actualValue,
                "rawText" to rawText,
                "isShowingHint" to showingHint,
                "isPopulated" to actualValue.isNotEmpty(),
                "contentDescription" to contentDesc,
                "className" to shortClass,
                "isFocused" to node.isFocused,
                "isEnabled" to node.isEnabled,
                "bounds" to boundsStr,
                "centerX" to bounds.centerX(),
                "centerY" to bounds.centerY()
            )
            editableList.add(fieldMap)
        } else if (hasValidBounds && (node.isClickable || node.isCheckable)) {
            val clickableLabel = resolveClickableLabel(node, rawText, contentDesc, shortId)
            if (clickableLabel.isNotEmpty() || node.isCheckable) {
                val idx = clickableList.size
                val clickMap = mutableMapOf<String, Any>(
                    "index" to idx,
                    "id" to viewId,
                    "shortId" to shortId,
                    "label" to clickableLabel,
                    "text" to rawText,
                    "contentDescription" to contentDesc,
                    "className" to shortClass,
                    "isClickable" to node.isClickable,
                    "isCheckable" to node.isCheckable,
                    "isChecked" to node.isChecked,
                    "isSelected" to node.isSelected,
                    "isEnabled" to node.isEnabled,
                    "bounds" to boundsStr,
                    "centerX" to bounds.centerX(),
                    "centerY" to bounds.centerY()
                )
                clickableList.add(clickMap)
            }
        }

        if (hasValidBounds && rawText.isNotEmpty() && !showingHint) {
            textList.add(rawText)
        } else if (hasValidBounds && contentDesc.isNotEmpty() && !isEditable) {
            textList.add(contentDesc)
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            collectScreenSnapshot(child, editableList, clickableList, textList)
        }
    }

    /**
     * Resolves a human-friendly label for an EditText by inspecting hintText, child TextViews
     * (used by Jetpack Compose OutlinedTextField/TextField), labeledBy, parent TextInputLayout,
     * or adjacent sibling TextViews.
     */
    private fun resolveNodeLabel(
        node: AccessibilityNodeInfo,
        hintText: String,
        contentDesc: String,
        shortId: String,
        showingHint: Boolean,
        rawText: String
    ): String {
        if (hintText.isNotEmpty()) return hintText
        if (showingHint && rawText.isNotEmpty()) return rawText
        if (contentDesc.isNotEmpty()) return contentDesc

        // Jetpack Compose OutlinedTextField / TextField pattern:
        // The floating label is a child TextView inside the EditText node itself!
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val cClass = child.className?.toString() ?: ""
            if (cClass.contains("TextView", ignoreCase = true) && !child.isClickable) {
                val cText = child.text?.toString()?.trim() ?: ""
                if (cText.isNotEmpty() && cText != rawText && cText.length <= 60) {
                    return cText
                }
            }
        }

        val labeledBy = node.labeledBy
        if (labeledBy != null) {
            val lbl = labeledBy.text?.toString()?.trim() ?: labeledBy.contentDescription?.toString()?.trim() ?: ""
            if (lbl.isNotEmpty()) return lbl
        }

        // Check parent or grandparent (e.g., TextInputLayout or FrameLayout wrapper)
        var parent = node.parent
        var depth = 0
        while (parent != null && depth < 3) {
            val pHint = parent.hintText?.toString()?.trim() ?: ""
            if (pHint.isNotEmpty()) return pHint
            val pText = parent.text?.toString()?.trim() ?: ""
            if (pText.isNotEmpty() && pText != rawText) return pText
            val pDesc = parent.contentDescription?.toString()?.trim() ?: ""
            if (pDesc.isNotEmpty()) return pDesc

            // Check sibling TextViews inside the same parent container
            for (i in 0 until parent.childCount) {
                val sibling = parent.getChild(i) ?: continue
                if (sibling == node) continue
                val sClass = sibling.className?.toString() ?: ""
                if (sClass.contains("TextView", ignoreCase = true) && !sibling.isEditable) {
                    val sText = sibling.text?.toString()?.trim() ?: ""
                    if (sText.isNotEmpty() && sText.length <= 60) {
                        return sText
                    }
                }
            }
            parent = parent.parent
            depth++
        }

        return shortId.replace("_", " ").trim()
    }

    /**
     * Resolves the label of a clickable container (e.g. Button, FrameLayout, LinearLayout)
     * by checking its own text/description or recursively combining child TextView texts.
     */
    private fun resolveClickableLabel(
        node: AccessibilityNodeInfo,
        rawText: String,
        contentDesc: String,
        shortId: String
    ): String {
        if (rawText.isNotEmpty()) return rawText
        if (contentDesc.isNotEmpty()) return contentDesc

        val childTexts = mutableListOf<String>()
        collectChildTexts(node, childTexts, 0)
        if (childTexts.isNotEmpty()) {
            return childTexts.joinToString(" ").trim()
        }
        return shortId
    }

    private fun collectChildTexts(node: AccessibilityNodeInfo, out: MutableList<String>, depth: Int) {
        if (depth > 3) return
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val t = child.text?.toString()?.trim() ?: ""
            val d = child.contentDescription?.toString()?.trim() ?: ""
            if (t.isNotEmpty()) out.add(t)
            else if (d.isNotEmpty()) out.add(d)
            collectChildTexts(child, out, depth + 1)
        }
    }

    /**
     * Reads and checks existing writes across all editable fields on screen.
     */
    fun checkExistingWrites(targetKeys: List<String>? = null): Map<String, Any> {
        val snapshot = getScreenSnapshot(preferExternal = true)
        @Suppress("UNCHECKED_CAST")
        val fields = (snapshot["editableFields"] as? List<Map<String, Any>>) ?: emptyList()

        val summary = fields.map { f ->
            mapOf(
                "index" to (f["index"] ?: 0),
                "label" to (f["label"] ?: ""),
                "id" to (f["shortId"] ?: ""),
                "currentValue" to (f["text"] ?: ""),
                "isPopulated" to (f["isPopulated"] ?: false)
            )
        }

        val requestedMatches = mutableMapOf<String, Any>()
        if (!targetKeys.isNullOrEmpty()) {
            for (key in targetKeys) {
                val matched = summary.firstOrNull { item ->
                    val lbl = (item["label"]?.toString() ?: "").lowercase()
                    val id = (item["id"]?.toString() ?: "").lowercase()
                    val k = key.lowercase()
                    lbl.contains(k) || id.contains(k) || k.contains(lbl.takeIf { it.isNotEmpty() } ?: "___")
                }
                requestedMatches[key] = matched ?: mapOf("found" to false)
            }
        }

        return mapOf(
            "activePackage" to (snapshot["activePackage"] ?: ""),
            "totalFields" to fields.size,
            "populatedFieldsCount" to summary.count { it["isPopulated"] == true },
            "fields" to summary,
            "requestedMatches" to requestedMatches
        )
    }

    /**
     * Executes a bot action on [rootNode], wrapping execution in a try-catch-finally block
     * and guaranteeing a short status string sent back to FloatingBubbleService and Flutter.
     */
    fun executeBotAction(actionName: String, rootNode: AccessibilityNodeInfo?) {
        var feedback = "✅ Done: $actionName completed."
        try {
            feedback = if (rootNode == null) {
                "⚠️ Bot Error: Active screen unreadable."
            } else {
                val success = performNodeAction(rootNode)
                if (success) {
                    "✅ Done: $actionName completed."
                } else {
                    "⚠️ Bot Alert: Target fields not found."
                }
            }
        } catch (e: Exception) {
            feedback = "❌ Bot Failed: ${e.localizedMessage?.take(40) ?: "Unknown error"}"
        } finally {
            // Always broadcast feedback to Floating Bubble & Flutter UI
            sendBotFeedback(feedback)
        }
    }

    /**
     * Performs node click or smart autofill on [rootNode].
     */
    fun performNodeAction(rootNode: AccessibilityNodeInfo): Boolean {
        val editableEntries = mutableListOf<EditableNodeEntry>()
        collectEditableEntries(rootNode, editableEntries)
        if (editableEntries.isNotEmpty()) {
            val sampleValues = listOf("Ali Asghar", "1024", "Class 10-A", "+1555019283", "Present - Verified by Copilot")
            val payload = mutableMapOf<String, String>()
            for ((i, entry) in editableEntries.withIndex()) {
                val lbl = entry.label.lowercase()
                val value = when {
                    lbl.contains("bform") || lbl.contains("b-form") || lbl.contains("cnic") -> "35201-1234567-1"
                    lbl.contains("emis") -> "EMIS-5421"
                    lbl.contains("present") || lbl.contains("attendance") || lbl.contains("days") -> "24"
                    lbl.contains("first") -> "Ali"
                    lbl.contains("last") || lbl.contains("surname") -> "Asghar"
                    lbl.contains("name") || lbl.contains("student") -> "Ali Asghar"
                    lbl.contains("company") || lbl.contains("class") || lbl.contains("grade") || lbl.contains("school") -> "Class 10-A"
                    lbl.contains("phone") || lbl.contains("mobile") || lbl.contains("tel") -> "0300-1234567"
                    lbl.contains("roll") || lbl.contains("id") || lbl.contains("number") -> "CS-2026-044"
                    lbl.contains("email") || lbl.contains("mail") -> "aliasgharinnocent@yahoo.com"
                    lbl.contains("note") || lbl.contains("status") || lbl.contains("remark") -> "Good Standing (96% Attendance)"
                    else -> sampleValues[i % sampleValues.size]
                }
                payload["#$i"] = value
            }
            val results = writeFieldsWithVerification(payload, append = false, broadcastFeedback = false)
            return results.values.any { info ->
                (info as? Map<*, *>)?.let { it["success"] == true || it["verified"] == true } == true
            }
        }
        return false
    }

    /**
     * Executes a raw command string from Flutter's runOmniPilotBot or overlay fallback,
     * guaranteed to broadcast and return a concise status string.
     */
    fun executeBotCommand(command: String): String {
        val trimmed = command.trim()
        var feedback = "✅ Command processed."
        try {
            if (trimmed.isEmpty()) {
                feedback = "⚠️ Bot Alert: Empty command received."
                return feedback
            }

            if (!SystemPermissionHelper.hasOverlayPermission(this)) {
                feedback = "⚠️ Bot Error: Overlay permission is required."
                sendBotFeedback(feedback)
                return feedback
            }

            val lower = trimmed.lowercase()

            // 1. App launch command
            val openPrefixes = listOf("open ", "launch ", "start ", "go to ")
            for (pfx in openPrefixes) {
                if (lower.startsWith(pfx)) {
                    val targetApp = trimmed.substring(pfx.length).trim()
                    launchOrResolveApp(targetApp, this)
                    return "⏳ Processing launch for $targetApp..."
                }
            }

            // 2. Click command
            val clickPrefixes = listOf("click ", "tap ", "press ")
            for (pfx in clickPrefixes) {
                if (lower.startsWith(pfx)) {
                    val target = trimmed.substring(pfx.length).trim()
                    val clicked = clickElement(target, broadcastFeedback = false)
                    feedback = if (clicked) {
                        "✅ Done: Click '$target' completed."
                    } else {
                        "⚠️ Bot Alert: Target '$target' not found."
                    }
                    return feedback
                }
            }

            // 3. Scroll command
            if (lower.startsWith("scroll")) {
                val dir = if (lower.contains("up")) "up" else "down"
                val scrolled = scrollScreen(dir, broadcastFeedback = false)
                feedback = if (scrolled) {
                    "✅ Done: Scroll $dir completed."
                } else {
                    "⚠️ Bot Alert: Could not scroll $dir."
                }
                return feedback
            }

            // 4. Navigation command
            if (lower == "back" || lower == "go back" || lower == "home") {
                val nav = if (lower.contains("home")) "HOME" else "BACK"
                val ok = performSystemNavigation(nav, broadcastFeedback = false)
                feedback = if (ok) {
                    "✅ Done: Navigate $nav completed."
                } else {
                    "⚠️ Bot Error: Navigation $nav failed."
                }
                return feedback
            }

            // 5. Key=Value or Key: Value field fill
            val map = mutableMapOf<String, String>()
            val pairRegex = Regex("([A-Za-z0-9_# ]+)[:=]\\s*([^,\\n]+)")
            for (m in pairRegex.findAll(trimmed)) {
                val k = m.groupValues[1].trim()
                val v = m.groupValues[2].trim()
                if (k.isNotEmpty() && v.isNotEmpty()) {
                    map[k] = v
                }
            }
            if (map.isNotEmpty()) {
                val roots = getTargetRoots(preferExternal = true)
                if (roots.isEmpty()) {
                    feedback = "⚠️ Bot Error: Active screen unreadable."
                    return feedback
                }
                val res = writeFieldsWithVerification(map, append = false, broadcastFeedback = false)
                val anySuccess = res.values.any { info ->
                    (info as? Map<*, *>)?.let { it["success"] == true || it["verified"] == true } == true
                }
                feedback = if (anySuccess) {
                    "✅ Done: Autofill completed."
                } else {
                    "⚠️ Bot Alert: Target fields not found."
                }
                return feedback
            }

            // 6. Default: run node action on the active external root
            val rootNode = getTargetRoots(preferExternal = true).firstOrNull()
            feedback = if (rootNode == null) {
                "⚠️ Bot Error: Active screen unreadable."
            } else {
                val success = performNodeAction(rootNode)
                if (success) {
                    "✅ Done: $trimmed completed."
                } else {
                    "⚠️ Bot Alert: Target fields not found."
                }
            }
            return feedback
        } catch (e: Exception) {
            feedback = "❌ Bot Failed: ${e.localizedMessage?.take(40) ?: "Unknown error"}"
            return feedback
        } finally {
            sendBotFeedback(feedback)
        }
    }

    fun sendBotFeedback(message: String) {
        // 1. Update FloatingBubbleService HUD/Toast immediately
        FloatingBubbleService.updateStatusBubble(message)

        // 2. Push back to Flutter MethodChannel if active
        mainHandler.post {
            try {
                MainActivity.methodChannel?.invokeMethod("onBotFeedback", message)
            } catch (e: Exception) {
                Log.w(TAG, "Failed to invoke onBotFeedback: ${e.message}")
            }
        }
    }

    /**
     * Checks if access to [packageName] is granted. If not, renders the interactive overlay
     * permission popup over the screen and awaits user decision before executing [onGranted].
     */
    fun requestAppPermissionIfNeeded(
        packageName: String,
        actionDescription: String,
        onGranted: () -> Unit,
        onDenied: () -> Unit = {}
    ) {
        if (AppPermissionManager.isPackageAllowed(this, packageName)) {
            onGranted()
            return
        }

        val (appLabel, appIcon) = AppPermissionManager.resolveAppDetails(this, packageName)

        FloatingBubbleService.showAppPermissionPopup(
            appLabel = appLabel,
            packageName = packageName,
            appIcon = appIcon,
            requestedScope = actionDescription
        ) { decision ->
            when (decision) {
                PermissionDecision.ALLOW_ALWAYS -> {
                    AppPermissionManager.allowPermanently(this, packageName)
                    sendBotFeedback("✅ Permission saved for $appLabel.")
                    onGranted()
                }
                PermissionDecision.ALLOW_ONCE -> {
                    AppPermissionManager.allowForSession(packageName)
                    sendBotFeedback("✅ Granted one-time access for $appLabel.")
                    onGranted()
                }
                PermissionDecision.DENY -> {
                    sendBotFeedback("🚫 Access denied for $appLabel.")
                    onDenied()
                }
            }
        }
    }

    /**
     * Backward-compatible boolean map filler.
     */
    fun fillFields(fieldMappings: Map<String, String>): Map<String, Boolean> {
        val detailed = writeFieldsWithVerification(fieldMappings, append = false)
        val simple = mutableMapOf<String, Boolean>()
        for ((k, v) in detailed) {
            @Suppress("UNCHECKED_CAST")
            val info = v as? Map<String, Any>
            simple[k] = (info?.get("success") as? Boolean) ?: false
        }
        return simple
    }

    /**
     * Universal multi-field writer that supports arbitrary field names, index (#0, #1),
     * semantic matching, clipboard fallback, and read-back verification of the written text.
     */
    @JvmOverloads
    fun writeFieldsWithVerification(
        fieldMappings: Map<String, String>,
        append: Boolean = false,
        broadcastFeedback: Boolean = true
    ): Map<String, Any> {
        val activePkg = (rootInActiveWindow?.packageName?.toString() ?: lastExternalPackage).orEmpty()
        if (activePkg.contains("permissioncontroller", ignoreCase = true)) {
            val msg = "⚠️ System permission prompt detected—please tap Allow on screen to continue"
            sendBotFeedback(msg)
            return emptyMap()
        }
        if (activePkg.isNotEmpty() && !AppPermissionManager.isPackageAllowed(this, activePkg)) {
            requestAppPermissionIfNeeded(
                packageName = activePkg,
                actionDescription = "Autofill fields in $activePkg",
                onGranted = {
                    writeFieldsWithVerification(fieldMappings, append, broadcastFeedback)
                },
                onDenied = {
                    sendBotFeedback("🚫 Cannot fill fields: Permission denied for $activePkg.")
                }
            )
            return emptyMap()
        }

        val results = mutableMapOf<String, Any>()
        var feedback = "✅ Done: Autofill completed."
        try {
            val roots = getTargetRoots(preferExternal = true)
            if (roots.isEmpty()) {
                feedback = "⚠️ Bot Error: Active screen unreadable."
                return emptyMap()
            }

            val editableEntries = mutableListOf<EditableNodeEntry>()
            for (root in roots) {
                if (roots.size > 1 && root.packageName?.toString() == packageName) continue
                collectEditableEntries(root, editableEntries)
            }

            if (editableEntries.isEmpty()) {
                feedback = "⚠️ Bot Alert: Target fields not found."
                for ((key, _) in fieldMappings) {
                    results[key] = mapOf(
                        "success" to false,
                        "verified" to false,
                        "error" to "No editable fields found on active screen",
                        "availableFields" to emptyList<String>()
                    )
                }
                return results
            }

            val usedIndices = mutableSetOf<Int>()
            var successCount = 0

            for ((key, valueToSet) in fieldMappings) {
                val matches = findAllMatchingEditableEntries(editableEntries, key, usedIndices)
                val match = if (matches.size > 1 && fieldMappings.size == 1 && broadcastFeedback) {
                    // Ambiguous field: trigger overlay disambiguation dialog for user to choose
                    FloatingBubbleService.showDisambiguationDialog(
                        title = "🤔 Multiple fields match \"$key\". Which one?",
                        options = matches.mapIndexed { idx, entry ->
                            ChoiceOption(
                                label = "#${idx + 1} ${entry.label.ifEmpty { entry.shortId.ifEmpty { "Field #${entry.index}" } }}",
                                subtitle = formatNodeContext(entry.node),
                                icon = null
                            )
                        }
                    ) { selectedIndex ->
                        if (selectedIndex in matches.indices) {
                            val selectedEntry = matches[selectedIndex]
                            writeToEditableNode(selectedEntry.node, valueToSet, append)
                            sendBotFeedback("✅ Done: Autofill for '$key' completed.")
                        }
                    }
                    matches.firstOrNull()
                } else {
                    findBestEditableEntry(editableEntries, key, usedIndices)
                }

                if (match != null) {
                    usedIndices.add(match.index)
                    val node = match.node
                    val prevValue = getActualNodeText(node)
                    val finalValue = if (append && prevValue.isNotEmpty()) "$prevValue$valueToSet" else valueToSet

                    val actionSuccess = writeToEditableNode(node, finalValue, append = false)
                    val verifiedValue = getActualNodeText(node)
                    val isVerified = verifiedValue == finalValue || verifiedValue.contains(valueToSet)
                    val ok = actionSuccess || isVerified
                    if (ok) successCount++

                    results[key] = mapOf(
                        "success" to ok,
                        "verified" to isVerified,
                        "matchedIndex" to match.index,
                        "matchedLabel" to match.label,
                        "previousValue" to prevValue,
                        "writtenValue" to finalValue,
                        "verifiedValue" to verifiedValue
                    )
                } else {
                    results[key] = mapOf(
                        "success" to false,
                        "verified" to false,
                        "error" to "No matching editable field found for '$key'",
                        "availableFields" to editableEntries.map { "#${it.index}: ${it.label}" }
                    )
                }
            }

            feedback = if (successCount > 0) {
                "✅ Done: Autofill ($successCount/${fieldMappings.size}) completed."
            } else {
                "⚠️ Bot Alert: Target fields not found."
            }
            return results
        } catch (e: Exception) {
            feedback = "❌ Bot Failed: ${e.localizedMessage?.take(40) ?: "Unknown error"}"
            return results
        } finally {
            if (broadcastFeedback) {
                sendBotFeedback(feedback)
            }
        }
    }

    private fun writeToEditableNode(node: AccessibilityNodeInfo, text: String, append: Boolean = false): Boolean {
        val prevValue = getActualNodeText(node)
        val finalValue = if (append && prevValue.isNotEmpty()) "$prevValue$text" else text

        node.performAction(AccessibilityNodeInfo.ACTION_FOCUS)

        val args = Bundle().apply {
            putCharSequence(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                finalValue
            )
        }
        var actionSuccess = node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
        if (!actionSuccess) {
            actionSuccess = pasteTextFallback(node, finalValue)
        }
        try {
            node.refresh()
        } catch (_: Exception) {}
        return actionSuccess
    }

    private fun pasteTextFallback(node: AccessibilityNodeInfo, text: String): Boolean {
        return try {
            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            val clip = ClipData.newPlainText("copilot_autofill", text)
            clipboard.setPrimaryClip(clip)
            node.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
            node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            val pasted = node.performAction(AccessibilityNodeInfo.ACTION_PASTE)
            if (!pasted) {
                // If PASTE action fails, try typing via ACTION_SET_TEXT once more after the click/focus
                val args = Bundle().apply {
                    putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
                }
                node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
            } else {
                true
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun getActualNodeText(node: AccessibilityNodeInfo): String {
        val showingHint = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            node.isShowingHintText
        } else {
            false
        }
        if (showingHint) return ""
        return node.text?.toString() ?: ""
    }

    private data class EditableNodeEntry(
        val index: Int,
        val node: AccessibilityNodeInfo,
        val label: String,
        val hint: String,
        val shortId: String,
        val fullId: String,
        val contentDesc: String
    )

    private fun collectEditableEntries(
        node: AccessibilityNodeInfo,
        list: MutableList<EditableNodeEntry>
    ) {
        val bounds = Rect()
        node.getBoundsInScreen(bounds)
        val hasValidBounds = bounds.width() > 0 && bounds.height() > 0

        if (hasValidBounds && isNodeEditableInThirdPartyApps(node)) {
            val fullId = node.viewIdResourceName ?: ""
            val shortId = fullId.substringAfterLast('/')
            val hint = node.hintText?.toString()?.trim() ?: ""
            val desc = node.contentDescription?.toString()?.trim() ?: ""
            val showingHint = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                node.isShowingHintText
            } else {
                false
            }
            val rawText = node.text?.toString()?.trim() ?: ""
            val label = resolveNodeLabel(node, hint, desc, shortId, showingHint, rawText)
            list.add(
                EditableNodeEntry(
                    index = list.size,
                    node = node,
                    label = label,
                    hint = hint,
                    shortId = shortId,
                    fullId = fullId,
                    contentDesc = desc
                )
            )
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            collectEditableEntries(child, list)
        }
    }

    private fun findBestEditableEntry(
        entries: List<EditableNodeEntry>,
        targetKey: String,
        usedIndices: Set<Int>
    ): EditableNodeEntry? {
        if (entries.isEmpty()) return null
        val trimmed = targetKey.trim()

        // If user is currently focused on an editable field in any third-party app, prefer it
        if (trimmed == "#0" || trimmed.isEmpty() || trimmed.equals("focused", ignoreCase = true) || trimmed.equals("current", ignoreCase = true)) {
            entries.firstOrNull { it.node.isFocused && !usedIndices.contains(it.index) }?.let { return it }
        }

        // If there is only 1 editable entry on screen (typical for chat apps like WhatsApp, Telegram, search bars, notes), use it
        if (entries.size == 1 && !usedIndices.contains(0)) {
            return entries[0]
        }

        // 1. Check index syntax: "#0", "#1", "0", "field_0", "index_0"
        val indexRegex = Regex("^(?:#|field_?|index_?)?(\\d+)$", RegexOption.IGNORE_CASE)
        val indexMatch = indexRegex.find(trimmed)
        if (indexMatch != null) {
            val idx = indexMatch.groupValues[1].toIntOrNull()
            if (idx != null && idx in entries.indices) {
                return entries[idx]
            }
        }

        // 2. Check "focused" or "current"
        if (trimmed.equals("focused", ignoreCase = true) || trimmed.equals("current", ignoreCase = true)) {
            entries.firstOrNull { it.node.isFocused }?.let { return it }
        }

        val normalizedKey = trimmed.lowercase().replace("_", "").replace("-", "").replace(" ", "")

        // 3. Exact match on label, hint, or shortId (preferring unused fields first)
        for (entry in entries) {
            val lblNorm = entry.label.lowercase().replace("_", "").replace(" ", "")
            val hintNorm = entry.hint.lowercase().replace("_", "").replace(" ", "")
            val idNorm = entry.shortId.lowercase().replace("_", "").replace(" ", "")
            if (lblNorm == normalizedKey || hintNorm == normalizedKey || idNorm == normalizedKey) {
                if (!usedIndices.contains(entry.index)) return entry
            }
        }

        // 4. Substring match on label, hint, shortId, fullId, or contentDescription
        for (entry in entries) {
            val combined = "${entry.label} ${entry.hint} ${entry.shortId} ${entry.fullId} ${entry.contentDesc}"
                .lowercase()
                .replace("_", "")
                .replace(" ", "")
            if (combined.contains(normalizedKey) && !usedIndices.contains(entry.index)) {
                return entry
            }
        }

        // 5. Rich semantic synonym dictionary for forms, contacts, school apps, login, etc.
        val synonyms = when (normalizedKey) {
            "studentname", "name", "fullname", "firstname", "givenname" ->
                listOf("firstname", "givenname", "student", "fullname", "name", "person")
            "lastname", "surname", "familyname" ->
                listOf("lastname", "surname", "familyname", "last", "second")
            "rollno", "roll", "rollnumber", "regno", "id", "studentid" ->
                listOf("roll", "reg", "id", "number", "code", "phone", "mobile")
            "classgrade", "class", "section", "grade", "company", "organization", "department" ->
                listOf("class", "grade", "section", "standard", "company", "organization", "school", "dept")
            "status", "attendance", "notes", "remarks", "comment" ->
                listOf("status", "attendance", "present", "absent", "note", "remark", "comment", "bio")
            "phone", "mobile", "phonenumber", "contact", "tel" ->
                listOf("phone", "mobile", "tel", "contact", "cell", "number")
            "email", "mail", "emailaddress" ->
                listOf("email", "mail", "e-mail")
            "search", "query", "find" ->
                listOf("search", "query", "find", "filter")
            "cnic", "nic", "nationalid", "mothercnic", "parentcnic" ->
                listOf("cnic", "nic", "national", "identity", "mother", "parent", "card")
            "bform", "crc", "bayform", "birthcert", "childid", "bformnumber" ->
                listOf("bform", "bayform", "b-form", "form-b", "crc", "child", "birth", "registration")
            "emis", "emiscode", "schoolcode", "institutioncode", "school" ->
                listOf("emis", "school", "institution", "campus", "center", "centre", "code")
            "totalworkingdays", "workingdays", "totaldays" ->
                listOf("total", "working", "period", "days")
            "dayspresent", "presentdays", "attendeddays", "attended" ->
                listOf("present", "attended", "actual", "days")
            "attendancepercentage", "percentage", "rate" ->
                listOf("percentage", "percent", "ratio", "rate", "%")
            "gender" ->
                listOf("gender", "sex")
            else -> listOf(normalizedKey)
        }

        for (syn in synonyms) {
            for (entry in entries) {
                if (usedIndices.contains(entry.index)) continue
                val combined = "${entry.label} ${entry.hint} ${entry.shortId} ${entry.contentDesc}"
                    .lowercase()
                    .replace("_", "")
                    .replace(" ", "")
                if (combined.contains(syn)) {
                    return entry
                }
            }
        }

        // 6. Fallback: if there are unused editable fields on screen, pick the first unused one
        return entries.firstOrNull { !usedIndices.contains(it.index) }
    }

    private fun findAllMatchingEditableEntries(
        entries: List<EditableNodeEntry>,
        targetKey: String,
        usedIndices: Set<Int>
    ): List<EditableNodeEntry> {
        val trimmed = targetKey.trim()
        val normalizedKey = trimmed.lowercase().replace("_", "").replace("-", "").replace(" ", "")

        val exactMatches = entries.filter {
            !usedIndices.contains(it.index) && (
                it.label.lowercase().replace("_", "").replace(" ", "") == normalizedKey ||
                it.hint.lowercase().replace("_", "").replace(" ", "") == normalizedKey ||
                it.shortId.lowercase().replace("_", "").replace(" ", "") == normalizedKey
            )
        }
        if (exactMatches.isNotEmpty()) return exactMatches

        val partialMatches = entries.filter {
            !usedIndices.contains(it.index) && (
                it.label.contains(trimmed, ignoreCase = true) ||
                it.hint.contains(trimmed, ignoreCase = true) ||
                it.shortId.contains(trimmed, ignoreCase = true)
            )
        }
        return partialMatches
    }

    private fun formatNodeContext(node: AccessibilityNodeInfo): String {
        val bounds = Rect()
        node.getBoundsInScreen(bounds)
        val id = node.viewIdResourceName?.substringAfterLast('/') ?: ""
        val boundsDesc = if (!bounds.isEmpty) "[${bounds.left}, ${bounds.top}]" else ""
        val parentText = node.parent?.text?.toString()?.trim() ?: ""
        return when {
            id.isNotEmpty() && parentText.isNotEmpty() -> "id: $id • in \"$parentText\" $boundsDesc"
            id.isNotEmpty() -> "id: $id $boundsDesc"
            parentText.isNotEmpty() -> "in \"$parentText\" $boundsDesc"
            boundsDesc.isNotEmpty() -> "position $boundsDesc"
            else -> node.className?.toString()?.substringAfterLast('.') ?: "UI Element"
        }
    }

    private fun findAllMatchingNodes(
        roots: List<AccessibilityNodeInfo>,
        target: String,
        mustBeClickable: Boolean = false,
        mustBeEditable: Boolean = false
    ): List<AccessibilityNodeInfo> {
        val results = mutableListOf<AccessibilityNodeInfo>()
        val seen = mutableSetOf<String>()

        for (root in roots) {
            if (roots.size > 1 && root.packageName?.toString() == packageName) continue
            collectAllMatchingNodes(root, target.lowercase().trim(), mustBeClickable, mustBeEditable, results, seen)
        }
        return results
    }

    private fun collectAllMatchingNodes(
        node: AccessibilityNodeInfo,
        targetLower: String,
        mustBeClickable: Boolean,
        mustBeEditable: Boolean,
        out: MutableList<AccessibilityNodeInfo>,
        seen: MutableSet<String>
    ) {
        val text = node.text?.toString()?.lowercase()?.trim() ?: ""
        val desc = node.contentDescription?.toString()?.lowercase()?.trim() ?: ""
        val id = node.viewIdResourceName?.lowercase() ?: ""
        val shortId = id.substringAfterLast('/')

        val matches = (text.isNotEmpty() && (text == targetLower || text.contains(targetLower))) ||
                      (desc.isNotEmpty() && (desc == targetLower || desc.contains(targetLower))) ||
                      (shortId.isNotEmpty() && (shortId == targetLower || shortId.contains(targetLower)))

        if (matches) {
            val passClickable = !mustBeClickable || node.isClickable || node.isCheckable || node.parent?.isClickable == true
            val passEditable = !mustBeEditable || isNodeEditableInThirdPartyApps(node)

            if (passClickable && passEditable) {
                val bounds = Rect()
                node.getBoundsInScreen(bounds)
                val key = "${node.viewIdResourceName}_${bounds.left}_${bounds.top}_${bounds.right}_${bounds.bottom}"
                if (!seen.contains(key)) {
                    seen.add(key)
                    out.add(node)
                }
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            collectAllMatchingNodes(child, targetLower, mustBeClickable, mustBeEditable, out, seen)
        }
    }

    /**
     * Clicks a button or interactive element matching a target label, resource ID, or index (#0).
     * Automatically walks up parent hierarchy if the text node itself is not clickable,
     * and falls back to hardware coordinate tap gesture if ACTION_CLICK returns false.
     */
    @JvmOverloads
    fun clickElement(targetLabel: String, broadcastFeedback: Boolean = true): Boolean {
        val trimmed = targetLabel.trim()
        val activePkg = (rootInActiveWindow?.packageName?.toString() ?: lastExternalPackage).orEmpty()
        if (activePkg.contains("permissioncontroller", ignoreCase = true)) {
            val msg = "⚠️ System permission prompt detected—please tap Allow on screen to continue"
            sendBotFeedback(msg)
            return false
        }
        if (activePkg.isNotEmpty() && !AppPermissionManager.isPackageAllowed(this, activePkg)) {
            requestAppPermissionIfNeeded(
                packageName = activePkg,
                actionDescription = "Tap '$trimmed' in $activePkg",
                onGranted = {
                    clickElement(targetLabel, broadcastFeedback)
                },
                onDenied = {
                    sendBotFeedback("🚫 Cannot tap '$trimmed': Permission denied for $activePkg.")
                }
            )
            return false
        }

        var clickedSuccess = false
        var feedback = "✅ Done: Click '$trimmed' completed."
        try {
            val roots = getTargetRoots(preferExternal = true)
            if (roots.isEmpty()) {
                feedback = "⚠️ Bot Error: Active screen unreadable."
                return false
            }

            // Support index syntax "#0", "#1" from clickableElements snapshot
            val indexRegex = Regex("^#(\\d+)$")
            val indexMatch = indexRegex.find(trimmed)
            if (indexMatch != null) {
                val idx = indexMatch.groupValues[1].toIntOrNull()
                if (idx != null) {
                    val snapshot = getScreenSnapshot(preferExternal = true)
                    @Suppress("UNCHECKED_CAST")
                    val clickables = (snapshot["clickableElements"] as? List<Map<String, Any>>) ?: emptyList()
                    if (idx in clickables.indices) {
                        val item = clickables[idx]
                        val cx = (item["centerX"] as? Int)?.toFloat() ?: 0f
                        val cy = (item["centerY"] as? Int)?.toFloat() ?: 0f
                        val lbl = item["label"]?.toString() ?: ""
                        if (lbl.isNotEmpty()) {
                            for (root in roots) {
                                val node = findNodeByTextOrId(root, lbl)
                                if (node != null && performRobustClick(node)) {
                                    clickedSuccess = true
                                    return true
                                }
                            }
                        }
                        if (cx > 0 && cy > 0) {
                            clickedSuccess = tapCoordinates(cx, cy)
                            return clickedSuccess
                        }
                    }
                }
            }

            // Disambiguation check across interactive nodes
            val matchingNodes = findAllMatchingNodes(roots, trimmed, mustBeClickable = false)
            when {
                matchingNodes.isEmpty() -> {
                    feedback = "⚠️ Bot Alert: Target \"$trimmed\" not found."
                    return false
                }
                matchingNodes.size == 1 -> {
                    val node = matchingNodes.first()
                    clickedSuccess = performRobustClick(node)
                    if (!clickedSuccess) {
                        feedback = "⚠️ Bot Alert: Could not click '$trimmed'."
                    }
                    return clickedSuccess
                }
                else -> {
                    // Multiple matching nodes (>= 2): Trigger overlay disambiguation dialog!
                    FloatingBubbleService.showDisambiguationDialog(
                        title = "🤔 Multiple elements match \"$trimmed\". Which one?",
                        options = matchingNodes.mapIndexed { idx, n ->
                            val rawText = n.text?.toString()?.trim() ?: ""
                            val desc = n.contentDescription?.toString()?.trim() ?: ""
                            val shortId = n.viewIdResourceName?.substringAfterLast('/') ?: ""
                            val displayLabel = rawText.ifEmpty { desc.ifEmpty { shortId.ifEmpty { trimmed } } }
                            ChoiceOption(
                                label = "#${idx + 1} $displayLabel",
                                subtitle = formatNodeContext(n),
                                icon = null
                            )
                        }
                    ) { selectedIndex ->
                        if (selectedIndex in matchingNodes.indices) {
                            val chosen = matchingNodes[selectedIndex]
                            val ok = performRobustClick(chosen)
                            val chosenFeedback = if (ok) "✅ Done: Click '${trimmed}' completed." else "⚠️ Bot Alert: Click failed."
                            sendBotFeedback(chosenFeedback)
                        }
                    }
                    clickedSuccess = true
                    feedback = "⏳ Disambiguating multiple elements for '$trimmed'..."
                    return true
                }
            }
        } catch (e: Exception) {
            feedback = "❌ Bot Failed: ${e.localizedMessage?.take(40) ?: "Unknown error"}"
            return false
        } finally {
            if (!clickedSuccess && !feedback.startsWith("❌") && !feedback.startsWith("⚠️ Bot Error")) {
                feedback = "⚠️ Bot Alert: Target \"$trimmed\" not found."
            }
            if (broadcastFeedback) {
                sendBotFeedback(feedback)
            }
        }
    }

    /**
     * Long-clicks a button or interactive element matching [targetLabel].
     */
    @JvmOverloads
    fun longClickElement(targetLabel: String, broadcastFeedback: Boolean = true): Boolean {
        val trimmed = targetLabel.trim()
        val activePkg = (rootInActiveWindow?.packageName?.toString() ?: lastExternalPackage).orEmpty()
        if (activePkg.contains("permissioncontroller", ignoreCase = true)) {
            val msg = "⚠️ System permission prompt detected—please tap Allow on screen to continue"
            sendBotFeedback(msg)
            return false
        }
        if (activePkg.isNotEmpty() && !AppPermissionManager.isPackageAllowed(this, activePkg)) {
            requestAppPermissionIfNeeded(
                packageName = activePkg,
                actionDescription = "Long press '$trimmed' in $activePkg",
                onGranted = {
                    longClickElement(targetLabel, broadcastFeedback)
                },
                onDenied = {
                    sendBotFeedback("🚫 Cannot long press '$trimmed': Permission denied for $activePkg.")
                }
            )
            return false
        }

        var clickedSuccess = false
        var feedback = "✅ Done: Long-press '$trimmed' completed."
        try {
            val roots = getTargetRoots(preferExternal = true)
            if (roots.isEmpty()) {
                feedback = "⚠️ Bot Error: Active screen unreadable."
                return false
            }

            val matchingNodes = findAllMatchingNodes(roots, trimmed, mustBeClickable = false)
            when {
                matchingNodes.isEmpty() -> {
                    feedback = "⚠️ Bot Alert: Target \"$trimmed\" not found."
                    return false
                }
                matchingNodes.size == 1 -> {
                    val node = matchingNodes.first()
                    clickedSuccess = performRobustLongClick(node)
                    if (!clickedSuccess) {
                        feedback = "⚠️ Bot Alert: Could not long-press '$trimmed'."
                    }
                    return clickedSuccess
                }
                else -> {
                    // Multiple matching nodes (>= 2): Trigger overlay disambiguation dialog!
                    FloatingBubbleService.showDisambiguationDialog(
                        title = "🤔 Multiple elements match \"$trimmed\". Which one?",
                        options = matchingNodes.mapIndexed { idx, n ->
                            val rawText = n.text?.toString()?.trim() ?: ""
                            val desc = n.contentDescription?.toString()?.trim() ?: ""
                            val shortId = n.viewIdResourceName?.substringAfterLast('/') ?: ""
                            val displayLabel = rawText.ifEmpty { desc.ifEmpty { shortId.ifEmpty { trimmed } } }
                            ChoiceOption(
                                label = "#${idx + 1} $displayLabel",
                                subtitle = formatNodeContext(n),
                                icon = null
                            )
                        }
                    ) { selectedIndex ->
                        if (selectedIndex in matchingNodes.indices) {
                            val chosen = matchingNodes[selectedIndex]
                            val ok = performRobustLongClick(chosen)
                            val chosenFeedback = if (ok) "✅ Done: Long-press '${trimmed}' completed." else "⚠️ Bot Alert: Long-press failed."
                            sendBotFeedback(chosenFeedback)
                        }
                    }
                    clickedSuccess = true
                    feedback = "⏳ Disambiguating multiple elements for '$trimmed'..."
                    return true
                }
            }
        } catch (e: Exception) {
            feedback = "❌ Bot Failed: ${e.localizedMessage?.take(40) ?: "Unknown error"}"
            return false
        } finally {
            if (!clickedSuccess && !feedback.startsWith("❌") && !feedback.startsWith("⚠️ Bot Error")) {
                feedback = "⚠️ Bot Alert: Target \"$trimmed\" not found."
            }
            if (broadcastFeedback) {
                sendBotFeedback(feedback)
            }
        }
    }

    private fun performRobustLongClick(node: AccessibilityNodeInfo): Boolean {
        var curr: AccessibilityNodeInfo? = node
        var depth = 0
        while (curr != null && depth < 5) {
            if (curr.isLongClickable && curr.performAction(AccessibilityNodeInfo.ACTION_LONG_CLICK)) {
                return true
            }
            curr = curr.parent
            depth++
        }
        val bounds = Rect()
        node.getBoundsInScreen(bounds)
        if (!bounds.isEmpty) {
            return dispatchTapOrSwipe(
                bounds.centerX().toFloat(),
                bounds.centerY().toFloat(),
                bounds.centerX().toFloat(),
                bounds.centerY().toFloat(),
                650L
            )
        }
        return false
    }

    /**
     * Sets a Checkbox, Switch, RadioButton, or Toggle element to the desired [checked] state.
     */
    @JvmOverloads
    fun setCheckableState(
        targetLabel: String,
        checked: Boolean,
        broadcastFeedback: Boolean = true
    ): Map<String, Any> {
        val trimmed = targetLabel.trim()
        var feedback = "✅ Done: Toggle '$trimmed' completed."
        try {
            val roots = getTargetRoots(preferExternal = true)
            if (roots.isEmpty()) {
                feedback = "⚠️ Bot Error: Active screen unreadable."
                return mapOf("success" to false, "error" to "No active window")
            }

            for (root in roots) {
                if (roots.size > 1 && root.packageName?.toString() == packageName) continue
                val node = findCheckableNode(root, trimmed)
                if (node != null) {
                    val currentlyChecked = node.isChecked
                    if (currentlyChecked == checked) {
                        return mapOf(
                            "success" to true,
                            "changed" to false,
                            "isChecked" to currentlyChecked,
                            "message" to "Already in desired state ($checked)"
                        )
                    }
                    val clicked = performRobustClick(node)
                    try {
                        node.refresh()
                    } catch (_: Exception) {}
                    if (!clicked) {
                        feedback = "⚠️ Bot Alert: Could not toggle '$trimmed'."
                    }
                    return mapOf(
                        "success" to clicked,
                        "changed" to clicked,
                        "isChecked" to node.isChecked
                    )
                }
            }
            feedback = "⚠️ Bot Alert: Target '$trimmed' not found."
            return mapOf("success" to false, "error" to "Checkable element '$targetLabel' not found")
        } catch (e: Exception) {
            feedback = "❌ Bot Failed: ${e.localizedMessage?.take(40) ?: "Unknown error"}"
            return mapOf("success" to false, "error" to (e.localizedMessage ?: "Unknown error"))
        } finally {
            if (broadcastFeedback) {
                sendBotFeedback(feedback)
            }
        }
    }

    private fun performRobustClick(node: AccessibilityNodeInfo): Boolean {
        // 1. Try clicking the node directly or walking up its parent containers
        var curr: AccessibilityNodeInfo? = node
        var depth = 0
        while (curr != null && depth < 6) {
            if (curr.isClickable && curr.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                return true
            }
            curr = curr.parent
            depth++
        }

        // 2. Try ACTION_CLICK even if isClickable wasn't explicitly set
        if (node.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
            return true
        }

        // 3. Fallback: Hardware-level coordinate tap at the center of the node's screen bounds
        val bounds = Rect()
        node.getBoundsInScreen(bounds)
        if (!bounds.isEmpty && bounds.centerX() > 0 && bounds.centerY() > 0) {
            return tapCoordinates(bounds.centerX().toFloat(), bounds.centerY().toFloat())
        }
        return false
    }

    private fun findNodeByTextOrId(node: AccessibilityNodeInfo, target: String): AccessibilityNodeInfo? {
        val targetLower = target.lowercase().trim()

        val text = node.text?.toString()?.lowercase()?.trim() ?: ""
        val desc = node.contentDescription?.toString()?.lowercase()?.trim() ?: ""
        val id = node.viewIdResourceName?.lowercase() ?: ""
        val shortId = id.substringAfterLast('/')

        // Exact match priority
        if (text == targetLower || desc == targetLower || shortId == targetLower) {
            return node
        }

        // Check children for exact match first
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val exactChild = findNodeByExactText(child, targetLower)
            if (exactChild != null) return exactChild
        }

        // Partial match
        if ((text.contains(targetLower) || desc.contains(targetLower) || shortId.contains(targetLower)) &&
            targetLower.isNotEmpty()
        ) {
            return node
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val found = findNodeByTextOrId(child, target)
            if (found != null) return found
        }

        return null
    }

    private fun findNodeByExactText(node: AccessibilityNodeInfo, targetLower: String): AccessibilityNodeInfo? {
        val text = node.text?.toString()?.lowercase()?.trim() ?: ""
        val desc = node.contentDescription?.toString()?.lowercase()?.trim() ?: ""
        val shortId = (node.viewIdResourceName?.lowercase() ?: "").substringAfterLast('/')

        if (text == targetLower || desc == targetLower || shortId == targetLower) {
            return node
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val found = findNodeByExactText(child, targetLower)
            if (found != null) return found
        }
        return null
    }

    private fun findCheckableNode(node: AccessibilityNodeInfo, target: String): AccessibilityNodeInfo? {
        val targetLower = target.lowercase()
        if (node.isCheckable) {
            val text = node.text?.toString()?.lowercase() ?: ""
            val desc = node.contentDescription?.toString()?.lowercase() ?: ""
            val id = node.viewIdResourceName?.lowercase() ?: ""
            val parentText = resolveClickableLabel(node, text, desc, id).lowercase()
            if (text.contains(targetLower) || desc.contains(targetLower) ||
                id.contains(targetLower) || parentText.contains(targetLower)
            ) {
                return node
            }
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val found = findCheckableNode(child, target)
            if (found != null) return found
        }
        return null
    }

    /**
     * Scrolls the active screen in [direction] ("down"/"forward", "up"/"backward", "left", "right").
     */
    @JvmOverloads
    fun scrollScreen(direction: String, broadcastFeedback: Boolean = true): Boolean {
        val dir = direction.lowercase().trim()
        val activePkg = (rootInActiveWindow?.packageName?.toString() ?: lastExternalPackage).orEmpty()
        if (activePkg.contains("permissioncontroller", ignoreCase = true)) {
            val msg = "⚠️ System permission prompt detected—please tap Allow on screen to continue"
            sendBotFeedback(msg)
            return false
        }
        if (activePkg.isNotEmpty() && !AppPermissionManager.isPackageAllowed(this, activePkg)) {
            requestAppPermissionIfNeeded(
                packageName = activePkg,
                actionDescription = "Scroll screen in $activePkg",
                onGranted = {
                    scrollScreen(direction, broadcastFeedback)
                },
                onDenied = {
                    sendBotFeedback("🚫 Cannot scroll: Permission denied for $activePkg.")
                }
            )
            return false
        }

        var scrolled = false
        var feedback = "✅ Done: Scroll $dir completed."
        try {
            val roots = getTargetRoots(preferExternal = true)

            val scrollAction = when (dir) {
                "up", "backward", "top", "right" -> AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
                else -> AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
            }

            for (root in roots) {
                if (roots.size > 1 && root.packageName?.toString() == packageName) continue
                val scrollable = findScrollableNode(root)
                if (scrollable != null && scrollable.performAction(scrollAction)) {
                    scrolled = true
                    return true
                }
            }

            // Fallback to physical swipe gesture on screen
            val displayMetrics = resources.displayMetrics
            val w = displayMetrics.widthPixels.toFloat()
            val h = displayMetrics.heightPixels.toFloat()

            scrolled = when (dir) {
                "up", "backward" -> dispatchTapOrSwipe(w * 0.5f, h * 0.3f, w * 0.5f, h * 0.75f, 350L)
                "left" -> dispatchTapOrSwipe(w * 0.8f, h * 0.5f, w * 0.2f, h * 0.5f, 350L)
                "right" -> dispatchTapOrSwipe(w * 0.2f, h * 0.5f, w * 0.8f, h * 0.5f, 350L)
                else -> dispatchTapOrSwipe(w * 0.5f, h * 0.75f, w * 0.5f, h * 0.25f, 350L)
            }
            return scrolled
        } catch (e: Exception) {
            feedback = "❌ Bot Failed: ${e.localizedMessage?.take(40) ?: "Unknown error"}"
            return false
        } finally {
            if (!scrolled && !feedback.startsWith("❌")) {
                feedback = "⚠️ Bot Alert: Could not scroll $dir."
            }
            if (broadcastFeedback) {
                sendBotFeedback(feedback)
            }
        }
    }

    private fun findScrollableNode(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.isScrollable) return node
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val found = findScrollableNode(child)
            if (found != null) return found
        }
        return null
    }

    /**
     * Taps exact screen coordinates (x, y) using Accessibility GestureDescription.
     */
    fun tapCoordinates(x: Float, y: Float): Boolean {
        return dispatchTapOrSwipe(x, y, x, y, 60L)
    }

    /**
     * Swipes from (startX, startY) to (endX, endY) over [durationMs] milliseconds.
     */
    fun swipeCoordinates(
        startX: Float,
        startY: Float,
        endX: Float,
        endY: Float,
        durationMs: Long = 350L
    ): Boolean {
        return dispatchTapOrSwipe(startX, startY, endX, endY, durationMs)
    }

    private fun dispatchTapOrSwipe(
        startX: Float,
        startY: Float,
        endX: Float,
        endY: Float,
        durationMs: Long
    ): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return false
        return try {
            val path = Path().apply {
                moveTo(startX.coerceAtLeast(1f), startY.coerceAtLeast(1f))
                if (startX != endX || startY != endY) {
                    lineTo(endX.coerceAtLeast(1f), endY.coerceAtLeast(1f))
                }
            }
            val stroke = GestureDescription.StrokeDescription(path, 0L, durationMs.coerceIn(40L, 5000L))
            val gesture = GestureDescription.Builder().addStroke(stroke).build()

            if (Looper.myLooper() == Looper.getMainLooper()) {
                dispatchGesture(gesture, null, null)
            } else {
                val latch = CountDownLatch(1)
                var ok = false
                mainHandler.post {
                    ok = dispatchGesture(
                        gesture,
                        object : GestureResultCallback() {
                            override fun onCompleted(gestureDescription: GestureDescription?) {
                                latch.countDown()
                            }

                            override fun onCancelled(gestureDescription: GestureDescription?) {
                                latch.countDown()
                            }
                        },
                        null
                    )
                    if (!ok) latch.countDown()
                }
                latch.await(1500, TimeUnit.MILLISECONDS)
                ok
            }
        } catch (e: Exception) {
            Log.e(TAG, "Gesture dispatch error: ${e.message}")
            false
        }
    }

    /**
     * Performs global Android system navigation actions:
     * BACK, HOME, RECENTS, NOTIFICATIONS, QUICK_SETTINGS
     */
    @JvmOverloads
    fun performSystemNavigation(action: String, broadcastFeedback: Boolean = true): Boolean {
        val norm = action.uppercase().trim()
        var ok = false
        var feedback = "✅ Done: Navigate $norm completed."
        try {
            val globalAction = when (norm) {
                "BACK", "GO_BACK", "NAVIGATE_BACK" -> GLOBAL_ACTION_BACK
                "HOME", "GO_HOME" -> GLOBAL_ACTION_HOME
                "RECENTS", "RECENT_APPS", "OVERVIEW" -> GLOBAL_ACTION_RECENTS
                "NOTIFICATIONS" -> GLOBAL_ACTION_NOTIFICATIONS
                "QUICK_SETTINGS" -> GLOBAL_ACTION_QUICK_SETTINGS
                else -> {
                    feedback = "⚠️ Bot Alert: Unknown navigation '$norm'."
                    return false
                }
            }
            ok = performGlobalAction(globalAction)
            if (!ok) {
                feedback = "⚠️ Bot Error: Navigation $norm failed."
            }
            return ok
        } catch (e: Exception) {
            feedback = "❌ Bot Failed: ${e.localizedMessage?.take(40) ?: "Unknown error"}"
            return false
        } finally {
            if (broadcastFeedback) {
                sendBotFeedback(feedback)
            }
        }
    }

    /**
     * Lists installed launchable apps matching an optional search query.
     */
    fun getInstalledApps(query: String? = null): List<Map<String, String>> {
        val pm = packageManager
        val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val resolveInfos = pm.queryIntentActivities(mainIntent, 0)
        val q = query?.lowercase()?.trim() ?: ""

        val apps = mutableListOf<Map<String, String>>()
        val seenPackages = mutableSetOf<String>()

        for (info in resolveInfos) {
            val pkg = info.activityInfo?.packageName ?: continue
            if (seenPackages.contains(pkg)) continue
            val label = info.loadLabel(pm)?.toString() ?: pkg
            if (q.isEmpty() || label.lowercase().contains(q) || pkg.lowercase().contains(q)) {
                seenPackages.add(pkg)
                apps.add(
                    mapOf(
                        "appName" to label,
                        "packageName" to pkg
                    )
                )
            }
        }
        return apps.sortedBy { it["appName"] ?: "" }
    }

    private fun isIntentResolvable(intent: Intent): Boolean {
        val resolveInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.resolveActivity(intent, PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_DEFAULT_ONLY.toLong()))
        } else {
            @Suppress("DEPRECATION")
            packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
        }
        return resolveInfo != null && resolveInfo.activityInfo != null && resolveInfo.activityInfo.packageName != "android"
    }

    /**
     * Resolves and launches the system default app for standard Android intents (Contacts, Browser, Phone, SMS, Calendar, Notes).
     * This guarantees OEM compatibility (Samsung, Infinix, Xiaomi, Oppo, Vivo, Pixel) by honoring user's default app settings.
     */
    fun launchDefaultApp(keyword: String): Boolean {
        val lower = keyword.lowercase().trim()
        val pm = packageManager
        var intent: Intent? = null

        when {
            lower == "contacts" || lower == "contact" || lower == "people" || lower == "phonebook" -> {
                val base = Intent(Intent.ACTION_VIEW, ContactsContract.Contacts.CONTENT_URI).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                if (isIntentResolvable(base)) {
                    intent = base
                } else {
                    try {
                        val catIntent = Intent.makeMainSelectorActivity(Intent.ACTION_MAIN, Intent.CATEGORY_APP_CONTACTS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        if (isIntentResolvable(catIntent)) intent = catIntent
                    } catch (_: Exception) {}
                }
            }
            lower == "browser" || lower == "chrome" || lower == "web" || lower == "internet" -> {
                try {
                    val browserIntent = Intent.makeMainSelectorActivity(Intent.ACTION_MAIN, Intent.CATEGORY_APP_BROWSER).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    if (isIntentResolvable(browserIntent)) {
                        intent = browserIntent
                    }
                } catch (_: Exception) {}
                if (intent == null) {
                    val webIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com")).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    if (isIntentResolvable(webIntent)) intent = webIntent
                }
            }
            lower == "phone" || lower == "dialer" || lower == "call" -> {
                val dialIntent = Intent(Intent.ACTION_DIAL).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                if (isIntentResolvable(dialIntent)) intent = dialIntent
            }
            lower == "sms" || lower == "messages" || lower == "message" || lower == "messaging" -> {
                try {
                    val msgIntent = Intent.makeMainSelectorActivity(Intent.ACTION_MAIN, Intent.CATEGORY_APP_MESSAGING).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    if (isIntentResolvable(msgIntent)) intent = msgIntent
                } catch (_: Exception) {}
            }
            lower == "calendar" -> {
                try {
                    val calIntent = Intent.makeMainSelectorActivity(Intent.ACTION_MAIN, Intent.CATEGORY_APP_CALENDAR).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    if (isIntentResolvable(calIntent)) intent = calIntent
                } catch (_: Exception) {}
            }
            lower == "email" || lower == "mail" -> {
                try {
                    val mailIntent = Intent.makeMainSelectorActivity(Intent.ACTION_MAIN, Intent.CATEGORY_APP_EMAIL).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    if (isIntentResolvable(mailIntent)) intent = mailIntent
                } catch (_: Exception) {}
            }
            lower == "gallery" || lower == "photos" -> {
                try {
                    val galIntent = Intent.makeMainSelectorActivity(Intent.ACTION_MAIN, Intent.CATEGORY_APP_GALLERY).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    if (isIntentResolvable(galIntent)) intent = galIntent
                } catch (_: Exception) {}
            }
            lower == "files" || lower == "file manager" || lower == "my files" -> {
                try {
                    val filesIntent = Intent.makeMainSelectorActivity(Intent.ACTION_MAIN, Intent.CATEGORY_APP_FILES).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    if (isIntentResolvable(filesIntent)) intent = filesIntent
                } catch (_: Exception) {}
            }
        }

        if (intent != null) {
            try {
                startActivity(intent)
                val resolveInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    pm.resolveActivity(intent, PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_DEFAULT_ONLY.toLong()))
                } else {
                    @Suppress("DEPRECATION")
                    pm.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
                }
                val pkg = resolveInfo?.activityInfo?.packageName
                if (!pkg.isNullOrEmpty() && pkg != "android") {
                    lastExternalPackage = pkg
                    Log.d(TAG, "Launched default system app for '$keyword': $pkg")
                }
                return true
            } catch (e: Exception) {
                Log.w(TAG, "Failed launching default app intent for '$keyword': ${e.message}")
            }
        }
        return false
    }

    data class AppCandidate(val label: String, val packageName: String, val icon: Drawable? = null)

    /**
     * Resolves app launch request. If an exact match exists or only 1 fuzzy candidate matches,
     * launches immediately; if multiple candidates match, presents the overlay disambiguation dialog.
     */
    fun launchOrResolveApp(query: String, context: Context = this) {
        val q = query.trim()
        if (q.isEmpty()) {
            sendBotFeedback("⚠️ Bot Alert: Empty app query.")
            return
        }

        // Check if query is a known system category (e.g. Contacts, Browser, Phone)
        if (launchDefaultApp(q)) {
            sendBotFeedback("✅ Done: Opened $q.")
            return
        }

        val pm = context.packageManager
        val launcherIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }

        val installedApps = pm.queryIntentActivities(launcherIntent, 0).map { resolveInfo ->
            AppCandidate(
                label = resolveInfo.loadLabel(pm).toString(),
                packageName = resolveInfo.activityInfo.packageName,
                icon = resolveInfo.loadIcon(pm)
            )
        }

        // 1. Exact match check (case-insensitive)
        val exactMatch = installedApps.firstOrNull {
            it.label.equals(q, ignoreCase = true) || it.packageName.equals(q, ignoreCase = true)
        }
        if (exactMatch != null) {
            openPackage(exactMatch, context)
            return
        }

        // 2. Fuzzy / partial match check
        val candidates = installedApps.filter {
            it.label.contains(q, ignoreCase = true) ||
            it.packageName.contains(q, ignoreCase = true)
        }.distinctBy { it.packageName }

        when {
            candidates.size == 1 -> openPackage(candidates.first(), context)
            candidates.size > 1 -> {
                // Ambiguous: Present GUI selection dialog with native app icons over active app
                FloatingBubbleService.showDisambiguationDialog(
                    title = "🤔 Multiple apps match \"$q\". Which one?",
                    options = candidates.map {
                        ChoiceOption(
                            label = it.label,
                            subtitle = it.packageName,
                            icon = it.icon
                        )
                    }
                ) { selectedIndex ->
                    if (selectedIndex in candidates.indices) {
                        openPackage(candidates[selectedIndex], context)
                    }
                }
            }
            else -> {
                sendBotFeedback("⚠️ Bot Alert: No installed app matched \"$q\".")
            }
        }
    }

    private fun openPackage(app: AppCandidate, context: Context) {
        requestAppPermissionIfNeeded(
            packageName = app.packageName,
            actionDescription = "Open ${app.label} and interact with screen",
            onGranted = {
                val pm = context.packageManager
                val launchIntent = pm.getLaunchIntentForPackage(app.packageName)
                if (launchIntent != null) {
                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(launchIntent)
                    lastExternalPackage = app.packageName
                    sendBotFeedback("✅ Done: Opened ${app.label}.")
                } else {
                    sendBotFeedback("⚠️ Bot Error: Cannot launch ${app.label}.")
                }
            },
            onDenied = {
                sendBotFeedback("🚫 Cannot open ${app.label}: Access denied by user.")
            }
        )
    }

    /**
     * Launches an installed external Android app by its human name (e.g. "Contacts", "Chrome")
     * or package name (e.g. "com.google.android.contacts"). Prioritizes the user's default app.
     */
    @JvmOverloads
    fun launchAppByPackageOrName(nameOrPackage: String, broadcastFeedback: Boolean = true): Boolean {
        val query = nameOrPackage.trim()
        var launched = false
        var feedback = "✅ Done: Launch $query completed."
        try {
            if (query.isEmpty()) {
                feedback = "⚠️ Bot Alert: Empty app name."
                return false
            }

            // 1. Check if the query refers to a system default app category first
            if (launchDefaultApp(query)) {
                launched = true
                return true
            }

            val pm = packageManager

            // 2. Direct package launch
            val directIntent = pm.getLaunchIntentForPackage(query)
            if (directIntent != null) {
                directIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(directIntent)
                lastExternalPackage = query
                launched = true
                return true
            }

            // 3. Search launchable activities by app label or partial package name
            val apps = getInstalledApps(query)
            val bestMatch = apps.firstOrNull {
                it["appName"].equals(query, ignoreCase = true) ||
                    it["packageName"].equals(query, ignoreCase = true)
            } ?: apps.firstOrNull()

            if (bestMatch != null) {
                val pkg = bestMatch["packageName"]
                if (pkg != null) {
                    val launchIntent = pm.getLaunchIntentForPackage(pkg)
                    if (launchIntent != null) {
                        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(launchIntent)
                        lastExternalPackage = pkg
                        launched = true
                        return true
                    }
                }
            }
            return false
        } catch (e: Exception) {
            feedback = "❌ Bot Failed: ${e.localizedMessage?.take(40) ?: "Unknown error"}"
            return false
        } finally {
            if (!launched && !feedback.startsWith("❌") && query.isNotEmpty()) {
                feedback = "⚠️ Bot Alert: App '$query' not found."
            }
            if (broadcastFeedback) {
                sendBotFeedback(feedback)
            }
        }
    }
}
