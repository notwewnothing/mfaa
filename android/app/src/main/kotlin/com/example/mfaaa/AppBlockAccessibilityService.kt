package com.example.mfaaa

import android.accessibilityservice.AccessibilityService
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Build
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class AppBlockAccessibilityService : AccessibilityService(), SharedPreferences.OnSharedPreferenceChangeListener {
    private var overlayView: View? = null
    private var overlayPackage: String? = null
    private var currentPackage: String? = null
    private val prefs by lazy { getSharedPreferences("app_blocker", MODE_PRIVATE) }
    private val windowManager by lazy { getSystemService(WINDOW_SERVICE) as WindowManager }

    override fun onServiceConnected() {
        super.onServiceConnected()
        prefs.registerOnSharedPreferenceChangeListener(this)
        refreshOverlay()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED && event.eventType != AccessibilityEvent.TYPE_WINDOWS_CHANGED) return
        val packageName = event.packageName?.toString() ?: return
        if (packageName == this.packageName) return
        currentPackage = packageName
        refreshOverlay()
    }

    override fun onSharedPreferenceChanged(sharedPreferences: SharedPreferences?, key: String?) {
        refreshOverlay()
    }

    override fun onInterrupt() {
        removeOverlay()
    }

    override fun onDestroy() {
        prefs.unregisterOnSharedPreferenceChangeListener(this)
        removeOverlay()
        super.onDestroy()
    }

    private fun refreshOverlay() {
        val packageName = currentPackage
        if (packageName == null) {
            removeOverlay()
            return
        }
        val enabled = prefs.getBoolean("enabled", false)
        val strictMode = prefs.getBoolean("strictMode", false)
        val onBreak = prefs.getBoolean("onBreak", false)
        if (!enabled || (!strictMode && onBreak)) {
            removeOverlay()
            return
        }
        val blockedPackages = prefs.getStringSet("blockedPackages", emptySet()) ?: emptySet()
        if (!blockedPackages.contains(packageName)) {
            removeOverlay()
            return
        }
        showOverlay(packageName, appLabel(packageName))
    }

    private fun showOverlay(packageName: String, label: String) {
        if (overlayView != null && overlayPackage == packageName) return
        removeOverlay()
        overlayPackage = packageName
        overlayView = blockedView(label)
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.CENTER
        }
        windowManager.addView(overlayView, params)
    }

    private fun removeOverlay() {
        val view = overlayView ?: return
        overlayView = null
        overlayPackage = null
        runCatching { windowManager.removeView(view) }
    }

    private fun blockedView(label: String): View {
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(48, 48, 48, 48)
            setBackgroundColor(Color.BLACK)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            addView(TextView(context).apply {
                text = "$label IS BLOCKED"
                textSize = 30f
                setTextColor(Color.rgb(168, 200, 137))
                gravity = Gravity.CENTER
                typeface = Typeface.MONOSPACE
            })
            addView(TextView(context).apply {
                text = "RETURN TO YOUR FOCUS SESSION"
                textSize = 16f
                setTextColor(Color.rgb(105, 116, 95))
                gravity = Gravity.CENTER
                typeface = Typeface.MONOSPACE
                setPadding(0, 24, 0, 36)
            })
            addView(Button(context).apply {
                text = "GO HOME"
                setOnClickListener {
                    performGlobalAction(GLOBAL_ACTION_HOME)
                    removeOverlay()
                }
            })
        }
    }

    private fun appLabel(packageName: String): String {
        return try {
            val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getApplicationInfo(packageName, PackageManager.ApplicationInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                packageManager.getApplicationInfo(packageName, 0)
            }
            packageManager.getApplicationLabel(info).toString()
        } catch (_: PackageManager.NameNotFoundException) {
            packageName
        }
    }
}
