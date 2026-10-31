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

        // If overlay permission is already granted, launch the floating assistant bubble
        mainHandler.post {
            try {
                val hasOverlay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    Settings.canDrawOverlays(this)
                } else {
                    true
                }
                if (hasOverlay && !FloatingBubbleService.isRunning) {
                    val intent = Intent(this, FloatingBubbleService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    Log.d(TAG, "Auto-started FloatingBubbleService on Accessibility connect")
                }
            } catch (e: Exception) {
                Log.w(TAG, "Floating bubble launch deferred: ${e.message}")
            }
        }
    }

    /**
     * Responds immediately when the user taps the Android system accessibility button
     * or triggers the Accessibility Shortcut.
     */
    fun handleAccessibilityShortcutTriggered() {
        mainHandler.post {
            try {
                val hasOverlay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    Settings.canDrawOverlays(this)
                } else {
                    true
                }

                if (hasOverlay) {
                    val bubbleInstance = FloatingBubbleService.currentInstance
                    if (FloatingBubbleService.isRunning && bubbleInstance != null) {
                        bubbleInstance.toggleCommandPanel()
                    } else {
                        val intent = Intent(this, FloatingBubbleService::class.java).apply {
                            action = FloatingBubbleService.ACTION_SHOW_PANEL
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                    }
                } else {
                    val intent = Intent(this, MainActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    }
                    startActivity(intent)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error handling accessibility shortcut trigger: ${e.message}", e)
            }
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val pkg = event?.packageName?.toString() ?: return
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
            val launched = launchAppByPackageOrName(targetPkg)
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
    fun writeFieldsWithVerification(
        fieldMappings: Map<String, String>,
        append: Boolean = false
    ): Map<String, Any> {
        val roots = getTargetRoots(preferExternal = true)
        if (roots.isEmpty()) return emptyMap()

        val editableEntries = mutableListOf<EditableNodeEntry>()
        for (root in roots) {
            if (roots.size > 1 && root.packageName?.toString() == packageName) continue
            collectEditableEntries(root, editableEntries)
        }

        val results = mutableMapOf<String, Any>()
        val usedIndices = mutableSetOf<Int>()

        for ((key, valueToSet) in fieldMappings) {
            val match = findBestEditableEntry(editableEntries, key, usedIndices)
            if (match != null) {
                usedIndices.add(match.index)
                val node = match.node
                val prevValue = getActualNodeText(node)
                val finalValue = if (append && prevValue.isNotEmpty()) "$prevValue$valueToSet" else valueToSet

                // Focus the node first
                node.performAction(AccessibilityNodeInfo.ACTION_FOCUS)

                // Perform ACTION_SET_TEXT
                val args = Bundle().apply {
                    putCharSequence(
                        AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                        finalValue
                    )
                }
                var actionSuccess = node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)

                // Fallback to Clipboard Paste if ACTION_SET_TEXT is unsupported by a custom view
                if (!actionSuccess) {
                    actionSuccess = pasteTextFallback(node, finalValue)
                }

                // Refresh node to verify actual text written
                try {
                    node.refresh()
                } catch (_: Exception) {}

                val verifiedValue = getActualNodeText(node)
                val isVerified = verifiedValue == finalValue || verifiedValue.contains(valueToSet)

                results[key] = mapOf(
                    "success" to (actionSuccess || isVerified),
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

        return results
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

    /**
     * Clicks a button or interactive element matching a target label, resource ID, or index (#0).
     * Automatically walks up parent hierarchy if the text node itself is not clickable,
     * and falls back to hardware coordinate tap gesture if ACTION_CLICK returns false.
     */
    fun clickElement(targetLabel: String): Boolean {
        val roots = getTargetRoots(preferExternal = true)
        if (roots.isEmpty()) return false

        val trimmed = targetLabel.trim()

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
                            if (node != null && performRobustClick(node)) return true
                        }
                    }
                    if (cx > 0 && cy > 0) {
                        return tapCoordinates(cx, cy)
                    }
                }
            }
        }

        for (root in roots) {
            if (roots.size > 1 && root.packageName?.toString() == packageName) continue
            val node = findNodeByTextOrId(root, trimmed)
            if (node != null && performRobustClick(node)) {
                return true
            }
        }
        return false
    }

    /**
     * Long-clicks a button or interactive element matching [targetLabel].
     */
    fun longClickElement(targetLabel: String): Boolean {
        val roots = getTargetRoots(preferExternal = true)
        if (roots.isEmpty()) return false
        for (root in roots) {
            if (roots.size > 1 && root.packageName?.toString() == packageName) continue
            val node = findNodeByTextOrId(root, targetLabel.trim())
            if (node != null) {
                var curr: AccessibilityNodeInfo? = node
                var depth = 0
                while (curr != null && depth < 5) {
                    if (curr.isLongClickable && curr.performAction(AccessibilityNodeInfo.ACTION_LONG_CLICK)) {
                        return true
                    }
                    curr = curr.parent
                    depth++
                }
                // Fallback to long-press gesture at node center
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
            }
        }
        return false
    }

    /**
     * Sets a Checkbox, Switch, RadioButton, or Toggle element to the desired [checked] state.
     */
    fun setCheckableState(targetLabel: String, checked: Boolean): Map<String, Any> {
        val roots = getTargetRoots(preferExternal = true)
        if (roots.isEmpty()) return mapOf("success" to false, "error" to "No active window")

        for (root in roots) {
            if (roots.size > 1 && root.packageName?.toString() == packageName) continue
            val node = findCheckableNode(root, targetLabel.trim())
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
                return mapOf(
                    "success" to clicked,
                    "changed" to clicked,
                    "isChecked" to node.isChecked
                )
            }
        }
        return mapOf("success" to false, "error" to "Checkable element '$targetLabel' not found")
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
    fun scrollScreen(direction: String): Boolean {
        val dir = direction.lowercase().trim()
        val roots = getTargetRoots(preferExternal = true)

        val scrollAction = when (dir) {
            "up", "backward", "top", "right" -> AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
            else -> AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
        }

        for (root in roots) {
            if (roots.size > 1 && root.packageName?.toString() == packageName) continue
            val scrollable = findScrollableNode(root)
            if (scrollable != null && scrollable.performAction(scrollAction)) {
                return true
            }
        }

        // Fallback to physical swipe gesture on screen
        val displayMetrics = resources.displayMetrics
        val w = displayMetrics.widthPixels.toFloat()
        val h = displayMetrics.heightPixels.toFloat()

        return when (dir) {
            "up", "backward" -> dispatchTapOrSwipe(w * 0.5f, h * 0.3f, w * 0.5f, h * 0.75f, 350L)
            "left" -> dispatchTapOrSwipe(w * 0.8f, h * 0.5f, w * 0.2f, h * 0.5f, 350L)
            "right" -> dispatchTapOrSwipe(w * 0.2f, h * 0.5f, w * 0.8f, h * 0.5f, 350L)
            else -> dispatchTapOrSwipe(w * 0.5f, h * 0.75f, w * 0.5f, h * 0.25f, 350L)
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
    fun performSystemNavigation(action: String): Boolean {
        val globalAction = when (action.uppercase().trim()) {
            "BACK", "GO_BACK", "NAVIGATE_BACK" -> GLOBAL_ACTION_BACK
            "HOME", "GO_HOME" -> GLOBAL_ACTION_HOME
            "RECENTS", "RECENT_APPS", "OVERVIEW" -> GLOBAL_ACTION_RECENTS
            "NOTIFICATIONS" -> GLOBAL_ACTION_NOTIFICATIONS
            "QUICK_SETTINGS" -> GLOBAL_ACTION_QUICK_SETTINGS
            else -> return false
        }
        return performGlobalAction(globalAction)
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

    /**
     * Launches an installed external Android app by its human name (e.g. "Contacts", "Chrome")
     * or package name (e.g. "com.google.android.contacts"). Prioritizes the user's default app.
     */
    fun launchAppByPackageOrName(nameOrPackage: String): Boolean {
        val query = nameOrPackage.trim()
        if (query.isEmpty()) return false

        // 1. Check if the query refers to a system default app category first
        if (launchDefaultApp(query)) {
            return true
        }

        val pm = packageManager

        // 2. Direct package launch
        val directIntent = pm.getLaunchIntentForPackage(query)
        if (directIntent != null) {
            directIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(directIntent)
            lastExternalPackage = query
            return true
        }

        // 2. Search launchable activities by app label or partial package name
        val apps = getInstalledApps(query)
        val bestMatch = apps.firstOrNull {
            it["appName"].equals(query, ignoreCase = true) ||
                it["packageName"].equals(query, ignoreCase = true)
        } ?: apps.firstOrNull()

        if (bestMatch != null) {
            val pkg = bestMatch["packageName"] ?: return false
            val launchIntent = pm.getLaunchIntentForPackage(pkg)
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(launchIntent)
                lastExternalPackage = pkg
                return true
            }
        }
        return false
    }
}
