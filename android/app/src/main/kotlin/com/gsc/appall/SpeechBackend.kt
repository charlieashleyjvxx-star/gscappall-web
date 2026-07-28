package com.gsc.appall

import android.content.Intent
import android.speech.ModelDownloadListener
import android.speech.RecognitionSupport
import java.util.concurrent.Executor

internal data class SpeechBackendProbe(
    val backendId: String,
    val available: Boolean,
    val useOnDeviceRecognizer: Boolean,
    val selectedServiceInfo: String?,
    val visibleServices: List<String>,
    val message: String,
)

internal data class SpeechBackendSelection(
    val backend: SpeechBackend,
    val selectedProbe: SpeechBackendProbe,
    val diagnostics: List<String>,
    val hmsCandidateProbe: SpeechBackendProbe?,
)

internal interface SpeechBackendCallback {
    fun onReadyForSpeech()
    fun onBeginningOfSpeech()
    fun onRmsChanged(rmsDb: Float)
    fun onEndOfSpeech()
    fun onPartialResults(text: String)
    fun onResults(text: String)
    fun onError(errorCode: Int)
}

internal interface SpeechRecognitionSupportListener {
    fun onReadyToStart()
    fun onSupportResult(recognitionSupport: RecognitionSupport)
    fun onSupportError(errorCode: Int)
}

internal interface SpeechBackend {
    val backendId: String
    val selectedServiceInfo: String?

    fun bindCallback(callback: SpeechBackendCallback)
    fun unbindCallback()
    fun ensureRecognizer()
    fun hasRecognizer(): Boolean
    fun isListenerBound(): Boolean
    fun checkRecognitionSupport(
        intent: Intent,
        executor: Executor,
        listener: SpeechRecognitionSupportListener,
    )

    fun triggerModelDownload(
        intent: Intent,
        executor: Executor,
        listener: ModelDownloadListener,
    )

    fun startListening(intent: Intent)
    fun stopListening()
    fun cancel()
    fun destroy()
}
