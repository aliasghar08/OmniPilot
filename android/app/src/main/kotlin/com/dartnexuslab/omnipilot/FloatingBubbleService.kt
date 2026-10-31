package com.dartnexuslab.omnipilot

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.EditText
import android.widget.HorizontalScrollView
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast

class FloatingBubbleService : Service() {

    private var windowManager: WindowManager? = null
    private var floatingBubbleView: View? = null
    private var floatingPanelView: View? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    private var panelParams: WindowManager.LayoutParams? = null

    private var statusTextView: TextView? = null
    private var promptInput: EditText? = null
    private var targetAppBadge: TextView? = null

    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        private const val CHANNEL_ID = "floating_bubble_channel"
        private const val NOTIFICATION_ID = 2001
        const val ACTION_SHOW_PANEL = "com.dartnexuslab.omnipilot.SHOW_PANEL"
        const val ACTION_TOGGLE = "com.dartnexuslab.omnipilot.TOGGLE"

        @Volatile
        var isRunning = false
            private set

        @Volatile
        var currentInstance: FloatingBubbleService? = null
            private set

        /**
         * Callback registered by MainActivity to process natural-language prompts via Flutter's Gemini AssistantController.
         */
        var onOverlayPromptHandler: ((String, (String) -> Unit) -> Unit)? = null
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        currentInstance = this
        createNotificationChannel()

        val notification = buildForegroundNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val fgsType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            } else {
                0
            }
            startForeground(NOTIFICATION_ID, notification, fgsType)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        setupFloatingBubble()
        setupFloatingCommandPanel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW_PANEL -> {
                mainHandler.post { expandCommandPanel() }
            }
            ACTION_TOGGLE -> {
                mainHandler.post { toggleCommandPanel() }
            }
        }
        return START_STICKY
    }

    fun toggleCommandPanel() {
        if (floatingPanelView?.visibility == View.VISIBLE) {
            collapseCommandPanel()
        } else {
            expandCommandPanel()
        }
    }

    private fun overlayLayoutType(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
    }

    private fun dp(value: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            resources.displayMetrics
        ).toInt()
    }

    private fun setupFloatingBubble() {
        val params = WindowManager.LayoutParams(
            dp(58),
            dp(58),
            overlayLayoutType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp(16)
            y = dp(120)
        }
        bubbleParams = params

        val bubble = ImageView(this).apply {
            val bg = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#0F172A"))
                setStroke(dp(2), Color.parseColor("#38BDF8"))
            }
            background = bg
            setImageResource(R.mipmap.ic_launcher)
            scaleType = ImageView.ScaleType.FIT_CENTER
            val pad = dp(4)
            setPadding(pad, pad, pad, pad)
            elevation = dp(8).toFloat()
        }

        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var isClick = false
        val clickSlop = dp(20)

        bubble.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isClick = true
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val deltaX = (event.rawX - initialTouchX).toInt()
                    val deltaY = (event.rawY - initialTouchY).toInt()
                    if (Math.abs(deltaX) > clickSlop || Math.abs(deltaY) > clickSlop) {
                        isClick = false
                    }
                    params.x = initialX + deltaX
                    params.y = initialY + deltaY
                    try {
                        windowManager?.updateViewLayout(bubble, params)
                    } catch (_: Exception) {}
                    true
                }
                MotionEvent.ACTION_UP -> {
                    val deltaX = (event.rawX - initialTouchX).toInt()
                    val deltaY = (event.rawY - initialTouchY).toInt()
                    if (isClick && Math.abs(deltaX) <= clickSlop && Math.abs(deltaY) <= clickSlop) {
                        expandCommandPanel()
                    }
                    true
                }
                else -> false
            }
        }

        floatingBubbleView = bubble
        try {
            windowManager?.addView(bubble, params)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun setupFloatingCommandPanel() {
        val screenWidth = resources.displayMetrics.widthPixels
        val panelWidth = (screenWidth * 0.92).toInt()

        // Start with FLAG_NOT_FOCUSABLE so underlying app keeps window focus until user taps the input box
        val params = WindowManager.LayoutParams(
            panelWidth,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayLayoutType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = dp(64)
        }
        panelParams = params

        val rootCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val bg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(18).toFloat()
                setColor(Color.parseColor("#F8FAFC"))
                setStroke(dp(2), Color.parseColor("#3B82F6"))
            }
            background = bg
            val pad = dp(14)
            setPadding(pad, pad, pad, pad)
            elevation = dp(12).toFloat()
            visibility = View.GONE
        }

        // 1. Header Row
        val headerRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val headerIcon = ImageView(this).apply {
            setImageResource(R.mipmap.ic_launcher)
            scaleType = ImageView.ScaleType.FIT_CENTER
            layoutParams = LinearLayout.LayoutParams(dp(34), dp(34)).apply {
                marginEnd = dp(10)
            }
        }
        headerRow.addView(headerIcon)

        val titleCol = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }

        val titleText = TextView(this).apply {
            text = "OmniPilot Overlay"
            setTextColor(Color.parseColor("#0F172A"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            setTypeface(typeface, Typeface.BOLD)
        }

        val badgeText = TextView(this).apply {
            text = "Target: Detecting active app..."
            setTextColor(Color.parseColor("#475569"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            ellipsize = TextUtils.TruncateAt.END
            maxLines = 1
        }
        targetAppBadge = badgeText

        titleCol.addView(titleText)
        titleCol.addView(badgeText)

        val openAppBtn = createSmallButton("↗ App", "#E2E8F0", "#1E293B") {
            collapseCommandPanel()
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            startActivity(intent)
        }

        val closeBtn = createSmallButton("✕", "#FEE2E2", "#991B1B") {
            collapseCommandPanel()
        }

        headerRow.addView(titleCol)
        headerRow.addView(openAppBtn)
        headerRow.addView( View(this).apply { layoutParams = LinearLayout.LayoutParams(dp(6), dp(1)) } )
        headerRow.addView(closeBtn)

        // 2. Quick Action Chips Row
        val chipScroll = HorizontalScrollView(this).apply {
            isHorizontalScrollBarEnabled = false
            setPadding(0, dp(8), 0, dp(6))
        }
        val chipRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
        }

        chipRow.addView(createActionChip("🌐 Google Search & Write") {
            val customTopic = promptInput?.text?.toString()?.trim().orEmpty()
            val topic = if (customTopic.isNotEmpty()) customTopic else "Quantum Computing"
            executeUserInstructionOverApp("Search Google for $topic and write in notes")
        })
        chipRow.addView(createActionChip("🔍 Check Writes & Fields") {
            runWithUnderlyingAppFocus {
                performNativeInspectAndVerify()
            }
        })
        chipRow.addView(createActionChip("📝 Write AI Note") {
            runWithUnderlyingAppFocus {
                performAiNoteWriteWorkflow()
            }
        })
        chipRow.addView(createActionChip("✍️ Quick Fill Form") {
            runWithUnderlyingAppFocus {
                performQuickFillDemo()
            }
        })
        chipRow.addView(createActionChip("✅ Click Save/Submit") {
            runWithUnderlyingAppFocus {
                val service = AttendanceAccessibilityService.instance
                val clicked = service?.clickElement("Save") == true ||
                    service?.clickElement("Submit") == true ||
                    service?.clickElement("Done") == true
                updateStatus(
                    if (clicked) "✅ Clicked Save/Submit button on active screen!"
                    else "⚠️ Could not find a 'Save' or 'Submit' button on screen."
                )
            }
        })
        chipRow.addView(createActionChip("⬇️ Scroll Down") {
            runWithUnderlyingAppFocus {
                val ok = AttendanceAccessibilityService.instance?.scrollScreen("down") ?: false
                updateStatus(if (ok) "⬇️ Scrolled down." else "⚠️ Could not scroll.")
            }
        })
        chipRow.addView(createActionChip("◀ Back") {
            runWithUnderlyingAppFocus {
                AttendanceAccessibilityService.instance?.performSystemNavigation("BACK")
                updateStatus("◀ Navigated Back.")
            }
        })

        chipScroll.addView(chipRow)

        // 3. Prompt Input Row
        val inputRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, dp(4), 0, dp(6))
        }

        val edit = EditText(this).apply {
            hint = "Ask anything, search Google, or control this app..."
            setHintTextColor(Color.parseColor("#94A3B8"))
            setTextColor(Color.parseColor("#0F172A"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setSingleLine(true)
            val editBg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(10).toFloat()
                setColor(Color.WHITE)
                setStroke(dp(1), Color.parseColor("#CBD5E1"))
            }
            background = editBg
            setPadding(dp(10), dp(8), dp(10), dp(8))
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)

            setOnTouchListener { v, event ->
                if (event.action == MotionEvent.ACTION_DOWN) {
                    enablePanelKeyboardFocus(true)
                    v.requestFocus()
                    val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                    imm.showSoftInput(v, InputMethodManager.SHOW_IMPLICIT)
                }
                false
            }
        }
        promptInput = edit

        val sendBtn = createSmallButton("Run AI", "#2563EB", "#FFFFFF") {
            val text = edit.text?.toString()?.trim() ?: ""
            if (text.isEmpty()) {
                Toast.makeText(this, "Enter an instruction first", Toast.LENGTH_SHORT).show()
            } else {
                executeUserInstructionOverApp(text)
            }
        }

        inputRow.addView(edit)
        inputRow.addView(View(this).apply { layoutParams = LinearLayout.LayoutParams(dp(8), dp(1)) })
        inputRow.addView(sendBtn)

        // 4. Status / Output Scroll Area
        val statusScroll = ScrollView(this).apply {
            val scrollBg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(10).toFloat()
                setColor(Color.parseColor("#0F172A"))
            }
            background = scrollBg
            val pad = dp(10)
            setPadding(pad, pad, pad, pad)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(135)
            )
        }

        val statusTv = TextView(this).apply {
            text = "Ready. Tap 'Check Writes & Fields' to inspect the active app or type a prompt above."
            setTextColor(Color.parseColor("#E2E8F0"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            typeface = Typeface.MONOSPACE
        }
        statusTextView = statusTv
        statusScroll.addView(statusTv)

        rootCard.addView(headerRow)
        rootCard.addView(chipScroll)
        rootCard.addView(inputRow)
        rootCard.addView(statusScroll)

        floatingPanelView = rootCard
        try {
            windowManager?.addView(rootCard, params)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun createSmallButton(
        label: String,
        bgColorHex: String,
        textColorHex: String,
        onClick: () -> Unit
    ): Button {
        return Button(this).apply {
            text = label
            isAllCaps = false
            setTextColor(Color.parseColor(textColorHex))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            minWidth = 0
            minimumWidth = 0
            minHeight = 0
            minimumHeight = 0
            setPadding(dp(12), dp(7), dp(12), dp(7))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(10).toFloat()
                setColor(Color.parseColor(bgColorHex))
            }
            setOnClickListener { onClick() }
        }
    }

    private fun createActionChip(label: String, onClick: () -> Unit): TextView {
        return TextView(this).apply {
            text = label
            setTextColor(Color.parseColor("#1E40AF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11.5f)
            setTypeface(typeface, Typeface.BOLD)
            setPadding(dp(10), dp(6), dp(10), dp(6))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(14).toFloat()
                setColor(Color.parseColor("#DBEAFE"))
                setStroke(dp(1), Color.parseColor("#93C5FD"))
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                marginEnd = dp(6)
            }
            setOnClickListener { onClick() }
        }
    }

    private fun enablePanelKeyboardFocus(focusable: Boolean) {
        val panel = floatingPanelView ?: return
        val params = panelParams ?: return
        if (focusable) {
            params.flags = params.flags and WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE.inv()
        } else {
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
            imm.hideSoftInputFromWindow(panel.windowToken, 0)
            params.flags = params.flags or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
        }
        try {
            windowManager?.updateViewLayout(panel, params)
        } catch (_: Exception) {}
    }

    /**
     * Temporarily hides the overlay panel for 150ms so Android / Jetpack Compose
     * exposes 100% of underlying nodes without occlusion, runs [action], and restores the panel.
     */
    private fun runWithUnderlyingAppFocus(action: () -> Unit) {
        enablePanelKeyboardFocus(false)
        floatingPanelView?.visibility = View.GONE
        mainHandler.postDelayed({
            try {
                action()
            } finally {
                mainHandler.postDelayed({
                    floatingPanelView?.visibility = View.VISIBLE
                }, 120L)
            }
        }, 160L)
    }

    private fun expandCommandPanel() {
        floatingBubbleView?.visibility = View.GONE
        enablePanelKeyboardFocus(false)
        // Inspect BEFORE showing the panel so zero nodes are occluded by the overlay
        performNativeInspectAndVerify()
        floatingPanelView?.visibility = View.VISIBLE
    }

    private fun collapseCommandPanel() {
        enablePanelKeyboardFocus(false)
        floatingPanelView?.visibility = View.GONE
        floatingBubbleView?.visibility = View.VISIBLE
    }

    private fun updateStatus(message: String) {
        mainHandler.post {
            statusTextView?.text = message
        }
    }

    private fun performNativeInspectAndVerify() {
        val service = AttendanceAccessibilityService.instance
        if (service == null) {
            updateStatus("⚠️ Accessibility Service is disabled. Enable it in Android Settings > Accessibility.")
            return
        }

        val snapshot = service.getScreenSnapshot(preferExternal = true)
        val pkg = snapshot["activePackage"]?.toString() ?: "Unknown"
        mainHandler.post {
            targetAppBadge?.text = "Target App: $pkg"
        }

        @Suppress("UNCHECKED_CAST")
        val fields = (snapshot["editableFields"] as? List<Map<String, Any>>) ?: emptyList()
        @Suppress("UNCHECKED_CAST")
        val buttons = (snapshot["clickableElements"] as? List<Map<String, Any>>) ?: emptyList()

        val sb = StringBuilder()
        sb.appendLine("📱 Active App: $pkg")
        sb.appendLine("✏️ Editable Fields (${fields.size}):")
        if (fields.isEmpty()) {
            sb.appendLine("  (No editable inputs on current screen)")
        } else {
            for (f in fields) {
                val idx = f["index"]
                val lbl = f["label"]?.toString()?.ifEmpty { f["shortId"]?.toString() ?: "Field" }
                val valStr = f["text"]?.toString() ?: ""
                val state = if (valStr.isNotEmpty()) "✅ Written: \"$valStr\"" else "⬜ Empty"
                sb.appendLine("  #$idx [$lbl] -> $state")
            }
        }

        val btnLabels = buttons.mapNotNull { it["label"]?.toString()?.takeIf { s -> s.isNotEmpty() } }.distinct().take(8)
        if (btnLabels.isNotEmpty()) {
            sb.appendLine("🔘 Buttons: ${btnLabels.joinToString(", ")}")
        }

        updateStatus(sb.toString().trim())
    }

    private fun performAiNoteWriteWorkflow() {
        val service = AttendanceAccessibilityService.instance
        if (service == null) {
            updateStatus("⚠️ Accessibility Service is disabled.")
            return
        }

        Thread {
            val snapshot = service.getScreenSnapshot(preferExternal = true)
            val pkg = snapshot["activePackage"]?.toString() ?: ""

            // Step 1: If the app has a "Create a new note" button (e.g. Fossify Notes), click it & title the note!
            var createdNewTab = false
            if (service.clickElement("Create a new note") || service.clickElement("New note")) {
                try { Thread.sleep(500) } catch (_: InterruptedException) {}
                service.writeFieldsWithVerification(mapOf("#0" to "Class 10-A AI Report"), append = false)
                try { Thread.sleep(300) } catch (_: InterruptedException) {}
                createdNewTab = service.clickElement("OK") || service.clickElement("Create")
                try { Thread.sleep(500) } catch (_: InterruptedException) {}
            }

            // Step 2: Write structured multi-line AI note into the note editor & verify
            val noteBody = buildString {
                appendLine("📋 CLASS 10-A ATTENDANCE & AI LOG")
                appendLine("Date: October 29, 2026")
                appendLine("----------------------------------------")
                appendLine("✅ Summary: 28 Present / 30 Total (93.3%)")
                appendLine("")
                appendLine("👤 Verified Student Records:")
                appendLine("1. Ali Asghar (Roll #12) — Present")
                appendLine("2. Fatima Khan (Roll #08) — Present")
                appendLine("3. Zayd Ahmed (Roll #19) — Late")
                appendLine("4. Sara Malik (Roll #04) — Absent")
                appendLine("")
                appendLine("🤖 Action Items:")
                appendLine("• Synced attendance sheet with Cloud Firestore")
                appendLine("• Verified external form writes via Accessibility Copilot")
            }.trim()

            val writeResults = service.writeFieldsWithVerification(mapOf("#0" to noteBody), append = false)
            @Suppress("UNCHECKED_CAST")
            val info = writeResults["#0"] as? Map<String, Any>
            val verifiedVal = info?.get("verifiedValue")?.toString() ?: ""
            val isVerified = info?.get("verified") == true

            val report = buildString {
                appendLine("📝 AI Note Written in $pkg")
                if (createdNewTab) {
                    appendLine("➕ Created New Note Tab: \"Class 10-A AI Report\"")
                }
                appendLine("✔️ Write Verified: $isVerified (${verifiedVal.length} chars)")
                appendLine("📄 Preview: \"${verifiedVal.lines().firstOrNull() ?: ""}\"")
            }.trim()

            updateStatus(report)
        }.start()
    }

    private fun performQuickFillDemo() {
        val service = AttendanceAccessibilityService.instance
        if (service == null) {
            updateStatus("⚠️ Accessibility Service is disabled.")
            return
        }

        val snapshot = service.getScreenSnapshot(preferExternal = true)
        @Suppress("UNCHECKED_CAST")
        val fields = (snapshot["editableFields"] as? List<Map<String, Any>>) ?: emptyList()
        if (fields.isEmpty()) {
            updateStatus("⚠️ No editable fields detected on this screen.")
            return
        }

        // Smart default mapping based on detected field labels
        val payload = mutableMapOf<String, String>()
        val sampleValues = listOf("Ali Asghar", "1024", "Class 10-A", "+1555019283", "Present - Verified by Copilot")

        for ((i, f) in fields.withIndex()) {
            val lbl = (f["label"]?.toString() ?: "").lowercase()
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

        val writeResults = service.writeFieldsWithVerification(payload, append = false)
        val sb = StringBuilder("✨ Autofill & Write Verification:\n")
        for ((k, v) in writeResults) {
            @Suppress("UNCHECKED_CAST")
            val info = v as? Map<String, Any> ?: continue
            val lbl = info["matchedLabel"] ?: k
            val written = info["verifiedValue"] ?: info["writtenValue"]
            val ok = info["verified"] == true || info["success"] == true
            sb.appendLine("${if (ok) "✅" else "❌"} [$lbl] = \"$written\"")
        }
        updateStatus(sb.toString().trim())
    }

    private fun executeUserInstructionOverApp(prompt: String) {
        updateStatus("🤖 Running instruction on active app...\n\"$prompt\"")
        runWithUnderlyingAppFocus {
            val handler = onOverlayPromptHandler
            if (handler != null) {
                handler.invoke(prompt) { aiReply ->
                    updateStatus("🤖 Gemini Copilot:\n$aiReply")
                }
            } else {
                // Offline / direct native parser fallback if Flutter engine is detached
                val fallbackResult = executeDirectNativeInstruction(prompt)
                updateStatus(fallbackResult)
            }
        }
    }

    private fun executeDirectNativeInstruction(prompt: String): String {
        val service = AttendanceAccessibilityService.instance
            ?: return "⚠️ Accessibility Service is not enabled."

        val lower = prompt.lowercase()
        if (lower.contains("inspect") || lower.contains("check") || lower.contains("read")) {
            performNativeInspectAndVerify()
            return statusTextView?.text?.toString() ?: "Inspected."
        }

        // Parse key=value or key: value pairs if present
        val map = mutableMapOf<String, String>()
        val pairRegex = Regex("([A-Za-z0-9_# ]+)[:=]\\s*([^,\\n]+)")
        for (m in pairRegex.findAll(prompt)) {
            val k = m.groupValues[1].trim()
            val v = m.groupValues[2].trim()
            if (k.isNotEmpty() && v.isNotEmpty()) {
                map[k] = v
            }
        }

        if (map.isNotEmpty()) {
            val res = service.writeFieldsWithVerification(map)
            return "✅ Executed field writes: $res"
        }

        // 0. App Launch commands in human language (e.g. "open contacts", "launch browser", "start chrome")
        val openPrefixes = listOf("open ", "launch ", "start ", "go to ")
        for (pfx in openPrefixes) {
            if (lower.startsWith(pfx)) {
                val appTarget = prompt.substring(pfx.length).trim()
                val ok = service.launchAppByPackageOrName(appTarget)
                return if (ok) "🚀 Launched $appTarget" else "⚠️ Could not open $appTarget"
            }
        }

        // 1. Natural language field extraction (Name, Phone, Email, B-Form/CNIC, etc.)
        val humanFields = mutableMapOf<String, String>()

        // Phone number matching (Pakistani or international/standard format)
        val phoneMatch = Regex("""(?:\+?92|0)?3[0-9]{2}[-\s]?[0-9]{7}|(?:\+?1|0)?[0-9]{10,11}""").find(prompt)
        if (phoneMatch != null) {
            humanFields["phone"] = phoneMatch.value.trim()
        }

        // Email address matching
        val emailMatch = Regex("""[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}""").find(prompt)
        if (emailMatch != null) {
            humanFields["email"] = emailMatch.value.trim()
        }

        // CNIC / B-Form matching
        val cnicMatch = Regex("""[0-9]{5}-?[0-9]{7}-?[0-9]""").find(prompt)
        if (cnicMatch != null) {
            humanFields["bForm"] = cnicMatch.value.trim()
            humanFields["cnic"] = cnicMatch.value.trim()
        }

        // Name extraction from natural phrases ("for Ali Asghar", "name is Ali", "name Ali", "student Ali Asghar")
        val nameMatch = Regex("""(?:name\s*(?:is|:)?|for|student\s*(?:is|:)?)\s+([A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+)?)""").find(prompt)
            ?: Regex("""(?:put|enter|write)\s+([A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+)?)\s+(?:as|in|for)\s+(?:name|contact)""").find(prompt)
        if (nameMatch != null) {
            val fullName = nameMatch.groupValues[1].trim()
            if (fullName.contains(" ")) {
                humanFields["firstName"] = fullName.substringBefore(" ")
                humanFields["lastName"] = fullName.substringAfter(" ")
            } else {
                humanFields["firstName"] = fullName
                humanFields["studentName"] = fullName
            }
        }

        if (humanFields.isNotEmpty()) {
            val res = service.writeFieldsWithVerification(humanFields)
            val sb = StringBuilder("✨ Human Language Auto-Fill:\n")
            for ((k, v) in res) {
                @Suppress("UNCHECKED_CAST")
                val info = v as? Map<String, Any> ?: continue
                val lbl = info["matchedLabel"] ?: k
                val written = info["verifiedValue"] ?: info["writtenValue"]
                val ok = info["verified"] == true || info["success"] == true
                sb.appendLine("${if (ok) "✅" else "❌"} [$lbl] = \"$written\"")
            }
            if (lower.contains("save") || lower.contains("done") || lower.contains("submit")) {
                mainHandler.postDelayed({
                    service.clickElement("Save") || service.clickElement("Done") || service.clickElement("Submit")
                }, 400L)
            }
            return sb.toString().trim()
        }

        // 1. Direct text typing into whatever third-party app is currently open
        val writePrefixes = listOf("type ", "input ", "write ", "enter ", "fill ", "paste ")
        for (pfx in writePrefixes) {
            if (lower.startsWith(pfx)) {
                val value = prompt.substring(pfx.length).trim().removeSurrounding("\"").removeSurrounding("'")
                val writeRes = service.writeFieldsWithVerification(mapOf("#0" to value))
                val sb = StringBuilder("✨ Typed into Active App:\n")
                for ((k, v) in writeRes) {
                    @Suppress("UNCHECKED_CAST")
                    val info = v as? Map<String, Any> ?: continue
                    val lbl = info["matchedLabel"] ?: k
                    val written = info["verifiedValue"] ?: info["writtenValue"]
                    val ok = info["verified"] == true || info["success"] == true
                    sb.appendLine("${if (ok) "✅" else "❌"} [$lbl] = \"$written\"")
                }
                return sb.toString().trim()
            }
        }

        // 2. Navigation commands in third party apps
        if (lower.contains("scroll down")) {
            val ok = service.scrollScreen("down")
            return if (ok) "⬇️ Scrolled down." else "⚠️ Could not scroll."
        }
        if (lower.contains("scroll up")) {
            val ok = service.scrollScreen("up")
            return if (ok) "⬆️ Scrolled up." else "⚠️ Could not scroll."
        }
        if (lower.equals("back", ignoreCase = true) || lower.startsWith("go back")) {
            service.performSystemNavigation("BACK")
            return "◀ Navigated Back."
        }

        if (lower.startsWith("click ") || lower.startsWith("tap ") || lower.startsWith("press ")) {
            val target = prompt.substringAfter(" ").trim()
            val ok = service.clickElement(target)
            return if (ok) "✅ Clicked '$target'" else "⚠️ Could not find '$target'"
        }

        performQuickFillDemo()
        return statusTextView?.text?.toString() ?: "Done."
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "OmniPilot Overlay",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows the floating OmniPilot AI assistant overlay over other apps"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildForegroundNotification(): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(this, 0, notificationIntent, flags)

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("OmniPilot Assistant Active")
                .setContentText("Tap to open OmniPilot • Tap floating bubble to inspect & control any app")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentIntent(pendingIntent)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("OmniPilot Assistant Active")
                .setContentText("Tap to open OmniPilot • Tap floating bubble to inspect & control any app")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentIntent(pendingIntent)
                .build()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        if (currentInstance == this) {
            currentInstance = null
        }
        floatingBubbleView?.let {
            try {
                windowManager?.removeView(it)
            } catch (_: Exception) {}
        }
        floatingPanelView?.let {
            try {
                windowManager?.removeView(it)
            } catch (_: Exception) {}
        }
    }
}
