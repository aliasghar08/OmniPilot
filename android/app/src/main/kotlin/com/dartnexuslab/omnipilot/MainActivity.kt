package com.dartnexuslab.omnipilot

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.dartnexuslab.omnipilot/accessibility"
    private var methodChannel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onResume() {
        super.onResume()
        // When user returns to OmniPilot after granting permissions, auto-launch the assistant overlay if authorized
        try {
            val canOverlay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Settings.canDrawOverlays(this)
            } else {
                true
            }
            if (AttendanceAccessibilityService.isRunning && canOverlay && !FloatingBubbleService.isRunning) {
                val intent = Intent(this, FloatingBubbleService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(intent)
                } else {
                    startService(intent)
                }
            }
        } catch (_: Exception) {}
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAccessibilityEnabled" -> {
                        // Return true only if service is actively running and bound to system
                        result.success(AttendanceAccessibilityService.isRunning)
                    }

                    "getAccessibilityStatus" -> {
                        val isRunning = AttendanceAccessibilityService.isRunning
                        val enabledServices = Settings.Secure.getString(
                            contentResolver,
                            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
                        ) ?: ""
                        val isSettingEnabled = enabledServices.contains(packageName)
                        result.success(
                            mapOf(
                                "isBound" to isRunning,
                                "isSettingEnabled" to isSettingEnabled
                            )
                        )
                    }

                    "openAccessibilitySettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.localizedMessage, null)
                        }
                    }

                    "canDrawOverlays" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            result.success(Settings.canDrawOverlays(context))
                        } else {
                            result.success(true)
                        }
                    }

                    "requestOverlayPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            try {
                                val intent = Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:$packageName")
                                ).apply {
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(intent)
                                result.success(true)
                            } catch (_: Exception) {
                                try {
                                    val genericIntent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                    }
                                    startActivity(genericIntent)
                                    result.success(true)
                                } catch (e2: Exception) {
                                    result.error("ERROR", e2.localizedMessage, null)
                                }
                            }
                        } else {
                            result.success(true)
                        }
                    }

                    "openAppInfoSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.localizedMessage, null)
                        }
                    }

                    "requestIgnoreBatteryOptimizations" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                try {
                                    val directIntent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                        data = Uri.parse("package:$packageName")
                                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                    }
                                    startActivity(directIntent)
                                    result.success(true)
                                    return@setMethodCallHandler
                                } catch (_: Exception) {}

                                val listIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(listIntent)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.localizedMessage, null)
                        }
                    }

                    "openAutoStartSettings" -> {
                        val launched = openOemAutoStartSettings()
                        result.success(launched)
                    }

                    "inspectActiveWindow" -> {
                        val service = AttendanceAccessibilityService.instance
                        if (service == null) {
                            result.error(
                                "SERVICE_DISABLED",
                                "Accessibility service is not enabled. Please enable it in Settings.",
                                null
                            )
                        } else {
                            val fields = service.inspectActiveWindow()
                            result.success(fields)
                        }
                    }

                    "getScreenSnapshot" -> {
                        val service = AttendanceAccessibilityService.instance
                        if (service == null) {
                            result.error("SERVICE_DISABLED", "Accessibility service is disabled.", null)
                        } else {
                            val preferExternal = call.argument<Boolean>("preferExternal") ?: true
                            val switchToExternal = call.argument<Boolean>("switchToExternal") ?: false
                            if (switchToExternal) {
                                Thread {
                                    service.ensureExternalAppFocused()
                                    val snapshot = service.getScreenSnapshot(preferExternal)
                                    mainHandler.post { result.success(snapshot) }
                                }.start()
                            } else {
                                val snapshot = service.getScreenSnapshot(preferExternal)
                                result.success(snapshot)
                            }
                        }
                    }

                    "checkExistingWrites" -> {
                        val service = AttendanceAccessibilityService.instance
                        if (service == null) {
                            result.error("SERVICE_DISABLED", "Accessibility service is disabled.", null)
                        } else {
                            @Suppress("UNCHECKED_CAST")
                            val targets = call.argument<List<String>>("targets")
                            val switchToExternal = call.argument<Boolean>("switchToExternal") ?: false
                            if (switchToExternal) {
                                Thread {
                                    service.ensureExternalAppFocused()
                                    val checkResult = service.checkExistingWrites(targets)
                                    mainHandler.post { result.success(checkResult) }
                                }.start()
                            } else {
                                val checkResult = service.checkExistingWrites(targets)
                                result.success(checkResult)
                            }
                        }
                    }

                    "fillExternalFields" -> {
                        val service = AttendanceAccessibilityService.instance
                        if (service == null) {
                            result.error(
                                "SERVICE_DISABLED",
                                "Accessibility service is not enabled. Please enable it in Settings.",
                                null
                            )
                        } else {
                            @Suppress("UNCHECKED_CAST")
                            val fieldMap = call.argument<Map<String, String>>("fields") ?: emptyMap()
                            val fillResults = service.fillFields(fieldMap)
                            result.success(fillResults)
                        }
                    }

                    "writeFieldsWithVerification" -> {
                        val service = AttendanceAccessibilityService.instance
                        if (service == null) {
                            result.error("SERVICE_DISABLED", "Accessibility service is disabled.", null)
                        } else {
                            @Suppress("UNCHECKED_CAST")
                            val fieldMap = call.argument<Map<String, String>>("fields") ?: emptyMap()
                            val append = call.argument<Boolean>("append") ?: false
                            val switchToExternal = call.argument<Boolean>("switchToExternal") ?: false
                            if (switchToExternal) {
                                Thread {
                                    service.ensureExternalAppFocused()
                                    val writeRes = service.writeFieldsWithVerification(fieldMap, append)
                                    mainHandler.post { result.success(writeRes) }
                                }.start()
                            } else {
                                val writeRes = service.writeFieldsWithVerification(fieldMap, append)
                                result.success(writeRes)
                            }
                        }
                    }

                    "clickElement" -> {
                        val service = AttendanceAccessibilityService.instance
                        if (service == null) {
                            result.error("SERVICE_DISABLED", "Accessibility service is disabled.", null)
                        } else {
                            val target = call.argument<String>("target") ?: ""
                            val clicked = service.clickElement(target)
                            result.success(clicked)
                        }
                    }

                    "longClickElement" -> {
                        val service = AttendanceAccessibilityService.instance
                        if (service == null) {
                            result.error("SERVICE_DISABLED", "Accessibility service is disabled.", null)
                        } else {
                            val target = call.argument<String>("target") ?: ""
                            val clicked = service.longClickElement(target)
                            result.success(clicked)
                        }
                    }

                    "setCheckableState" -> {
                        val service = AttendanceAccessibilityService.instance
                        if (service == null) {
                            result.error("SERVICE_DISABLED", "Accessibility service is disabled.", null)
                        } else {
                            val target = call.argument<String>("target") ?: ""
                            val checked = call.argument<Boolean>("checked") ?: true
                            val res = service.setCheckableState(target, checked)
                            result.success(res)
                        }
                    }

                    "scrollScreen" -> {
                        val service = AttendanceAccessibilityService.instance
                        if (service == null) {
                            result.error("SERVICE_DISABLED", "Accessibility service is disabled.", null)
                        } else {
                            val direction = call.argument<String>("direction") ?: "down"
                            val scrolled = service.scrollScreen(direction)
                            result.success(scrolled)
                        }
                    }

                    "tapCoordinates" -> {
                        val service = AttendanceAccessibilityService.instance
                        if (service == null) {
                            result.error("SERVICE_DISABLED", "Accessibility service is disabled.", null)
                        } else {
                            val x = (call.argument<Number>("x")?.toFloat()) ?: 0f
                            val y = (call.argument<Number>("y")?.toFloat()) ?: 0f
                            val ok = service.tapCoordinates(x, y)
                            result.success(ok)
                        }
                    }

                    "swipeCoordinates" -> {
                        val service = AttendanceAccessibilityService.instance
                        if (service == null) {
                            result.error("SERVICE_DISABLED", "Accessibility service is disabled.", null)
                        } else {
                            val startX = (call.argument<Number>("startX")?.toFloat()) ?: 0f
                            val startY = (call.argument<Number>("startY")?.toFloat()) ?: 0f
                            val endX = (call.argument<Number>("endX")?.toFloat()) ?: 0f
                            val endY = (call.argument<Number>("endY")?.toFloat()) ?: 0f
                            val durationMs = (call.argument<Number>("durationMs")?.toLong()) ?: 350L
                            val ok = service.swipeCoordinates(startX, startY, endX, endY, durationMs)
                            result.success(ok)
                        }
                    }

                    "performSystemNavigation" -> {
                        val service = AttendanceAccessibilityService.instance
                        if (service == null) {
                            result.error("SERVICE_DISABLED", "Accessibility service is disabled.", null)
                        } else {
                            val action = call.argument<String>("action") ?: "BACK"
                            val ok = service.performSystemNavigation(action)
                            result.success(ok)
                        }
                    }

                    "ensureExternalAppFocused" -> {
                        val service = AttendanceAccessibilityService.instance
                        if (service == null) {
                            result.error("SERVICE_DISABLED", "Accessibility service is disabled.", null)
                        } else {
                            Thread {
                                val ok = service.ensureExternalAppFocused()
                                mainHandler.post { result.success(ok) }
                            }.start()
                        }
                    }

                    "getInstalledApps" -> {
                        val service = AttendanceAccessibilityService.instance
                        if (service != null) {
                            val query = call.argument<String>("query")
                            result.success(service.getInstalledApps(query))
                        } else {
                            result.error("SERVICE_DISABLED", "Accessibility service is disabled.", null)
                        }
                    }

                    "launchExternalApp" -> {
                        val service = AttendanceAccessibilityService.instance
                        val appNameOrPackage = call.argument<String>("app") ?: ""
                        if (service != null) {
                            Thread {
                                val launched = service.launchAppByPackageOrName(appNameOrPackage)
                                if (launched) {
                                    try {
                                        Thread.sleep(750)
                                    } catch (_: InterruptedException) {}
                                }
                                mainHandler.post { result.success(launched) }
                            }.start()
                        } else {
                            val launchIntent = packageManager.getLaunchIntentForPackage(appNameOrPackage)
                            if (launchIntent != null) {
                                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(launchIntent)
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        }
                    }

                    "startFloatingBubble" -> {
                        try {
                            val intent = Intent(this@MainActivity, FloatingBubbleService::class.java)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OVERLAY_ERROR", e.localizedMessage, null)
                        }
                    }

                    "stopFloatingBubble" -> {
                        val intent = Intent(this@MainActivity, FloatingBubbleService::class.java)
                        stopService(intent)
                        result.success(true)
                    }

                    "isFloatingBubbleRunning" -> {
                        result.success(FloatingBubbleService.isRunning)
                    }

                    "openGoogleSearchInBrowser" -> {
                        try {
                            val query = call.argument<String>("query") ?: ""
                            val searchUrl = "https://www.google.com/search?q=${Uri.encode(query)}"
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(searchUrl)).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("BROWSER_ERROR", e.localizedMessage, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
        }

        // Connect FloatingBubbleService prompt handler to Flutter's Gemini AssistantController
        FloatingBubbleService.onOverlayPromptHandler = { prompt, callback ->
            mainHandler.post {
                val channel = methodChannel
                if (channel != null) {
                    channel.invokeMethod(
                        "onOverlayPrompt",
                        mapOf("prompt" to prompt),
                        object : MethodChannel.Result {
                            override fun success(result: Any?) {
                                callback(result?.toString() ?: "Action completed.")
                            }

                            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                                callback("Error: ${errorMessage ?: errorCode}")
                            }

                            override fun notImplemented() {
                                callback("Flutter handler not registered.")
                            }
                        }
                    )
                } else {
                    callback("Assistant engine not ready.")
                }
            }
        }
    }

    private fun openOemAutoStartSettings(): Boolean {
        val oemIntents = listOf(
            // Xiaomi / HyperOS / MIUI
            Intent().setComponent(android.content.ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")),
            // Oppo / Realme / OnePlus ColorOS / OxygenOS
            Intent().setComponent(android.content.ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")),
            Intent().setComponent(android.content.ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity")),
            Intent().setComponent(android.content.ComponentName("com.oplus.safecenter", "com.oplus.safecenter.startupapp.StartupAppListActivity")),
            // Vivo / iQOO FuntouchOS / OriginOS
            Intent().setComponent(android.content.ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")),
            Intent().setComponent(android.content.ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity")),
            // Huawei / Honor EMUI / HarmonyOS
            Intent().setComponent(android.content.ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")),
            Intent().setComponent(android.content.ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity")),
            // Transsion / Infinix / Tecno (XOS / HiOS)
            Intent().setComponent(android.content.ComponentName("com.transsion.phonemanager", "com.transsion.phonemanager.view.AppAutoRunActivity")),
            Intent().setComponent(android.content.ComponentName("com.transsion.phonemaster", "com.transsion.phonemaster.autostart.AutoStartActivity")),
            // Samsung Device Care / Battery
            Intent().setComponent(android.content.ComponentName("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity"))
        )

        for (intent in oemIntents) {
            try {
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                if (packageManager.resolveActivity(intent, 0) != null) {
                    startActivity(intent)
                    return true
                }
            } catch (_: Exception) {}
        }

        // Fallback to Application Details Settings (App Info)
        return try {
            val appInfoIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(appInfoIntent)
            true
        } catch (_: Exception) {
            false
        }
    }
}
