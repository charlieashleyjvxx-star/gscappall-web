package com.gsc.appall

import android.os.Build
import android.speech.SpeechRecognizer

internal const val SPEECH_LOG_TAG = "GSCSpeech"
internal const val SPEECH_METHOD_CHANNEL = "gscappall/speech/methods"
internal const val SPEECH_EVENT_CHANNEL = "gscappall/speech/events"
internal const val SPEECH_LANGUAGE_TAG = "zh-CN"
internal const val VOICE_RECOGNITION_SERVICE_SETTING = "voice_recognition_service"

internal val SPEECH_BIASING_STRINGS = listOf(
    "刷牙",
    "洗手",
    "整理书包",
    "我完成了",
    "开始任务",
    "今天打卡",
    "再说一遍",
)

internal enum class SpeechSessionState(val wireName: String) {
    IDLE("idle"),
    INITIALIZING("initializing"),
    READY("ready"),
    LISTENING("listening"),
    STOPPING("stopping"),
    COMPLETED("completed"),
    ERROR("error"),
    DESTROYED("destroyed"),
}

internal data class SpeechDebugSnapshot(
    val permissionGranted: Boolean,
    val isRecognitionAvailable: Boolean,
    val isOnDeviceRecognitionAvailable: Boolean,
    val eventSinkReady: Boolean,
    val recognizerCreated: Boolean,
    val listenerBound: Boolean,
    val currentState: String,
    val currentLocale: String,
    val selectedBackend: String,
    val currentDeviceBrand: String,
    val currentDeviceManufacturer: String,
    val sdkInt: Int,
    val selectedServiceInfo: String?,
    val diagnostics: List<String>,
) {
    fun toMap(): Map<String, Any?> {
        return mapOf(
            "permissionGranted" to permissionGranted,
            "isRecognitionAvailable" to isRecognitionAvailable,
            "isOnDeviceRecognitionAvailable" to isOnDeviceRecognitionAvailable,
            "eventSinkReady" to eventSinkReady,
            "recognizerCreated" to recognizerCreated,
            "listenerBound" to listenerBound,
            "currentState" to currentState,
            "currentLocale" to currentLocale,
            "selectedBackend" to selectedBackend,
            "currentDeviceBrand" to currentDeviceBrand,
            "currentDeviceManufacturer" to currentDeviceManufacturer,
            "sdkInt" to sdkInt,
            "selectedServiceInfo" to selectedServiceInfo,
            "diagnostics" to diagnostics,
        )
    }
}

internal data class SpeechEventPayload(
    val type: String,
    val text: String,
    val isFinal: Boolean,
    val errorCode: Int?,
    val errorName: String?,
    val backend: String,
    val state: String,
    val timestamp: Long,
    val debugSnapshot: SpeechDebugSnapshot,
    val extras: Map<String, Any?> = emptyMap(),
) {
    fun toMap(): Map<String, Any?> {
        return buildMap<String, Any?> {
            put("type", type)
            put("text", text)
            put("isFinal", isFinal)
            put("errorCode", errorCode)
            put("errorName", errorName)
            put("backend", backend)
            put("state", state)
            put("timestamp", timestamp)
            put("debugSnapshot", debugSnapshot.toMap())
            putAll(extras)
        }
    }
}

internal fun speechErrorName(errorCode: Int): String {
    return when (errorCode) {
        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "ERROR_NETWORK_TIMEOUT"
        SpeechRecognizer.ERROR_NETWORK -> "ERROR_NETWORK"
        SpeechRecognizer.ERROR_AUDIO -> "ERROR_AUDIO"
        SpeechRecognizer.ERROR_SERVER -> "ERROR_SERVER"
        SpeechRecognizer.ERROR_CLIENT -> "ERROR_CLIENT"
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "ERROR_SPEECH_TIMEOUT"
        SpeechRecognizer.ERROR_NO_MATCH -> "ERROR_NO_MATCH"
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "ERROR_RECOGNIZER_BUSY"
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "ERROR_INSUFFICIENT_PERMISSIONS"
        SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED -> "ERROR_LANGUAGE_NOT_SUPPORTED"
        SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> "ERROR_LANGUAGE_UNAVAILABLE"
        SpeechRecognizer.ERROR_CANNOT_CHECK_SUPPORT -> "ERROR_CANNOT_CHECK_SUPPORT"
        SpeechRecognizer.ERROR_CANNOT_LISTEN_TO_DOWNLOAD_EVENTS -> "ERROR_CANNOT_LISTEN_TO_DOWNLOAD_EVENTS"
        SpeechRecognizer.ERROR_SERVER_DISCONNECTED -> "ERROR_SERVER_DISCONNECTED"
        SpeechRecognizer.ERROR_TOO_MANY_REQUESTS -> "ERROR_TOO_MANY_REQUESTS"
        else -> "ERROR_UNKNOWN_$errorCode"
    }
}

internal fun speechErrorMessage(errorCode: Int): String {
    return when (errorCode) {
        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Speech recognition network timeout."
        SpeechRecognizer.ERROR_NETWORK -> "Network error while recognizing speech."
        SpeechRecognizer.ERROR_AUDIO -> "Audio input error."
        SpeechRecognizer.ERROR_SERVER -> "Speech recognition service error."
        SpeechRecognizer.ERROR_CLIENT -> "Speech recognition client error."
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No speech was detected in time."
        SpeechRecognizer.ERROR_NO_MATCH -> "No clear speech result was recognized."
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Speech recognizer is busy."
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Speech recognition permission is missing."
        SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED -> "The requested language is not supported."
        SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> "The requested language model is unavailable."
        SpeechRecognizer.ERROR_CANNOT_CHECK_SUPPORT -> "The device cannot check language support right now."
        SpeechRecognizer.ERROR_CANNOT_LISTEN_TO_DOWNLOAD_EVENTS ->
            "The device cannot listen to speech model download events."
        SpeechRecognizer.ERROR_SERVER_DISCONNECTED -> "The speech recognition service disconnected."
        SpeechRecognizer.ERROR_TOO_MANY_REQUESTS -> "Too many recognition requests were made."
        else -> "Speech recognition failed with error code $errorCode."
    }
}

internal fun isHuaweiOrHonorDevice(): Boolean {
    val brand = Build.BRAND.lowercase()
    val manufacturer = Build.MANUFACTURER.lowercase()
    return brand.contains("huawei") ||
        brand.contains("honor") ||
        manufacturer.contains("huawei") ||
        manufacturer.contains("honor")
}
