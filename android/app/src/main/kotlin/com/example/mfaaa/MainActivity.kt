package com.example.mfaaa

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mfaaa/app_blocker").setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledApps" -> result.success(getInstalledApps())
                "setBlockingState" -> {
                    val blockedPackages = call.argument<List<String>>("blockedPackages") ?: emptyList()
                    getSharedPreferences("app_blocker", Context.MODE_PRIVATE).edit()
                        .putBoolean("enabled", call.argument<Boolean>("enabled") ?: false)
                        .putBoolean("strictMode", call.argument<Boolean>("strictMode") ?: false)
                        .putBoolean("onBreak", call.argument<Boolean>("onBreak") ?: false)
                        .putStringSet("blockedPackages", blockedPackages.toSet())
                        .apply()
                    result.success(null)
                }
                "isAccessibilityEnabled" -> result.success(isAccessibilityEnabled())
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mfaaa/app_icons").setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppIcon" -> {
                    val packageName = call.argument<String>("packageName") ?: run {
                        result.error("NO_PACKAGE", "packageName is required", null)
                        return@setMethodCallHandler
                    }
                    val iconSize = 72
                    try {
                        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
                        val activities = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            packageManager.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(0))
                        } else {
                            @Suppress("DEPRECATION")
                            packageManager.queryIntentActivities(intent, 0)
                        }
                        var drawable: android.graphics.drawable.Drawable? = null
                        for (info in activities) {
                            if (info.activityInfo?.packageName == packageName) {
                                drawable = info.loadIcon(packageManager)
                                break
                            }
                        }
                        if (drawable == null) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        val bitmap = android.graphics.Bitmap.createBitmap(
                            iconSize, iconSize,
                            android.graphics.Bitmap.Config.ARGB_8888
                        )
                        val canvas = android.graphics.Canvas(bitmap)
                        drawable.setBounds(0, 0, iconSize, iconSize)
                        drawable.draw(canvas)
                        val stream = java.io.ByteArrayOutputStream()
                        bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, stream)
                        result.success(stream.toByteArray())
                    } catch (e: Exception) {
                        android.util.Log.w("AppIcons", "getAppIcon failed for $packageName: ${e.message}")
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getInstalledApps(): List<Map<String, String>> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val activities = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(intent, 0)
        }
        return activities
            .mapNotNull { info ->
                val packageName = info.activityInfo?.packageName ?: return@mapNotNull null
                if (packageName == this.packageName) return@mapNotNull null
                val label = info.loadLabel(packageManager)?.toString()?.trim().orEmpty()
                if (label.isEmpty()) return@mapNotNull null
                mapOf("label" to label, "packageName" to packageName)
            }
            .distinctBy { it["packageName"] }
            .sortedBy { it["label"]?.lowercase(Locale.getDefault()) }
    }

    private fun isAccessibilityEnabled(): Boolean {
        val expected = ComponentName(this, AppBlockAccessibilityService::class.java).flattenToString()
        val enabled = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabled)
        for (service in splitter) {
            if (service.equals(expected, ignoreCase = true)) return true
        }
        return false
    }
}
