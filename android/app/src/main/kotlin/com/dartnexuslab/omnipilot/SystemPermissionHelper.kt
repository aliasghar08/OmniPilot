package com.dartnexuslab.omnipilot

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

data class SystemPermissionRequirement(
    val key: String,
    val title: String,
    val reason: String
)

object SystemPermissionHelper {
    const val PERM_OVERLAY = "overlay"
    const val PERM_ACCESSIBILITY = "accessibility"
    const val PERM_NOTIFICATIONS = "notifications"
    const val PERM_BATTERY = "battery_optimization"

    @Volatile
    var pendingPermissionKey: String? = null

    @Volatile
    var pendingActionCommand: String? = null

    /**
     * Checks if "Display over other apps" (SYSTEM_ALERT_WINDOW) is granted.
     */
    fun hasOverlayPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }

    /**
     * Checks if OmniPilot's AttendanceAccessibilityService is enabled in Settings
     * and bound to the system.
     */
    fun hasAccessibilityPermission(context: Context): Boolean {
        val isRunning = AttendanceAccessibilityService.isRunning
        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: ""
        val isSettingEnabled = enabledServices.contains(context.packageName)
        return (isRunning || AttendanceAccessibilityService.instance != null) && isSettingEnabled
    }

    /**
     * Checks if notification permission (POST_NOTIFICATIONS) is granted on Android 13+ (API 33+).
     */
    fun hasNotificationPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    /**
     * Checks if OmniPilot is exempted from Android's PowerManager battery optimizations.
     */
    fun isBatteryOptimizationIgnored(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            pm?.isIgnoringBatteryOptimizations(context.packageName) ?: false
        } else {
            true
        }
    }

    /**
     * Checks if a given system permission by key is granted.
     */
    fun isPermissionGranted(context: Context, key: String): Boolean {
        return when (key) {
            PERM_OVERLAY -> hasOverlayPermission(context)
            PERM_ACCESSIBILITY -> hasAccessibilityPermission(context)
            PERM_NOTIFICATIONS -> hasNotificationPermission(context)
            PERM_BATTERY -> isBatteryOptimizationIgnored(context)
            else -> false
        }
    }

    /**
     * Returns structured metadata (title and reason) for a given permission key.
     */
    fun getRequirementInfo(key: String): SystemPermissionRequirement {
        return when (key) {
            PERM_OVERLAY -> SystemPermissionRequirement(
                key = PERM_OVERLAY,
                title = "Display Over Other Apps",
                reason = "OmniPilot requires overlay permission to draw the assistant controls and interactive bot HUD over external apps."
            )
            PERM_ACCESSIBILITY -> SystemPermissionRequirement(
                key = PERM_ACCESSIBILITY,
                title = "Accessibility Service",
                reason = "OmniPilot requires Accessibility Service to inspect on-screen UI elements, auto-fill forms, and perform automated actions."
            )
            PERM_NOTIFICATIONS -> SystemPermissionRequirement(
                key = PERM_NOTIFICATIONS,
                title = "Notification Permission",
                reason = "Android 13+ requires notification permission so OmniPilot can run reliably as an uninterrupted foreground service."
            )
            PERM_BATTERY -> SystemPermissionRequirement(
                key = PERM_BATTERY,
                title = "Battery Optimization Exemption",
                reason = "Exempting OmniPilot from aggressive OEM battery savers ensures the background accessibility service is not killed."
            )
            else -> SystemPermissionRequirement(
                key = key,
                title = "System Permission",
                reason = "OmniPilot requires this system permission to operate correctly."
            )
        }
    }

    /**
     * Checks missing permissions for a specified scope ('floating_bubble', 'automation', or 'all').
     */
    fun checkRequiredPermissions(context: Context, scope: String): List<SystemPermissionRequirement> {
        val missing = mutableListOf<SystemPermissionRequirement>()
        when (scope.lowercase()) {
            "floating_bubble", "overlay" -> {
                if (!hasOverlayPermission(context)) missing.add(getRequirementInfo(PERM_OVERLAY))
                if (!hasNotificationPermission(context)) missing.add(getRequirementInfo(PERM_NOTIFICATIONS))
            }
            "automation", "bot" -> {
                if (!hasOverlayPermission(context)) missing.add(getRequirementInfo(PERM_OVERLAY))
                if (!hasAccessibilityPermission(context)) missing.add(getRequirementInfo(PERM_ACCESSIBILITY))
            }
            "all" -> {
                if (!hasOverlayPermission(context)) missing.add(getRequirementInfo(PERM_OVERLAY))
                if (!hasAccessibilityPermission(context)) missing.add(getRequirementInfo(PERM_ACCESSIBILITY))
                if (!hasNotificationPermission(context)) missing.add(getRequirementInfo(PERM_NOTIFICATIONS))
                if (!isBatteryOptimizationIgnored(context)) missing.add(getRequirementInfo(PERM_BATTERY))
            }
            else -> {
                if (!hasOverlayPermission(context)) missing.add(getRequirementInfo(PERM_OVERLAY))
                if (!hasAccessibilityPermission(context)) missing.add(getRequirementInfo(PERM_ACCESSIBILITY))
            }
        }
        return missing
    }

    /**
     * Returns a map with current status of all four critical system permissions.
     */
    fun getAllPermissionsStatus(context: Context): Map<String, Boolean> {
        return mapOf(
            PERM_OVERLAY to hasOverlayPermission(context),
            PERM_ACCESSIBILITY to hasAccessibilityPermission(context),
            PERM_NOTIFICATIONS to hasNotificationPermission(context),
            PERM_BATTERY to isBatteryOptimizationIgnored(context)
        )
    }

    fun openOverlaySettings(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:${context.packageName}")
                ).apply {
                    if (context !is Activity) flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(intent)
            } catch (_: Exception) {
                try {
                    val genericIntent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                        if (context !is Activity) flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    context.startActivity(genericIntent)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }

    fun openAccessibilitySettings(context: Context) {
        try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                if (context !is Activity) flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun openNotificationSettings(context: Context, activity: Activity? = null) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (activity != null) {
                ActivityCompat.requestPermissions(
                    activity,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    1002
                )
                return
            }
            try {
                val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                    if (context !is Activity) flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(intent)
                return
            } catch (_: Exception) {}
        }

        // Fallback to Application Details (App Info)
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${context.packageName}")
                if (context !is Activity) flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun openBatteryOptimizationSettings(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val directIntent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:${context.packageName}")
                    if (context !is Activity) flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(directIntent)
                return
            } catch (_: Exception) {}

            try {
                val listIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                    if (context !is Activity) flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(listIntent)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    /**
     * Opens the respective system settings screen for the specified permission key.
     */
    fun openSettingsForPermission(context: Context, permissionKey: String, activity: Activity? = null) {
        when (permissionKey) {
            PERM_OVERLAY -> openOverlaySettings(context)
            PERM_ACCESSIBILITY -> openAccessibilitySettings(context)
            PERM_NOTIFICATIONS -> openNotificationSettings(context, activity)
            PERM_BATTERY -> openBatteryOptimizationSettings(context)
            else -> openOverlaySettings(context)
        }
    }

    fun setPendingPermission(key: String, pendingCommand: String? = null) {
        pendingPermissionKey = key
        pendingActionCommand = pendingCommand
    }

    /**
     * Checks if a pending requested permission has been granted, and if so,
     * broadcasts feedback and resumes any pending action.
     */
    fun checkAndNotifyPendingPermission(context: Context) {
        val pending = pendingPermissionKey ?: return
        if (isPermissionGranted(context, pending)) {
            pendingPermissionKey = null
            val cmd = pendingActionCommand
            pendingActionCommand = null

            val successMsg = "✅ System permission granted! Resuming..."
            FloatingBubbleService.updateStatusBubble(successMsg)
            MainActivity.methodChannel?.invokeMethod("onBotFeedback", successMsg)

            if (!cmd.isNullOrBlank()) {
                AttendanceAccessibilityService.instance?.let { service ->
                    Thread {
                        try {
                            service.executeBotCommand(cmd)
                        } catch (_: Exception) {}
                    }.start()
                }
            }
        }
    }
}
