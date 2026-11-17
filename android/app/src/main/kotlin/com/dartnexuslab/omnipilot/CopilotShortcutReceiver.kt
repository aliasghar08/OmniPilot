package com.dartnexuslab.omnipilot

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class CopilotShortcutReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "CopilotShortcutReceiver"
        const val ACTION_TRIGGER_COPILOT = "com.dartnexuslab.omnipilot.TRIGGER_COPILOT"
        const val ACTION_SHOW_COPILOT = "com.dartnexuslab.omnipilot.SHOW_COPILOT"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        val action = intent?.action ?: return
        Log.d(TAG, "CopilotShortcutReceiver received action: $action")
        if (action == ACTION_TRIGGER_COPILOT || action == ACTION_SHOW_COPILOT) {
            if (context != null) {
                FloatingBubbleService.showCopilotMenu(context)
            }
        }
    }
}
