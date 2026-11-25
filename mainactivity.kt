package com.example.electro_pass // <-- keep YOUR existing package line from the old MainActivity.kt

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.view.autofill.AutofillManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "electro/autofill")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isEnabled" -> {
                        val m = getSystemService(AutofillManager::class.java)
                        result.success(m != null && m.hasEnabledAutofillServices())
                    }
                    "openSettings" -> {
                        try {
                            val i = Intent(Settings.ACTION_REQUEST_SET_AUTOFILL_SERVICE)
                            i.data = Uri.parse("package:$packageName")
                            startActivity(i)
                        } catch (e: Exception) {
                            try {
                                startActivity(Intent(Settings.ACTION_SETTINGS))
                            } catch (_: Exception) {
                            }
                        }
                        result.success(true)
                    }
                    "sync" -> {
                        AutofillVault.save(this, call.arguments as String)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}