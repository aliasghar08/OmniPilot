package com.dartnexuslab.omnipilot

import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.graphics.drawable.Drawable
import java.util.Collections

/**
 * Manages per-app access consent for OmniPilot cross-app automation.
 * Persists permanent approvals in SharedPreferences and manages session-only approvals in memory.
 */
object AppPermissionManager {
    private const val PREFS_NAME = "omnipilot_app_permissions"
    private const val KEY_ALLOWED_PACKAGES = "allowed_packages"

    // System packages and OmniPilot itself that never require approval
    private val ALWAYS_ALLOWED_PACKAGES = setOf(
        "com.dartnexuslab.omnipilot",
        "com.android.systemui",
        "android",
        "com.google.android.inputmethod.latin",
        "com.android.inputmethod.latin"
    )

    // In-memory set for "Allow Once" (valid for current service lifetime only)
    private val sessionAllowedPackages = Collections.synchronizedSet(mutableSetOf<String>())

    private fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    /**
     * Checks whether access to [packageName] is permitted (permanently, for this session, or system whitelist).
     */
    fun isPackageAllowed(context: Context, packageName: String?): Boolean {
        if (packageName.isNullOrBlank()) return true
        if (packageName == context.packageName || ALWAYS_ALLOWED_PACKAGES.contains(packageName)) {
            return true
        }
        if (sessionAllowedPackages.contains(packageName)) {
            return true
        }
        val allowedSet = getPrefs(context).getStringSet(KEY_ALLOWED_PACKAGES, emptySet()) ?: emptySet()
        return allowedSet.contains(packageName)
    }

    /**
     * Permanently authorizes [packageName].
     */
    fun allowPermanently(context: Context, packageName: String) {
        val prefs = getPrefs(context)
        val currentSet = prefs.getStringSet(KEY_ALLOWED_PACKAGES, emptySet())?.toMutableSet() ?: mutableSetOf()
        currentSet.add(packageName)
        prefs.edit().putStringSet(KEY_ALLOWED_PACKAGES, currentSet).apply()
    }

    /**
     * Authorizes [packageName] for the current session only.
     */
    fun allowForSession(packageName: String) {
        sessionAllowedPackages.add(packageName)
    }

    /**
     * Revokes permission for [packageName] from permanent storage and session memory.
     */
    fun revokePermission(context: Context, packageName: String): Boolean {
        sessionAllowedPackages.remove(packageName)
        val prefs = getPrefs(context)
        val currentSet = prefs.getStringSet(KEY_ALLOWED_PACKAGES, emptySet())?.toMutableSet() ?: mutableSetOf()
        val removed = currentSet.remove(packageName)
        if (removed) {
            prefs.edit().putStringSet(KEY_ALLOWED_PACKAGES, currentSet).apply()
        }
        return true
    }

    /**
     * Returns a list of all permanently authorized third-party apps with their package name and human label.
     */
    fun getAuthorizedApps(context: Context): List<Map<String, String>> {
        val prefs = getPrefs(context)
        val set = prefs.getStringSet(KEY_ALLOWED_PACKAGES, emptySet()) ?: emptySet()
        val pm = context.packageManager
        val list = mutableListOf<Map<String, String>>()
        for (pkg in set) {
            val label = try {
                val appInfo = pm.getApplicationInfo(pkg, 0)
                pm.getApplicationLabel(appInfo).toString()
            } catch (_: Exception) {
                pkg.substringAfterLast('.')
            }
            list.add(mapOf("packageName" to pkg, "label" to label))
        }
        return list.sortedBy { it["label"]?.lowercase() ?: "" }
    }

    /**
     * Resolves human label and app icon for [packageName].
     */
    fun resolveAppDetails(context: Context, packageName: String): Pair<String, Drawable?> {
        val pm = context.packageManager
        return try {
            val appInfo = pm.getApplicationInfo(packageName, 0)
            val label = pm.getApplicationLabel(appInfo).toString()
            val icon = pm.getApplicationIcon(appInfo)
            Pair(label, icon)
        } catch (_: Exception) {
            Pair(packageName.substringAfterLast('.'), null)
        }
    }
}
