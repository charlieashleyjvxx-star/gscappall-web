package com.gsc.appall

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var speechBridge: NativeSpeechBridge? = null
    private var textToSpeechBridge: NativeTextToSpeechBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        speechBridge = NativeSpeechBridge(
            activity = this,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
        )
        textToSpeechBridge = NativeTextToSpeechBridge(
            activity = this,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun onDestroy() {
        textToSpeechBridge?.dispose()
        textToSpeechBridge = null
        speechBridge?.dispose()
        speechBridge = null
        super.onDestroy()
    }
}
