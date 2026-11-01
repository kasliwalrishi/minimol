package com.hivenet.hivenet

import android.Manifest
import android.content.pm.PackageManager
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.hivenet.hivenet/node"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startNode" -> {
                        val id = call.argument<String>("nodeId") ?: "unknown"
                        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 41)
                        }
                        try {
                            val intent = Intent(this, HiveNodeService::class.java).putExtra("nodeId", id)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent) else startService(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("NODE_START_FAILED", e.message, null)
                        }
                    }
                    "stopNode" -> { stopService(Intent(this, HiveNodeService::class.java)); result.success(true) }
                    else -> result.notImplemented()
                }
            }
    }
}
