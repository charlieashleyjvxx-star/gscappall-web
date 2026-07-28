package com.gsc.appall

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import android.speech.ModelDownloadListener
import android.speech.RecognitionListener
import android.speech.RecognitionService
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterActivity
import java.util.concurrent.Executor

internal class SystemSpeechBackend(
    private val activity: FlutterActivity,
    private val probe: SpeechBackendProbe,
) : SpeechBackend {
    override val backendId: String = probe.backendId
    override val selectedServiceInfo: String? = probe.selectedServiceInfo

    private var callback: SpeechBackendCallback? = null
    private var recognizer: SpeechRecognizer? = null
    private var listenerBound: Boolean = false

    private val recognitionListener = object : RecognitionListener {
        override fun onReadyForSpeech(params: android.os.Bundle?) {
            callback?.onReadyForSpeech()
        }

        override fun onBeginningOfSpeech() {
            callback?.onBeginningOfSpeech()
        }

        override fun onRmsChanged(rmsdB: Float) {
            callback?.onRmsChanged(rmsdB)
        }

        override fun onBufferReceived(buffer: ByteArray?) = Unit

        override fun onEndOfSpeech() {
            callback?.onEndOfSpeech()
        }

        override fun onError(error: Int) {
            callback?.onError(error)
        }

        override fun onResults(results: android.os.Bundle?) {
            callback?.onResults(extractBestMatch(results))
        }

        override fun onPartialResults(partialResults: android.os.Bundle?) {
            callback?.onPartialResults(extractBestMatch(partialResults))
        }

        override fun onEvent(eventType: Int, params: android.os.Bundle?) = Unit
    }

    override fun bindCallback(callback: SpeechBackendCallback) {
        this.callback = callback
        recognizer?.setRecognitionListener(recognitionListener)
        listenerBound = recognizer != null
    }

    override fun unbindCallback() {
        callback = null
        recognizer?.setRecognitionListener(null)
        listenerBound = false
    }

    override fun ensureRecognizer() {
        if (recognizer != null) {
            recognizer?.setRecognitionListener(recognitionListener)
            listenerBound = true
            return
        }

        recognizer =
            when {
                probe.useOnDeviceRecognizer && android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S -> {
                    SpeechRecognizer.createOnDeviceSpeechRecognizer(activity)
                }

                probe.selectedServiceInfo != null -> {
                    val componentName = ComponentName.unflattenFromString(probe.selectedServiceInfo)
                    if (componentName != null) {
                        SpeechRecognizer.createSpeechRecognizer(activity, componentName)
                    } else {
                        SpeechRecognizer.createSpeechRecognizer(activity)
                    }
                }

                else -> SpeechRecognizer.createSpeechRecognizer(activity)
            }

        recognizer?.setRecognitionListener(recognitionListener)
        listenerBound = recognizer != null
    }

    override fun hasRecognizer(): Boolean = recognizer != null

    override fun isListenerBound(): Boolean = listenerBound

    override fun checkRecognitionSupport(
        intent: Intent,
        executor: Executor,
        listener: SpeechRecognitionSupportListener,
    ) {
        ensureRecognizer()
        if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.TIRAMISU) {
            listener.onReadyToStart()
            return
        }

        recognizer?.checkRecognitionSupport(
            intent,
            executor,
            object : RecognitionSupportCallback {
                override fun onSupportResult(recognitionSupport: RecognitionSupport) {
                    listener.onSupportResult(recognitionSupport)
                }

                override fun onError(error: Int) {
                    listener.onSupportError(error)
                }
            },
        ) ?: listener.onSupportError(SpeechRecognizer.ERROR_CLIENT)
    }

    override fun triggerModelDownload(
        intent: Intent,
        executor: Executor,
        listener: ModelDownloadListener,
    ) {
        ensureRecognizer()
        if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.TIRAMISU) {
            listener.onError(SpeechRecognizer.ERROR_CANNOT_CHECK_SUPPORT)
            return
        }

        recognizer?.triggerModelDownload(intent, executor, listener)
            ?: listener.onError(SpeechRecognizer.ERROR_CLIENT)
    }

    override fun startListening(intent: Intent) {
        ensureRecognizer()
        recognizer?.startListening(intent)
    }

    override fun stopListening() {
        recognizer?.stopListening()
    }

    override fun cancel() {
        recognizer?.cancel()
    }

    override fun destroy() {
        recognizer?.setRecognitionListener(null)
        recognizer?.destroy()
        recognizer = null
        listenerBound = false
        callback = null
    }

    private fun extractBestMatch(bundle: android.os.Bundle?): String {
        val matches = bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        return matches?.firstOrNull()?.trim().orEmpty()
    }

    companion object {
        @Suppress("DEPRECATION")
        fun probe(
            activity: FlutterActivity,
            preferOnDevice: Boolean,
        ): SpeechBackendProbe {
            val packageManager = activity.packageManager
            val services = packageManager.queryIntentServices(
                Intent(RecognitionService.SERVICE_INTERFACE),
                android.content.pm.PackageManager.MATCH_ALL,
            )
            val visibleServices = services.mapNotNull { resolveInfo ->
                resolveInfo.serviceInfo?.let { "${it.packageName}/${it.name}" }
            }
            val configuredService = Settings.Secure.getString(
                activity.contentResolver,
                VOICE_RECOGNITION_SERVICE_SETTING,
            )
            val recognitionAvailable = SpeechRecognizer.isRecognitionAvailable(activity)
            val onDeviceAvailable =
                android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S &&
                    SpeechRecognizer.isOnDeviceRecognitionAvailable(activity)
            val available =
                if (preferOnDevice) {
                    onDeviceAvailable
                } else {
                    recognitionAvailable && visibleServices.isNotEmpty()
                }
            val selectedService =
                when {
                    preferOnDevice && onDeviceAvailable -> "on-device"
                    configuredService.isNullOrBlank() -> visibleServices.firstOrNull()
                    else -> configuredService
                }
            val message =
                if (available) {
                    if (preferOnDevice) {
                        "System on-device backend is available."
                    } else {
                        "System backend is available."
                    }
                } else {
                    if (preferOnDevice) {
                        "System on-device backend is unavailable."
                    } else {
                        "System backend is unavailable."
                    }
                }

            return SpeechBackendProbe(
                backendId = if (preferOnDevice) "system_on_device" else "system_default",
                available = available,
                useOnDeviceRecognizer = preferOnDevice && onDeviceAvailable,
                selectedServiceInfo = selectedService,
                visibleServices = visibleServices,
                message = message,
            )
        }
    }
}
