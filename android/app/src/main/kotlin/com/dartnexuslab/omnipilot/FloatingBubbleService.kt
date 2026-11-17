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
import android.graphics.drawable.Drawable
import android.speech.tts.TextToSpeech
import android.widget.Toast
import java.util.ArrayDeque
import java.util.Locale

data class ChoiceOption(
    val label: String,
    val subtitle: String? = null,
    val icon: Drawable? = null
)

enum class PermissionDecision {
    ALLOW_ALWAYS,
    ALLOW_ONCE,
    DENY
}

class FloatingBubbleService : Service() {

    private var windowManager: WindowManager? = null
    private var floatingBubbleView: View? = null
    private var floatingPanelView: View? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    private var panelParams: WindowManager.LayoutParams? = null

    private var statusTextView: TextView? = null
    private var panelStatusTextView: TextView? = null
    private var promptInput: EditText? = null
    private var targetAppBadge: TextView? = null

    // Native Text-to-Speech Engine & Chat History Feed
    private var tts: TextToSpeech? = null
    private var ttsReady: Boolean = false
    private var speakerToggleBtn: Button? = null
    private var chatContainer: LinearLayout? = null
    private var chatScrollView: ScrollView? = null
    private val chatHistory = ArrayDeque<Pair<String, String>>()

    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        private const val CHANNEL_ID = "floating_bubble_channel"
        private const val NOTIFICATION_ID = 2001
        const val ACTION_SHOW_PANEL = "com.dartnexuslab.omnipilot.SHOW_PANEL"
        const val ACTION_TOGGLE = "com.dartnexuslab.omnipilot.TOGGLE"

        // Synced with Flutter SharedPreferences key "flutter.tts_voice_enabled"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_TTS_VOICE_ENABLED = "flutter.tts_voice_enabled"
        private const val ALT_KEY_TTS = "omni_tts_voice_enabled"

        @Volatile
        private var instance: FloatingBubbleService? = null

        val currentInstance: FloatingBubbleService?
            get() = instance

        @Volatile
        var isRunning = false
            private set

        /**
         * Checks whether TTS voice replies are enabled, checking Flutter SharedPreferences first.
         */
        val isTtsVoiceEnabled: Boolean
            get() {
                val ctx = instance ?: return true
                val sp = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                return if (sp.contains(KEY_TTS_VOICE_ENABLED)) {
                    sp.getBoolean(KEY_TTS_VOICE_ENABLED, true)
                } else {
                    ctx.getSharedPreferences("omnipilot_prefs", Context.MODE_PRIVATE)
                        .getBoolean(ALT_KEY_TTS, true)
                }
            }

        /**
         * Sets whether TTS voice replies are enabled, syncing to both SharedPreferences and updating the UI.
         */
        fun setTtsVoiceEnabled(enabled: Boolean) {
            instance?.let { service ->
                service.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    .edit()
                    .putBoolean(KEY_TTS_VOICE_ENABLED, enabled)
                    .apply()
                service.getSharedPreferences("omnipilot_prefs", Context.MODE_PRIVATE)
                    .edit()
                    .putBoolean(ALT_KEY_TTS, enabled)
                    .apply()
                Handler(Looper.getMainLooper()).post {
                    service.updateSpeakerButtonUI()
                }
            }
        }

        /**
         * Sanitizes feedback text for spoken TTS output: strips URLs, emojis, and markdown.
         */
        fun cleanTextForSpeech(text: String): String {
            if (text.isBlank()) return ""
            return text
                // Strip URLs
                .replace(Regex("""https?://\S+"""), "")
                // Strip emojis and unicode surrogate symbols
                .replace(Regex("""[\uD83C-\uDBFF\uDC00-\uDFFF]+"""), "")
                .replace(Regex("""[\u2600-\u27BF]"""), "")
                // Strip markdown formatting characters
                .replace(Regex("""[*#_~`>|\-]"""), " ")
                // Collapse multiple spaces/newlines into a single clean space
                .replace(Regex("""\s+"""), " ")
                .trim()
        }

        /**
         * Speaks [text] immediately via the native TTS engine if voice is enabled.
         */
        fun speakText(text: String) {
            instance?.let { service ->
                Handler(Looper.getMainLooper()).post {
                    service.speakTextDirectly(text)
                }
            }
        }

        /**
         * Callback registered by MainActivity to process natural-language prompts via Flutter's Gemini AssistantController.
         */
        var onOverlayPromptHandler: ((String, (String) -> Unit) -> Unit)? = null

        private fun View.removeCallbacksAndMessages(token: Any?) {
            handler?.removeCallbacksAndMessages(token)
        }

        fun updateStatusBubble(feedback: String) {
            instance?.let { service ->
                Handler(Looper.getMainLooper()).post {
                    service.statusTextView?.apply {
                        text = feedback
                        visibility = View.VISIBLE
                        // Auto-hide after 3.5 seconds
                        removeCallbacksAndMessages(null)
                        postDelayed({ visibility = View.GONE }, 3500)
                    }
                    service.panelStatusTextView?.text = feedback
                    service.addChatMessage("OmniPilot", feedback)
                    if (isTtsVoiceEnabled) {
                        service.speakTextDirectly(feedback)
                    }
                }
            }
        }

        fun showDisambiguationDialog(
            title: String,
            options: List<ChoiceOption>,
            onSelect: (Int) -> Unit
        ) {
            instance?.let { service ->
                Handler(Looper.getMainLooper()).post {
                    service.renderOverlayChoiceCard(title, options, onSelect)
                }
            }
        }

        fun showAppPermissionPopup(
            appLabel: String,
            packageName: String,
            appIcon: Drawable?,
            requestedScope: String,
            onDecision: (PermissionDecision) -> Unit
        ) {
            instance?.let { service ->
                Handler(Looper.getMainLooper()).post {
                    service.renderAppPermissionDialog(appLabel, packageName, appIcon, requestedScope, onDecision)
                }
            }
        }

        fun showSystemPermissionPopup(
            permissionKey: String,
            title: String,
            reason: String,
            pendingCommand: String? = null
        ) {
            instance?.let { service ->
                Handler(Looper.getMainLooper()).post {
                    service.renderSystemPermissionDialog(permissionKey, title, reason, pendingCommand)
                }
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        instance = this
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
        setupSlidingEdgeHandle()
        setupFloatingStatusBubble()
        setupFloatingCommandPanel()

        // Initialize Android TextToSpeech engine
        try {
            tts = TextToSpeech(this) { status ->
                if (status == TextToSpeech.SUCCESS) {
                    val result = tts?.setLanguage(Locale.US)
                    if (result != TextToSpeech.LANG_MISSING_DATA && result != TextToSpeech.LANG_NOT_SUPPORTED) {
                        tts?.setSpeechRate(1.05f)
                        ttsReady = true
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
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

    /**
     * Sets up a sleek, flush edge sliding tab/handle docked to the right edge of the screen.
     * Replaces the floating round overlay icon with an unobtrusive edge slider.
     */
    private fun setupSlidingEdgeHandle() {
        val handleWidth = dp(14)
        val handleHeight = dp(76)
        val screenH = resources.displayMetrics.heightPixels

        val params = WindowManager.LayoutParams(
            handleWidth,
            handleHeight,
            overlayLayoutType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            x = 0
            y = (screenH * 0.32).toInt()
        }
        bubbleParams = params

        val handleContainer = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL or Gravity.END
            isClickable = true
            isFocusable = false

            // Sleek inner pill docked flush to the screen edge with rounded inner corners
            val innerPill = View(context).apply {
                val pillBg = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE
                    cornerRadii = floatArrayOf(
                        dp(8).toFloat(), dp(8).toFloat(), // top-left
                        0f, 0f,                           // top-right
                        0f, 0f,                           // bottom-right
                        dp(8).toFloat(), dp(8).toFloat()  // bottom-left
                    )
                    setColor(Color.parseColor("#E60F172A"))
                    setStroke(dp(1), Color.parseColor("#38BDF8"))
                }
                background = pillBg
                elevation = dp(6).toFloat()
                layoutParams = LinearLayout.LayoutParams(dp(6), dp(62))
            }
            addView(innerPill)
        }

        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var isClick = false
        val clickSlop = dp(16)

        handleContainer.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isClick = true
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val deltaX = event.rawX - initialTouchX
                    val deltaY = (event.rawY - initialTouchY).toInt()

                    // Sliding inward (left swipe from right edge) smoothly opens the sliding menu
                    if (deltaX < -dp(18)) {
                        isClick = false
                        expandCommandPanel()
                        return@setOnTouchListener true
                    }

                    if (Math.abs(deltaY) > clickSlop) {
                        isClick = false
                        params.y = (initialY + deltaY).coerceIn(dp(40), screenH - dp(120))
                        try {
                            windowManager?.updateViewLayout(handleContainer, params)
                        } catch (_: Exception) {}
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    val deltaX = event.rawX - initialTouchX
                    val deltaY = event.rawY - initialTouchY
                    if (isClick && Math.abs(deltaX) <= clickSlop && Math.abs(deltaY) <= clickSlop) {
                        expandCommandPanel()
                    } else if (deltaX < -dp(14)) {
                        expandCommandPanel()
                    }
                    true
                }
                else -> false
            }
        }

        floatingBubbleView = handleContainer
        try {
            windowManager?.addView(handleContainer, params)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /**
     * Renders a brief, auto-dismissing bot reply badge directly over the active app
     * whenever an action finishes or fails.
     */
    private fun setupFloatingStatusBubble() {
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayLayoutType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = dp(24)
        }

        val badgeTv = TextView(this).apply {
            text = ""
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f)
            setTypeface(typeface, Typeface.BOLD)
            maxLines = 3
            ellipsize = TextUtils.TruncateAt.END
            setPadding(dp(14), dp(8), dp(14), dp(8))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(16).toFloat()
                setColor(Color.parseColor("#E60F172A"))
                setStroke(dp(1), Color.parseColor("#38BDF8"))
            }
            elevation = dp(10).toFloat()
            visibility = View.GONE
        }

        statusTextView = badgeTv
        try {
            windowManager?.addView(badgeTv, params)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun setupFloatingCommandPanel() {
        val screenWidth = resources.displayMetrics.widthPixels
        val panelWidth = (screenWidth * 0.93).toInt()

        // Start with FLAG_NOT_FOCUSABLE so underlying app keeps window focus until user taps the input box
        val params = WindowManager.LayoutParams(
            panelWidth,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayLayoutType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            x = dp(8)
            y = dp(52)
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
            setOnTouchListener { _, event ->
                if (event.action == MotionEvent.ACTION_OUTSIDE) {
                    collapseCommandPanel()
                    true
                } else {
                    false
                }
            }
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
            text = "OmniPilot Menu"
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

        val speakerBtn = createSmallButton(
            if (isTtsVoiceEnabled) "🔊 Voice On" else "🔇 Muted",
            if (isTtsVoiceEnabled) "#DCFCE7" else "#F1F5F9",
            if (isTtsVoiceEnabled) "#15803D" else "#64748B"
        ) {
            setTtsVoiceEnabled(!isTtsVoiceEnabled)
        }
        speakerToggleBtn = speakerBtn

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
        headerRow.addView(speakerBtn)
        headerRow.addView( View(this).apply { layoutParams = LinearLayout.LayoutParams(dp(4), dp(1)) } )
        headerRow.addView(openAppBtn)
        headerRow.addView( View(this).apply { layoutParams = LinearLayout.LayoutParams(dp(4), dp(1)) } )
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

        // 4. Status / Mini Chat History Feed Area
        val statusScroll = ScrollView(this).apply {
            val scrollBg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(10).toFloat()
                setColor(Color.parseColor("#0F172A"))
            }
            background = scrollBg
            val pad = dp(8)
            setPadding(pad, pad, pad, pad)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(145)
            )
            isVerticalScrollBarEnabled = true
        }
        chatScrollView = statusScroll

        val chatLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }
        chatContainer = chatLayout

        val statusTv = TextView(this).apply {
            text = "🤖 OmniPilot Ready. Tap chips or ask anything above..."
            setTextColor(Color.parseColor("#94A3B8"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setPadding(dp(4), dp(4), dp(4), dp(4))
        }
        panelStatusTextView = statusTv
        chatLayout.addView(statusTv)
        statusScroll.addView(chatLayout)

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

    fun updateSpeakerButtonUI() {
        val btn = speakerToggleBtn ?: return
        val enabled = isTtsVoiceEnabled
        if (enabled) {
            btn.text = "🔊 Voice On"
            btn.setTextColor(Color.parseColor("#15803D"))
            (btn.background as? GradientDrawable)?.setColor(Color.parseColor("#DCFCE7"))
        } else {
            btn.text = "🔇 Muted"
            btn.setTextColor(Color.parseColor("#64748B"))
            (btn.background as? GradientDrawable)?.setColor(Color.parseColor("#F1F5F9"))
        }
    }

    fun speakTextDirectly(rawText: String) {
        val clean = cleanTextForSpeech(rawText)
        if (clean.isBlank()) return
        if (ttsReady && tts != null) {
            try {
                tts?.speak(clean, TextToSpeech.QUEUE_FLUSH, null, "omnipilot_reply")
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    fun addChatMessage(sender: String, message: String) {
        if (message.isBlank()) return
        mainHandler.post {
            val container = chatContainer ?: return@post
            val scroll = chatScrollView

            // Keep max 15 messages in history
            if (chatHistory.size >= 15) {
                chatHistory.removeFirst()
                if (container.childCount > 0) {
                    container.removeViewAt(0)
                }
            }
            chatHistory.addLast(Pair(sender, message))

            val isUser = sender.equals("You", ignoreCase = true)
            val bubble = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                val bg = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE
                    cornerRadius = dp(8).toFloat()
                    if (isUser) {
                        setColor(Color.parseColor("#1D4ED8")) // vibrant blue
                    } else {
                        setColor(Color.parseColor("#1E293B")) // slate
                        setStroke(dp(1), Color.parseColor("#38BDF8"))
                    }
                }
                background = bg
                val padH = dp(10)
                val padV = dp(6)
                setPadding(padH, padV, padH, padV)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    gravity = if (isUser) Gravity.END else Gravity.START
                    bottomMargin = dp(6)
                }
            }

            val senderTv = TextView(this).apply {
                text = if (isUser) "You" else "OmniPilot"
                setTextColor(if (isUser) Color.parseColor("#93C5FD") else Color.parseColor("#38BDF8"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
                setTypeface(typeface, Typeface.BOLD)
            }

            val messageTv = TextView(this).apply {
                text = message
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            }

            bubble.addView(senderTv)
            bubble.addView(messageTv)
            container.addView(bubble)

            scroll?.post {
                scroll.fullScroll(View.FOCUS_DOWN)
            }
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

        val panel = floatingPanelView ?: return
        val screenWidth = resources.displayMetrics.widthPixels
        panel.translationX = screenWidth.toFloat()
        panel.visibility = View.VISIBLE
        panel.animate()
            .translationX(0f)
            .setDuration(240L)
            .setInterpolator(android.view.animation.DecelerateInterpolator())
            .start()
    }

    private fun collapseCommandPanel() {
        enablePanelKeyboardFocus(false)
        val panel = floatingPanelView
        if (panel != null && panel.visibility == View.VISIBLE) {
            val screenWidth = resources.displayMetrics.widthPixels
            panel.animate()
                .translationX(screenWidth.toFloat())
                .setDuration(190L)
                .setInterpolator(android.view.animation.AccelerateInterpolator())
                .withEndAction {
                    panel.visibility = View.GONE
                    panel.translationX = 0f
                    floatingBubbleView?.visibility = View.VISIBLE
                }
                .start()
        } else {
            panel?.visibility = View.GONE
            floatingBubbleView?.visibility = View.VISIBLE
        }
    }

    private fun updateStatus(message: String) {
        updateStatusBubble(message)
    }

    private fun performNativeInspectAndVerify() {
        var feedback = "⚠️ Bot Error: Active screen unreadable."
        try {
            val service = AttendanceAccessibilityService.instance
            if (service == null) {
                feedback = "⚠️ Bot Error: Accessibility Service is disabled."
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

            feedback = sb.toString().trim()
        } catch (e: Exception) {
            feedback = "❌ Bot Failed: ${e.localizedMessage?.take(40) ?: "Unknown error"}"
        } finally {
            updateStatus(feedback)
        }
    }

    private fun performAiNoteWriteWorkflow() {
        val service = AttendanceAccessibilityService.instance
        if (service == null) {
            updateStatus("⚠️ Bot Error: Accessibility Service is disabled.")
            return
        }

        Thread {
            var feedback = "⚠️ Bot Alert: Target fields not found."
            try {
                val snapshot = service.getScreenSnapshot(preferExternal = true)
                val pkg = snapshot["activePackage"]?.toString() ?: ""

                // Step 1: If the app has a "Create a new note" button (e.g. Fossify Notes), click it & title the note!
                var createdNewTab = false
                if (service.clickElement("Create a new note", broadcastFeedback = false) ||
                    service.clickElement("New note", broadcastFeedback = false)
                ) {
                    try { Thread.sleep(500) } catch (_: InterruptedException) {}
                    service.writeFieldsWithVerification(mapOf("#0" to "Class 10-A AI Report"), append = false, broadcastFeedback = false)
                    try { Thread.sleep(300) } catch (_: InterruptedException) {}
                    createdNewTab = service.clickElement("OK", broadcastFeedback = false) ||
                        service.clickElement("Create", broadcastFeedback = false)
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
                val isVerified = info?.get("verified") == true || info?.get("success") == true

                feedback = if (isVerified) {
                    buildString {
                        appendLine("✅ Done: AI Note Written in $pkg")
                        if (createdNewTab) {
                            appendLine("➕ Created New Note Tab: \"Class 10-A AI Report\"")
                        }
                        appendLine("✔️ Write Verified: $isVerified (${verifiedVal.length} chars)")
                        appendLine("📄 Preview: \"${verifiedVal.lines().firstOrNull() ?: ""}\"")
                    }.trim()
                } else {
                    "⚠️ Bot Alert: Target fields not found."
                }
            } catch (e: Exception) {
                feedback = "❌ Bot Failed: ${e.localizedMessage?.take(40) ?: "Unknown error"}"
            } finally {
                updateStatus(feedback)
            }
        }.start()
    }

    private fun performQuickFillDemo() {
        var feedback = "⚠️ Bot Alert: Target fields not found."
        try {
            val service = AttendanceAccessibilityService.instance
            if (service == null) {
                feedback = "⚠️ Bot Error: Accessibility Service is disabled."
                return
            }

            val snapshot = service.getScreenSnapshot(preferExternal = true)
            @Suppress("UNCHECKED_CAST")
            val fields = (snapshot["editableFields"] as? List<Map<String, Any>>) ?: emptyList()
            if (fields.isEmpty()) {
                feedback = "⚠️ Bot Alert: Target fields not found."
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
            val sb = StringBuilder("✅ Done: Autofill & Write Verification:\n")
            var anyOk = false
            for ((k, v) in writeResults) {
                @Suppress("UNCHECKED_CAST")
                val info = v as? Map<String, Any> ?: continue
                val lbl = info["matchedLabel"] ?: k
                val written = info["verifiedValue"] ?: info["writtenValue"]
                val ok = info["verified"] == true || info["success"] == true
                if (ok) anyOk = true
                sb.appendLine("${if (ok) "✅" else "❌"} [$lbl] = \"$written\"")
            }
            feedback = if (anyOk) sb.toString().trim() else "⚠️ Bot Alert: Target fields not found."
        } catch (e: Exception) {
            feedback = "❌ Bot Failed: ${e.localizedMessage?.take(40) ?: "Unknown error"}"
        } finally {
            updateStatus(feedback)
        }
    }

    private fun executeUserInstructionOverApp(prompt: String) {
        if (!SystemPermissionHelper.hasAccessibilityPermission(this)) {
            val req = SystemPermissionHelper.getRequirementInfo(SystemPermissionHelper.PERM_ACCESSIBILITY)
            showSystemPermissionPopup(
                permissionKey = req.key,
                title = req.title,
                reason = req.reason,
                pendingCommand = prompt
            )
            updateStatusBubble("🔐 Accessibility service required.")
            return
        }

        promptInput?.setText("")
        addChatMessage("You", prompt)
        updateStatus("🤖 Running instruction on active app...\n\"$prompt\"")
        runWithUnderlyingAppFocus {
            try {
                val handler = onOverlayPromptHandler
                if (handler != null) {
                    handler.invoke(prompt) { aiReply ->
                        val msg = if (aiReply.isNotBlank()) aiReply else "✅ Done: Command completed."
                        updateStatusBubble(msg)
                    }
                } else {
                    // Offline / direct native parser fallback if Flutter engine is detached
                    val fallbackResult = executeDirectNativeInstruction(prompt)
                    updateStatusBubble(fallbackResult)
                }
            } catch (e: Exception) {
                updateStatusBubble("❌ Bot Failed: ${e.localizedMessage?.take(40) ?: "Unknown error"}")
            }
        }
    }

    private fun executeDirectNativeInstruction(prompt: String): String {
        var feedback = "✅ Command processed."
        try {
            val service = AttendanceAccessibilityService.instance
            if (service == null) {
                feedback = "⚠️ Bot Error: Accessibility Service is not enabled."
                return feedback
            }

            val lower = prompt.lowercase()
            if (lower.contains("inspect") || lower.contains("check") || lower.contains("read")) {
                performNativeInspectAndVerify()
                feedback = panelStatusTextView?.text?.toString() ?: "✅ Done: Inspected screen."
                return feedback
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
                val anyOk = res.values.any { (it as? Map<*, *>)?.get("success") == true }
                feedback = if (anyOk) "✅ Done: Field writes completed." else "⚠️ Bot Alert: Target fields not found."
                return feedback
            }

            // 0. App Launch commands in human language (e.g. "open contacts", "launch browser", "start chrome")
            val openPrefixes = listOf("open ", "launch ", "start ", "go to ")
            for (pfx in openPrefixes) {
                if (lower.startsWith(pfx)) {
                    val appTarget = prompt.substring(pfx.length).trim()
                    service.launchOrResolveApp(appTarget, this)
                    return "⏳ Processing launch for $appTarget..."
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
                val sb = StringBuilder("✅ Done: Auto-Fill:\n")
                var anyOk = false
                for ((k, v) in res) {
                    @Suppress("UNCHECKED_CAST")
                    val info = v as? Map<String, Any> ?: continue
                    val lbl = info["matchedLabel"] ?: k
                    val written = info["verifiedValue"] ?: info["writtenValue"]
                    val ok = info["verified"] == true || info["success"] == true
                    if (ok) anyOk = true
                    sb.appendLine("${if (ok) "✅" else "❌"} [$lbl] = \"$written\"")
                }
                if (lower.contains("save") || lower.contains("done") || lower.contains("submit")) {
                    mainHandler.postDelayed({
                        service.clickElement("Save") || service.clickElement("Done") || service.clickElement("Submit")
                    }, 400L)
                }
                feedback = if (anyOk) sb.toString().trim() else "⚠️ Bot Alert: Target fields not found."
                return feedback
            }

            // 1. Direct text typing into whatever third-party app is currently open
            val writePrefixes = listOf("type ", "input ", "write ", "enter ", "fill ", "paste ")
            for (pfx in writePrefixes) {
                if (lower.startsWith(pfx)) {
                    val value = prompt.substring(pfx.length).trim().removeSurrounding("\"").removeSurrounding("'")
                    val writeRes = service.writeFieldsWithVerification(mapOf("#0" to value))
                    val sb = StringBuilder("✅ Done: Typed into Active App:\n")
                    var anyOk = false
                    for ((k, v) in writeRes) {
                        @Suppress("UNCHECKED_CAST")
                        val info = v as? Map<String, Any> ?: continue
                        val lbl = info["matchedLabel"] ?: k
                        val written = info["verifiedValue"] ?: info["writtenValue"]
                        val ok = info["verified"] == true || info["success"] == true
                        if (ok) anyOk = true
                        sb.appendLine("${if (ok) "✅" else "❌"} [$lbl] = \"$written\"")
                    }
                    feedback = if (anyOk) sb.toString().trim() else "⚠️ Bot Alert: Target fields not found."
                    return feedback
                }
            }

            // 2. Navigation commands in third party apps
            if (lower.contains("scroll down")) {
                val ok = service.scrollScreen("down")
                feedback = if (ok) "✅ Done: Scrolled down." else "⚠️ Bot Alert: Could not scroll."
                return feedback
            }
            if (lower.contains("scroll up")) {
                val ok = service.scrollScreen("up")
                feedback = if (ok) "✅ Done: Scrolled up." else "⚠️ Bot Alert: Could not scroll."
                return feedback
            }
            if (lower.equals("back", ignoreCase = true) || lower.startsWith("go back")) {
                val ok = service.performSystemNavigation("BACK")
                feedback = if (ok) "✅ Done: Navigated Back." else "⚠️ Bot Error: Could not navigate Back."
                return feedback
            }

            if (lower.startsWith("click ") || lower.startsWith("tap ") || lower.startsWith("press ")) {
                val target = prompt.substringAfter(" ").trim()
                val ok = service.clickElement(target)
                feedback = if (ok) "✅ Done: Clicked '$target'." else "⚠️ Bot Alert: Target '$target' not found."
                return feedback
            }

            performQuickFillDemo()
            feedback = panelStatusTextView?.text?.toString() ?: "✅ Done: Action completed."
            return feedback
        } catch (e: Exception) {
            feedback = "❌ Bot Failed: ${e.localizedMessage?.take(40) ?: "Unknown error"}"
            return feedback
        } finally {
            updateStatus(feedback)
        }
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
                .setContentText("Tap to open OmniPilot • Slide edge menu to inspect & control any app")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentIntent(pendingIntent)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("OmniPilot Assistant Active")
                .setContentText("Tap to open OmniPilot • Slide edge menu to inspect & control any app")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentIntent(pendingIntent)
                .build()
        }
    }

    private var activeChoiceDialogView: View? = null

    private fun renderOverlayChoiceCard(
        title: String,
        options: List<ChoiceOption>,
        onSelect: (Int) -> Unit
    ) {
        val wm = windowManager ?: (getSystemService(Context.WINDOW_SERVICE) as WindowManager)

        // Dismiss previous dialog if one was open
        activeChoiceDialogView?.let {
            try {
                wm.removeView(it)
            } catch (_: Exception) {}
            activeChoiceDialogView = null
        }

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val padH = dp(18)
            val padV = dp(16)
            setPadding(padH, padV, padH, padV)
            val bg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(16).toFloat()
                setColor(Color.parseColor("#1E1E2E"))
                setStroke(dp(1), Color.parseColor("#38BDF8"))
            }
            background = bg
            elevation = dp(16).toFloat()
        }

        val header = TextView(this).apply {
            text = title
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            setTypeface(typeface, Typeface.BOLD)
            setPadding(0, 0, 0, dp(12))
        }
        container.addView(header)

        val screenWidth = resources.displayMetrics.widthPixels
        val dialogWidth = (screenWidth * 0.88).toInt()

        val params = WindowManager.LayoutParams(
            dialogWidth,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayLayoutType(),
            WindowManager.LayoutParams.FLAG_DIM_BEHIND or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
            dimAmount = 0.55f
        }

        val scroll = ScrollView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                weight = 1f
            }
            isVerticalScrollBarEnabled = true
        }

        val listLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }

        // Add one clickable row per candidate option with icon, title and subtitle
        options.forEachIndexed { index, option ->
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                val rowBg = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE
                    cornerRadius = dp(10).toFloat()
                    setColor(Color.parseColor("#2E2E3E"))
                    setStroke(dp(1), Color.parseColor("#4B5563"))
                }
                background = rowBg
                val padH = dp(12)
                val padV = dp(10)
                setPadding(padH, padV, padH, padV)
                isClickable = true
                isFocusable = true
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    bottomMargin = dp(8)
                }

                // App / node icon on the left (32dp x 32dp, 12dp end margin)
                if (option.icon != null) {
                    val iconView = ImageView(context).apply {
                        setImageDrawable(option.icon)
                        scaleType = ImageView.ScaleType.FIT_CENTER
                        layoutParams = LinearLayout.LayoutParams(dp(32), dp(32)).apply {
                            marginEnd = dp(12)
                        }
                    }
                    addView(iconView)
                }

                // Text column: label + optional subtitle
                val textCol = LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                }

                val titleTv = TextView(context).apply {
                    text = option.label
                    setTextColor(Color.WHITE)
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 13.5f)
                    setTypeface(typeface, Typeface.BOLD)
                }
                textCol.addView(titleTv)

                if (!option.subtitle.isNullOrBlank()) {
                    val subTv = TextView(context).apply {
                        text = option.subtitle
                        setTextColor(Color.parseColor("#94A3B8"))
                        setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
                        ellipsize = TextUtils.TruncateAt.END
                        maxLines = 2
                        setPadding(0, dp(2), 0, 0)
                    }
                    textCol.addView(subTv)
                }
                addView(textCol)

                setOnClickListener {
                    try {
                        wm.removeView(container)
                    } catch (_: Exception) {}
                    if (activeChoiceDialogView == container) {
                        activeChoiceDialogView = null
                    }
                    onSelect(index)
                }
            }
            listLayout.addView(row)
        }
        scroll.addView(listLayout)
        container.addView(scroll)

        // Cancel option so the user is never stuck
        val cancelBtn = Button(this).apply {
            text = "Cancel"
            isAllCaps = false
            setTextColor(Color.parseColor("#EF4444"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            val cancelBg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(8).toFloat()
                setColor(Color.parseColor("#374151"))
            }
            background = cancelBg
            val pad = dp(8)
            setPadding(pad, pad, pad, pad)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = dp(4)
            }
            setOnClickListener {
                try {
                    wm.removeView(container)
                } catch (_: Exception) {}
                if (activeChoiceDialogView == container) {
                    activeChoiceDialogView = null
                }
                updateStatusBubble("🚫 Action cancelled.")
            }
        }
        container.addView(cancelBtn)

        activeChoiceDialogView = container
        try {
            wm.addView(container, params)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun renderAppPermissionDialog(
        appLabel: String,
        packageName: String,
        appIcon: Drawable?,
        requestedScope: String,
        onDecision: (PermissionDecision) -> Unit
    ) {
        val wm = windowManager ?: (getSystemService(Context.WINDOW_SERVICE) as WindowManager)

        // Dismiss previous dialog if one was open
        activeChoiceDialogView?.let {
            try {
                wm.removeView(it)
            } catch (_: Exception) {}
            activeChoiceDialogView = null
        }

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val padH = dp(20)
            val padV = dp(18)
            setPadding(padH, padV, padH, padV)
            val bg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(16).toFloat()
                setColor(Color.parseColor("#1E1E2E"))
                setStroke(dp(1), Color.parseColor("#38BDF8"))
            }
            background = bg
            elevation = dp(16).toFloat()
        }

        // 1. Header Badge: "🔐 App Access Request"
        val header = TextView(this).apply {
            text = "🔐 App Access Request"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setTypeface(typeface, Typeface.BOLD)
            setPadding(0, 0, 0, dp(14))
        }
        container.addView(header)

        // 2. Target App Row (Icon + App Label + Package)
        val appRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, 0, 0, dp(14))
        }

        val iconView = ImageView(this).apply {
            if (appIcon != null) {
                setImageDrawable(appIcon)
            } else {
                setImageResource(R.mipmap.ic_launcher)
            }
            scaleType = ImageView.ScaleType.FIT_CENTER
            layoutParams = LinearLayout.LayoutParams(dp(40), dp(40)).apply {
                marginEnd = dp(12)
            }
        }
        appRow.addView(iconView)

        val appTextCol = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        val labelTv = TextView(this).apply {
            text = appLabel
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            setTypeface(typeface, Typeface.BOLD)
        }
        val pkgTv = TextView(this).apply {
            text = packageName
            setTextColor(Color.parseColor("#94A3B8"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            ellipsize = TextUtils.TruncateAt.END
            maxLines = 1
        }
        appTextCol.addView(labelTv)
        appTextCol.addView(pkgTv)
        appRow.addView(appTextCol)
        container.addView(appRow)

        // 3. Scope Description Box
        val scopeBox = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val boxBg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(10).toFloat()
                setColor(Color.parseColor("#2A2A3C"))
                setStroke(dp(1), Color.parseColor("#3E3E52"))
            }
            background = boxBg
            val pad = dp(12)
            setPadding(pad, pad, pad, pad)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(16)
            }
        }
        val scopeTv = TextView(this).apply {
            text = "OmniPilot is requesting permission to view screen fields and automate actions in $appLabel.\n\nPurpose: $requestedScope"
            setTextColor(Color.parseColor("#E2E8F0"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f)
        }
        scopeBox.addView(scopeTv)
        container.addView(scopeBox)

        // Dismiss helper
        val dismissDialog = {
            try {
                wm.removeView(container)
            } catch (_: Exception) {}
            if (activeChoiceDialogView == container) {
                activeChoiceDialogView = null
            }
        }

        // 4. Action Buttons: Allow Always, Allow Once, Deny
        val buttonRow = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }

        val allowAlwaysBtn = Button(this).apply {
            text = "Allow Always"
            isAllCaps = false
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setTypeface(typeface, Typeface.BOLD)
            val btnBg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(8).toFloat()
                setColor(Color.parseColor("#2563EB")) // Primary blue
            }
            background = btnBg
            val pad = dp(10)
            setPadding(pad, pad, pad, pad)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(8)
            }
            setOnClickListener {
                dismissDialog()
                onDecision(PermissionDecision.ALLOW_ALWAYS)
            }
        }

        val allowOnceBtn = Button(this).apply {
            text = "Allow Once"
            isAllCaps = false
            setTextColor(Color.parseColor("#E2E8F0"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f)
            val btnBg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(8).toFloat()
                setColor(Color.parseColor("#374151")) // Slate
            }
            background = btnBg
            val pad = dp(9)
            setPadding(pad, pad, pad, pad)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(8)
            }
            setOnClickListener {
                dismissDialog()
                onDecision(PermissionDecision.ALLOW_ONCE)
            }
        }

        val denyBtn = Button(this).apply {
            text = "Deny"
            isAllCaps = false
            setTextColor(Color.parseColor("#EF4444"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f)
            val btnBg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(8).toFloat()
                setColor(Color.parseColor("#1F2937"))
                setStroke(dp(1), Color.parseColor("#7F1D1D"))
            }
            background = btnBg
            val pad = dp(8)
            setPadding(pad, pad, pad, pad)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            setOnClickListener {
                dismissDialog()
                onDecision(PermissionDecision.DENY)
            }
        }

        buttonRow.addView(allowAlwaysBtn)
        buttonRow.addView(allowOnceBtn)
        buttonRow.addView(denyBtn)
        container.addView(buttonRow)

        val screenWidth = resources.displayMetrics.widthPixels
        val dialogWidth = (screenWidth * 0.90).toInt()

        val params = WindowManager.LayoutParams(
            dialogWidth,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayLayoutType(),
            WindowManager.LayoutParams.FLAG_DIM_BEHIND or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
            dimAmount = 0.55f
        }

        activeChoiceDialogView = container
        try {
            wm.addView(container, params)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun renderSystemPermissionDialog(
        permissionKey: String,
        title: String,
        reason: String,
        pendingCommand: String? = null
    ) {
        val wm = windowManager ?: (getSystemService(Context.WINDOW_SERVICE) as WindowManager)

        // Dismiss previous dialog if one was open
        activeChoiceDialogView?.let {
            try {
                wm.removeView(it)
            } catch (_: Exception) {}
            activeChoiceDialogView = null
        }

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val padH = dp(20)
            val padV = dp(18)
            setPadding(padH, padV, padH, padV)
            val bg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(16).toFloat()
                setColor(Color.parseColor("#1E1E2E"))
                setStroke(dp(1), Color.parseColor("#38BDF8"))
            }
            background = bg
            elevation = dp(16).toFloat()
        }

        // 1. Header: "🔐 System Permission Required"
        val header = TextView(this).apply {
            text = "🔐 System Permission Required"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setTypeface(typeface, Typeface.BOLD)
            setPadding(0, 0, 0, dp(6))
        }
        container.addView(header)

        // 2. Permission Title Subheader
        val titleTv = TextView(this).apply {
            text = title
            setTextColor(Color.parseColor("#38BDF8"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            setTypeface(typeface, Typeface.BOLD)
            setPadding(0, 0, 0, dp(12))
        }
        container.addView(titleTv)

        // 3. Reason Box
        val reasonBox = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val boxBg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(10).toFloat()
                setColor(Color.parseColor("#2A2A3C"))
                setStroke(dp(1), Color.parseColor("#3E3E52"))
            }
            background = boxBg
            val pad = dp(12)
            setPadding(pad, pad, pad, pad)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(16)
            }
        }
        val reasonTv = TextView(this).apply {
            text = reason
            setTextColor(Color.parseColor("#E2E8F0"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f)
            setLineSpacing(0f, 1.25f)
        }
        reasonBox.addView(reasonTv)
        container.addView(reasonBox)

        // Dismiss helper
        val dismissDialog = {
            try {
                wm.removeView(container)
            } catch (_: Exception) {}
            if (activeChoiceDialogView == container) {
                activeChoiceDialogView = null
            }
        }

        // 4. Action Buttons: "Grant Now" and "Later"
        val buttonRow = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }

        val grantBtn = Button(this).apply {
            text = "Grant Now"
            isAllCaps = false
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setTypeface(typeface, Typeface.BOLD)
            val btnBg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(8).toFloat()
                setColor(Color.parseColor("#2563EB"))
            }
            background = btnBg
            val pad = dp(10)
            setPadding(pad, pad, pad, pad)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(8)
            }
            setOnClickListener {
                dismissDialog()
                SystemPermissionHelper.setPendingPermission(permissionKey, pendingCommand)
                SystemPermissionHelper.openSettingsForPermission(this@FloatingBubbleService, permissionKey)
            }
        }

        val laterBtn = Button(this).apply {
            text = "Later"
            isAllCaps = false
            setTextColor(Color.parseColor("#94A3B8"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f)
            val btnBg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(8).toFloat()
                setColor(Color.parseColor("#1F2937"))
            }
            background = btnBg
            val pad = dp(8)
            setPadding(pad, pad, pad, pad)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            setOnClickListener {
                dismissDialog()
                updateStatusBubble("⚠️ Permission setup postponed.")
            }
        }

        buttonRow.addView(grantBtn)
        buttonRow.addView(laterBtn)
        container.addView(buttonRow)

        val screenWidth = resources.displayMetrics.widthPixels
        val dialogWidth = (screenWidth * 0.90).toInt()

        val params = WindowManager.LayoutParams(
            dialogWidth,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayLayoutType(),
            WindowManager.LayoutParams.FLAG_DIM_BEHIND or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
            dimAmount = 0.55f
        }

        activeChoiceDialogView = container
        try {
            wm.addView(container, params)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        if (instance == this) {
            instance = null
        }
        try {
            tts?.stop()
            tts?.shutdown()
        } catch (_: Exception) {}
        tts = null
        ttsReady = false
        activeChoiceDialogView?.let {
            try {
                windowManager?.removeView(it)
            } catch (_: Exception) {}
            activeChoiceDialogView = null
        }
        statusTextView?.let {
            try {
                it.removeCallbacksAndMessages(null)
                windowManager?.removeView(it)
            } catch (_: Exception) {}
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
