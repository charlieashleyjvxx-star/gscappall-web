package com.gsc.appall

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.speech.ModelDownloadListener
import android.speech.RecognitionSupport
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

internal class NativeSpeechBridge(
    private val activity: FlutterActivity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler, SpeechBackendCallback {
    private val methodChannel = MethodChannel(messenger, SPEECH_METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, SPEECH_EVENT_CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val mainExecutor = ContextCompat.getMainExecutor(activity)
    private val backendSelector = SpeechBackendSelector(activity)

    private var eventSink: EventChannel.EventSink? = null
    private var currentState: SpeechSessionState = SpeechSessionState.IDLE
    private var backendSelection: SpeechBackendSelection? = null
    private var backend: SpeechBackend? = null
    private var activeSessionId: Long = 0
    private var latestText: String = ""
    private var stopRequested: Boolean = false

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        runOnMain {
            when (call.method) {
                "initialize" -> handleInitialize(result, emitEvent = true)
                "startListening" -> handleStartListening(result)
                "stopListening" -> handleStopListening(result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        runOnMain {
            logBridge("event sink attached")
            eventSink = events
        }
    }

    override fun onCancel(arguments: Any?) {
        runOnMain {
            logBridge("event sink detached")
            eventSink = null
        }
    }

    override fun onReadyForSpeech() {
        runOnMain {
            logAndroid("callback onReadyForSpeech")
            emitEvent(type = "onReadyForSpeech")
        }
    }

    override fun onBeginningOfSpeech() {
        runOnMain {
            transitionState(SpeechSessionState.LISTENING, "onBeginningOfSpeech")
            logAndroid("callback onBeginningOfSpeech")
            emitEvent(type = "onBeginningOfSpeech")
        }
    }

    override fun onRmsChanged(rmsDb: Float) {
        runOnMain {
            emitEvent(
                type = "onRmsChanged",
                extras = mapOf("rmsDb" to rmsDb),
            )
        }
    }

    override fun onEndOfSpeech() {
        runOnMain {
            transitionState(SpeechSessionState.STOPPING, "onEndOfSpeech")
            logAndroid("callback onEndOfSpeech")
            emitEvent(type = "onEndOfSpeech", text = latestText)
        }
    }

    override fun onPartialResults(text: String) {
        runOnMain {
            if (text.isNotBlank()) {
                latestText = text
            }
            transitionState(SpeechSessionState.LISTENING, "onPartialResults")
            logAndroid("callback onPartialResults textLength=${latestText.length}")
            emitEvent(
                type = "onPartialResults",
                text = latestText,
                isFinal = false,
            )
        }
    }

    override fun onResults(text: String) {
        runOnMain {
            if (text.isNotBlank()) {
                latestText = text
            }
            stopRequested = false
            transitionState(SpeechSessionState.COMPLETED, "onResults")
            logAndroid("callback onResults textLength=${latestText.length}")
            emitEvent(
                type = "onResults",
                text = latestText,
                isFinal = true,
            )
        }
    }

    override fun onError(errorCode: Int) {
        runOnMain {
            stopRequested = false
            transitionState(SpeechSessionState.ERROR, "onError:${speechErrorName(errorCode)}")
            logAndroid(
                "callback onError code=$errorCode name=${speechErrorName(errorCode)}",
            )
            emitEvent(
                type = "onError",
                text = latestText,
                isFinal = false,
                errorCode = errorCode,
                errorName = speechErrorName(errorCode),
            )
        }
    }

    fun dispose() {
        runOnMain {
            logBridge("dispose bridge")
            transitionState(SpeechSessionState.DESTROYED, "dispose")
            backend?.unbindCallback()
            backend?.destroy()
            backend = null
            backendSelection = null
            emitEvent(type = "destroyed", text = latestText)
            eventSink = null
            methodChannel.setMethodCallHandler(null)
            eventChannel.setStreamHandler(null)
        }
    }

    private fun handleInitialize(
        result: MethodChannel.Result,
        emitEvent: Boolean,
    ) {
        transitionState(SpeechSessionState.INITIALIZING, "initialize")
        val selection = backendSelector.selectBackend()
        installBackend(selection)

        selection.diagnostics.forEach { diagnostic ->
            logBridge("selector $diagnostic")
        }

        val permissionGranted = hasRecordPermission()
        val supported = selection.selectedProbe.available
        val errorCode = when {
            !permissionGranted -> "speech_permission_denied"
            supported -> null
            else -> "speech_unavailable"
        }
        val message = selection.selectedProbe.message

        transitionState(
            if (permissionGranted && supported) {
                SpeechSessionState.READY
            } else {
                SpeechSessionState.ERROR
            },
            "initialize-complete",
        )

        val status = buildMethodStatus(
            message = message,
            errorCode = errorCode,
            extras = mapOf(
                "supported" to supported,
                "authorized" to permissionGranted,
                "backend" to selection.selectedProbe.backendId,
                "selectedServiceInfo" to selection.selectedProbe.selectedServiceInfo,
                "diagnostics" to selection.diagnostics,
            ),
        )
        if (emitEvent) {
            emitEvent(type = "initialize", text = latestText)
        }
        result.success(status)
    }

    private fun handleStartListening(result: MethodChannel.Result) {
        if (currentState == SpeechSessionState.DESTROYED) {
            result.error(
                "speech_backend_destroyed",
                "Speech bridge was already destroyed.",
                buildMethodStatus(
                    message = "Speech bridge was already destroyed.",
                    errorCode = "speech_backend_destroyed",
                ),
            )
            return
        }

        if (eventSink == null) {
            result.error(
                "event_channel_not_ready",
                "EventChannel is not ready before startListening.",
                buildMethodStatus(
                    message = "EventChannel is not ready before startListening.",
                    errorCode = "event_channel_not_ready",
                ),
            )
            return
        }

        if (
            currentState == SpeechSessionState.INITIALIZING ||
            currentState == SpeechSessionState.LISTENING ||
            currentState == SpeechSessionState.STOPPING
        ) {
            result.error(
                "speech_session_busy",
                "Speech recognition is already active.",
                buildMethodStatus(
                    message = "Speech recognition is already active.",
                    errorCode = "speech_session_busy",
                ),
            )
            return
        }

        handleInitialize(result = CapturingResult(), emitEvent = false)
        val selection = backendSelection
        val speechBackend = backend
        val permissionGranted = hasRecordPermission()
        if (selection == null || speechBackend == null || !permissionGranted || !selection.selectedProbe.available) {
            val message = selection?.selectedProbe?.message ?: "Speech backend is unavailable."
            result.error(
                "speech_unavailable",
                message,
                buildMethodStatus(message = message, errorCode = "speech_unavailable"),
            )
            return
        }

        activeSessionId += 1
        latestText = ""
        stopRequested = false
        transitionState(SpeechSessionState.INITIALIZING, "startListening#$activeSessionId")
        emitEvent(
            type = "recognize",
            extras = mapOf("sessionId" to activeSessionId),
        )

        try {
            speechBackend.ensureRecognizer()
        } catch (error: Throwable) {
            transitionState(SpeechSessionState.ERROR, "ensureRecognizerFailed")
            val message = error.message ?: "Failed to create SpeechRecognizer."
            result.error(
                "speech_start_failed",
                message,
                buildMethodStatus(message = message, errorCode = "speech_start_failed"),
            )
            return
        }

        val intent = buildRecognitionIntent()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            speechBackend.checkRecognitionSupport(
                intent,
                mainExecutor,
                object : SpeechRecognitionSupportListener {
                    override fun onReadyToStart() {
                        startBackendListening(speechBackend, intent, result)
                    }

                    override fun onSupportResult(recognitionSupport: RecognitionSupport) {
                        handleRecognitionSupport(
                            recognitionSupport = recognitionSupport,
                            speechBackend = speechBackend,
                            intent = intent,
                            result = result,
                        )
                    }

                    override fun onSupportError(errorCode: Int) {
                        handleSupportError(errorCode, result)
                    }
                },
            )
        } else {
            startBackendListening(speechBackend, intent, result)
        }
    }

    private fun handleStopListening(result: MethodChannel.Result) {
        val speechBackend = backend
        if (speechBackend == null) {
            result.error(
                "speech_stop_failed",
                "Speech backend is not ready.",
                buildMethodStatus(
                    message = "Speech backend is not ready.",
                    errorCode = "speech_stop_failed",
                ),
            )
            return
        }

        if (
            currentState != SpeechSessionState.LISTENING &&
            currentState != SpeechSessionState.STOPPING
        ) {
            result.error(
                "speech_stop_invalid_state",
                "stop() can only be called while listening.",
                buildMethodStatus(
                    message = "stop() can only be called while listening.",
                    errorCode = "speech_stop_invalid_state",
                ),
            )
            return
        }

        if (currentState == SpeechSessionState.STOPPING) {
            result.success(
                buildMethodStatus(
                    message = "Speech recognition stop is already in progress.",
                    errorCode = null,
                ),
            )
            return
        }

        stopRequested = true
        transitionState(SpeechSessionState.STOPPING, "stopListening")
        emitEvent(type = "stop", text = latestText)

        try {
            speechBackend.stopListening()
            result.success(
                buildMethodStatus(
                    message = "Speech recognition stop was requested.",
                    errorCode = null,
                ),
            )
        } catch (error: Throwable) {
            transitionState(SpeechSessionState.ERROR, "stopListeningFailed")
            val message = error.message ?: "Failed to stop speech recognition."
            result.error(
                "speech_stop_failed",
                message,
                buildMethodStatus(
                    message = message,
                    errorCode = "speech_stop_failed",
                ),
            )
        }
    }

    private fun handleRecognitionSupport(
        recognitionSupport: RecognitionSupport,
        speechBackend: SpeechBackend,
        intent: Intent,
        result: MethodChannel.Result,
    ) {
        val installed = recognitionSupport.installedOnDeviceLanguages.orEmpty()
        val pending = recognitionSupport.pendingOnDeviceLanguages.orEmpty()
        val supported = recognitionSupport.supportedOnDeviceLanguages.orEmpty()
        val online = recognitionSupport.onlineLanguages.orEmpty()
        val supportExtras = mapOf(
            "installedOnDeviceLanguages" to installed,
            "pendingOnDeviceLanguages" to pending,
            "supportedOnDeviceLanguages" to supported,
            "onlineLanguages" to online,
        )

        emitEvent(type = "support", extras = supportExtras)

        val installedReady = installed.any(::matchesTargetLanguage)
        val pendingReady = pending.any(::matchesTargetLanguage)
        val supportedReady = supported.any(::matchesTargetLanguage)
        val onlineReady = online.any(::matchesTargetLanguage)

        when {
            installedReady || onlineReady -> {
                startBackendListening(speechBackend, intent, result)
            }

            pendingReady -> {
                transitionState(SpeechSessionState.ERROR, "modelPending")
                emitEvent(
                    type = "onError",
                    text = latestText,
                    errorCode = SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE,
                    errorName = speechErrorName(SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE),
                    extras = supportExtras + mapOf("downloadState" to "pending"),
                )
                result.error(
                    "speech_language_unavailable",
                    "Speech model download is pending for $SPEECH_LANGUAGE_TAG.",
                    buildMethodStatus(
                        message = "Speech model download is pending for $SPEECH_LANGUAGE_TAG.",
                        errorCode = "speech_language_unavailable",
                        extras = supportExtras + mapOf("downloadState" to "pending"),
                    ),
                )
            }

            supportedReady -> {
                emitEvent(
                    type = "modelDownloadRequested",
                    extras = supportExtras,
                )
                speechBackend.triggerModelDownload(
                    intent,
                    mainExecutor,
                    object : ModelDownloadListener {
                        override fun onProgress(completedPercent: Int) {
                            emitEvent(
                                type = "modelDownloadProgress",
                                extras = supportExtras + mapOf("progress" to completedPercent),
                            )
                        }

                        override fun onSuccess() {
                            transitionState(SpeechSessionState.READY, "modelDownloadSuccess")
                            emitEvent(type = "modelDownloadSuccess", extras = supportExtras)
                        }

                        override fun onScheduled() {
                            emitEvent(type = "modelDownloadScheduled", extras = supportExtras)
                        }

                        override fun onError(error: Int) {
                            transitionState(SpeechSessionState.ERROR, "modelDownloadError")
                            emitEvent(
                                type = "onError",
                                text = latestText,
                                errorCode = error,
                                errorName = speechErrorName(error),
                                extras = supportExtras + mapOf("downloadState" to "failed"),
                            )
                        }
                    },
                )
                transitionState(SpeechSessionState.ERROR, "modelDownloadTriggered")
                result.error(
                    "speech_language_unavailable",
                    "Speech model download was triggered for $SPEECH_LANGUAGE_TAG.",
                    buildMethodStatus(
                        message = "Speech model download was triggered for $SPEECH_LANGUAGE_TAG.",
                        errorCode = "speech_language_unavailable",
                        extras = supportExtras + mapOf("downloadState" to "triggered"),
                    ),
                )
            }

            else -> {
                transitionState(SpeechSessionState.ERROR, "languageNotSupported")
                emitEvent(
                    type = "onError",
                    text = latestText,
                    errorCode = SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED,
                    errorName = speechErrorName(SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED),
                    extras = supportExtras,
                )
                result.error(
                    "speech_language_not_supported",
                    "The selected speech backend does not support $SPEECH_LANGUAGE_TAG.",
                    buildMethodStatus(
                        message = "The selected speech backend does not support $SPEECH_LANGUAGE_TAG.",
                        errorCode = "speech_language_not_supported",
                        extras = supportExtras,
                    ),
                )
            }
        }
    }

    private fun handleSupportError(
        errorCode: Int,
        result: MethodChannel.Result,
    ) {
        transitionState(SpeechSessionState.ERROR, "supportCheckError")
        emitEvent(
            type = "onError",
            text = latestText,
            errorCode = errorCode,
            errorName = speechErrorName(errorCode),
        )
        result.error(
            "speech_support_check_failed",
            speechErrorMessage(errorCode),
            buildMethodStatus(
                message = speechErrorMessage(errorCode),
                errorCode = "speech_support_check_failed",
                extras = mapOf(
                    "nativeErrorCode" to errorCode,
                    "nativeErrorName" to speechErrorName(errorCode),
                ),
            ),
        )
    }

    private fun startBackendListening(
        speechBackend: SpeechBackend,
        intent: Intent,
        result: MethodChannel.Result,
    ) {
        try {
            speechBackend.startListening(intent)
            transitionState(SpeechSessionState.LISTENING, "startListeningConfirmed")
            emitEvent(type = "listening", text = latestText)
            result.success(
                buildMethodStatus(
                    message = "Speech recognition started.",
                    errorCode = null,
                    extras = mapOf("sessionId" to activeSessionId),
                ),
            )
        } catch (error: Throwable) {
            transitionState(SpeechSessionState.ERROR, "startListeningFailed")
            val message = error.message ?: "Failed to start speech recognition."
            result.error(
                "speech_start_failed",
                message,
                buildMethodStatus(
                    message = message,
                    errorCode = "speech_start_failed",
                ),
            )
        }
    }

    private fun installBackend(selection: SpeechBackendSelection) {
        backend?.unbindCallback()
        backend?.destroy()
        backendSelection = selection
        backend = selection.backend
        backend?.bindCallback(this)
    }

    private fun emitEvent(
        type: String,
        text: String = latestText,
        isFinal: Boolean = false,
        errorCode: Int? = null,
        errorName: String? = null,
        extras: Map<String, Any?> = emptyMap(),
    ) {
        val sink = eventSink
        val payload = SpeechEventPayload(
            type = type,
            text = text,
            isFinal = isFinal,
            errorCode = errorCode,
            errorName = errorName,
            backend = backendSelection?.selectedProbe?.backendId ?: "unselected",
            state = currentState.wireName,
            timestamp = System.currentTimeMillis(),
            debugSnapshot = buildSnapshot(),
            extras = extras,
        )

        if (sink == null) {
            logBridge("skip emitEvent type=$type because sink is not ready")
            return
        }

        sink.success(payload.toMap())
    }

    private fun buildMethodStatus(
        message: String,
        errorCode: String?,
        extras: Map<String, Any?> = emptyMap(),
    ): Map<String, Any?> {
        return buildMap {
            put("message", message)
            put("errorCode", errorCode)
            put("state", currentState.wireName)
            put("backend", backendSelection?.selectedProbe?.backendId)
            put("timestamp", System.currentTimeMillis())
            put("debugSnapshot", buildSnapshot().toMap())
            putAll(extras)
        }
    }

    private fun buildSnapshot(): SpeechDebugSnapshot {
        return SpeechDebugSnapshot(
            permissionGranted = hasRecordPermission(),
            isRecognitionAvailable = SpeechRecognizer.isRecognitionAvailable(activity),
            isOnDeviceRecognitionAvailable = isOnDeviceRecognitionAvailable(),
            eventSinkReady = eventSink != null,
            recognizerCreated = backend?.hasRecognizer() == true,
            listenerBound = backend?.isListenerBound() == true,
            currentState = currentState.wireName,
            currentLocale = SPEECH_LANGUAGE_TAG,
            selectedBackend = backendSelection?.selectedProbe?.backendId ?: "unselected",
            currentDeviceBrand = Build.BRAND,
            currentDeviceManufacturer = Build.MANUFACTURER,
            sdkInt = Build.VERSION.SDK_INT,
            selectedServiceInfo = backendSelection?.selectedProbe?.selectedServiceInfo,
            diagnostics = backendSelection?.diagnostics.orEmpty(),
        )
    }

    private fun buildRecognitionIntent(): Intent {
        return Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, SPEECH_LANGUAGE_TAG)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, SPEECH_LANGUAGE_TAG)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, activity.packageName)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                putStringArrayListExtra(
                    RecognizerIntent.EXTRA_BIASING_STRINGS,
                    ArrayList(SPEECH_BIASING_STRINGS),
                )
            }
        }
    }

    private fun transitionState(nextState: SpeechSessionState, reason: String) {
        if (currentState == nextState) {
            return
        }
        logState("${currentState.wireName} -> ${nextState.wireName} reason=$reason")
        currentState = nextState
    }

    private fun hasRecordPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun isOnDeviceRecognitionAvailable(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            SpeechRecognizer.isOnDeviceRecognitionAvailable(activity)
    }

    private fun matchesTargetLanguage(languageTag: String): Boolean {
        val candidateLocale = Locale.forLanguageTag(languageTag)
        val targetLocale = Locale.forLanguageTag(SPEECH_LANGUAGE_TAG)
        val candidateLanguage =
            if (candidateLocale.language.isNullOrBlank()) {
                languageTag.substringBefore('-').lowercase()
            } else {
                candidateLocale.language.lowercase()
            }
        return candidateLanguage == targetLocale.language.lowercase()
    }

    private fun runOnMain(action: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            action()
        } else {
            mainHandler.post(action)
        }
    }

    private fun logAndroid(message: String) {
        Log.d(SPEECH_LOG_TAG, "[Speech][Android] $message")
    }

    private fun logBridge(message: String) {
        Log.d(SPEECH_LOG_TAG, "[Speech][Bridge] $message")
    }

    private fun logState(message: String) {
        Log.d(SPEECH_LOG_TAG, "[Speech][State] $message")
    }

    private class CapturingResult : MethodChannel.Result {
        override fun success(result: Any?) = Unit

        override fun error(
            errorCode: String,
            errorMessage: String?,
            errorDetails: Any?,
        ) = Unit

        override fun notImplemented() = Unit
    }
}
