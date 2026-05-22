package com.rannarjogot.rannar_jogot

import android.content.pm.ActivityInfo
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"rannar_jogot/orientation"
		).setMethodCallHandler { call, result ->
			when (call.method) {
				"forceLandscape" -> {
					requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
					result.success(null)
				}

				"forcePortrait" -> {
					requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
					result.success(null)
				}

				else -> result.notImplemented()
			}
		}
	}
}
