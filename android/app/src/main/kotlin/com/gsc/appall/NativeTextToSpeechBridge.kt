package com.gsc.appall

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.speech.tts.Voice
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.Locale
import java.util.UUID

internal class NativeTextToSpeechBridge(
    private val activity: FlutterActivity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val methodChannel = MethodChannel(messenger, TTS_METHOD_CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())

    private var textToSpeech: TextToSpeech? = null
    private var isInitializing = false
    private var engineReady = false
    private var localeReady = false
    private var lastInitMessage: String = "Android native TTS not initialized."
    private val initCallbacks = mutableListOf<(TtsInitState) -> Unit>()
    private var pendingSynthesis: PendingSynthesis? = null

    init {
        methodChannel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        runOnMain {
            when (call.method) {
                "initialize" -> handleInitialize(result)
                "synthesizeToFile" -> handleSynthesize(call, result)
                else -> result.notImplemented()
            }
        }
    }

    fun dispose() {
        runOnMain {
            pendingSynthesis?.let { pending ->
                pending.result.error(
                    "tts_disposed",
                    "TTS bridge was disposed before synthesis completed.",
                    buildStatus(
                        available = false,
                        message = "TTS bridge was disposed before synthesis completed.",
                    ),
                )
            }
            pendingSynthesis = null
            initCallbacks.clear()
            textToSpeech?.stop()
            textToSpeech?.shutdown()
            textToSpeech = null
            engineReady = false
            localeReady = false
            isInitializing = false
            methodChannel.setMethodCallHandler(null)
        }
    }

    private fun handleInitialize(result: MethodChannel.Result) {
        ensureEngine { state ->
            result.success(state.toMap())
        }
    }

    private fun handleSynthesize(call: MethodCall, result: MethodChannel.Result) {
        val text = call.argument<String>("text")?.trim().orEmpty()
        if (text.isBlank()) {
            result.error(
                "tts_empty_text",
                "Text for synthesis cannot be empty.",
                buildStatus(
                    available = false,
                    message = "Text for synthesis cannot be empty.",
                ),
            )
            return
        }

        if (pendingSynthesis != null) {
            result.error(
                "tts_busy",
                "A TTS synthesis task is already running.",
                buildStatus(
                    available = false,
                    message = "A TTS synthesis task is already running.",
                ),
            )
            return
        }

        val localeTag = call.argument<String>("locale")?.ifBlank { DEFAULT_LOCALE_TAG } ?: DEFAULT_LOCALE_TAG
        val speechRate = (call.argument<Double>("speechRate") ?: DEFAULT_SPEECH_RATE)
            .coerceIn(0.6, 1.4)
            .toFloat()
        val pitch = (call.argument<Double>("pitch") ?: DEFAULT_PITCH)
            .coerceIn(0.8, 1.2)
            .toFloat()
        val forceRegenerate = call.argument<Boolean>("forceRegenerate") == true
        val cacheKey = call.argument<String>("cacheKey")?.takeIf { it.isNotBlank() }

        ensureEngine { state ->
            if (!state.available) {
                result.error(
                    "tts_unavailable",
                    state.message,
                    state.toMap(),
                )
                return@ensureEngine
            }

            val engine = textToSpeech
            if (engine == null) {
                result.error(
                    "tts_unavailable",
                    "TextToSpeech engine is not ready.",
                    buildStatus(
                        available = false,
                        message = "TextToSpeech engine is not ready.",
                    ),
                )
                return@ensureEngine
            }

            val locale = Locale.forLanguageTag(localeTag)
            val languageStatus = engine.setLanguage(locale)
            if (!isLanguageSupported(languageStatus)) {
                val message = when (languageStatus) {
                    TextToSpeech.LANG_MISSING_DATA ->
                        "The selected TTS engine is missing language data for $localeTag."

                    TextToSpeech.LANG_NOT_SUPPORTED ->
                        "The selected TTS engine does not support $localeTag."

                    else ->
                        "The selected TTS engine cannot synthesize locale $localeTag."
                }
                localeReady = false
                lastInitMessage = message
                result.error(
                    "tts_language_unavailable",
                    message,
                    buildStatus(
                        available = false,
                        message = message,
                        locale = localeTag,
                    ),
                )
                return@ensureEngine
            }

            localeReady = true
            selectPreferredVoice(engine, locale)
            engine.setSpeechRate(speechRate)
            engine.setPitch(pitch)

            val outputFile = resolveOutputFile(
                text = text,
                localeTag = localeTag,
                speechRate = speechRate,
                pitch = pitch,
                cacheKey = cacheKey,
            )
            if (!forceRegenerate && outputFile.exists() && outputFile.length() > 0L) {
                result.success(
                    buildStatus(
                        available = true,
                        message = "Android native TTS cache hit.",
                        locale = localeTag,
                        speechRate = speechRate.toDouble(),
                        pitch = pitch.toDouble(),
                        outputPath = outputFile.absolutePath,
                        cached = true,
                    ),
                )
                return@ensureEngine
            }

            outputFile.parentFile?.mkdirs()
            if (outputFile.exists()) {
                outputFile.delete()
            }

            val utteranceId = UUID.randomUUID().toString()
            pendingSynthesis = PendingSynthesis(
                utteranceId = utteranceId,
                result = result,
                outputFile = outputFile,
                localeTag = localeTag,
                speechRate = speechRate,
                pitch = pitch,
            )

            val bundle = Bundle().apply {
                putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, utteranceId)
            }

            val synthesizeStatus = engine.synthesizeToFile(
                text,
                bundle,
                outputFile,
                utteranceId,
            )
            if (synthesizeStatus != TextToSpeech.SUCCESS) {
                pendingSynthesis = null
                val message = "Android native TTS failed to start synthesis."
                result.error(
                    "tts_synthesize_failed",
                    message,
                    buildStatus(
                        available = false,
                        message = message,
                        locale = localeTag,
                        speechRate = speechRate.toDouble(),
                        pitch = pitch.toDouble(),
                    ),
                )
                return@ensureEngine
            }

            logTts("synthesizeToFile started path=${outputFile.absolutePath}")
        }
    }

    private fun ensureEngine(callback: (TtsInitState) -> Unit) {
        if (engineReady && localeReady && textToSpeech != null) {
            callback(buildInitState())
            return
        }

        initCallbacks += callback
        if (isInitializing) {
            return
        }

        isInitializing = true
        logTts("initializing Android native TTS")

        textToSpeech = TextToSpeech(activity.applicationContext) { status ->
            runOnMain {
                isInitializing = false
                engineReady = status == TextToSpeech.SUCCESS
                if (!engineReady) {
                    localeReady = false
                    lastInitMessage = "Android native TTS initialization failed."
                    flushInitCallbacks()
                    return@runOnMain
                }

                textToSpeech?.setOnUtteranceProgressListener(progressListener)
                val localeStatus = textToSpeech?.setLanguage(Locale.forLanguageTag(DEFAULT_LOCALE_TAG))
                    ?: TextToSpeech.ERROR
                localeReady = isLanguageSupported(localeStatus)
                lastInitMessage = when {
                    !localeReady && localeStatus == TextToSpeech.LANG_MISSING_DATA ->
                        "Android native TTS is missing language data for $DEFAULT_LOCALE_TAG."

                    !localeReady ->
                        "Android native TTS does not support $DEFAULT_LOCALE_TAG."

                    else ->
                        "Android native TTS is ready."
                }
                flushInitCallbacks()
            }
        }
    }

    private fun flushInitCallbacks() {
        val state = buildInitState()
        val callbacks = initCallbacks.toList()
        initCallbacks.clear()
        callbacks.forEach { callback -> callback(state) }
    }

    private fun buildInitState(): TtsInitState {
        val engineName = textToSpeech?.defaultEngine
        val voiceName = textToSpeech?.voice?.name
        val available = engineReady && localeReady && textToSpeech != null
        return TtsInitState(
            available = available,
            message = lastInitMessage,
            engineName = engineName,
            voiceName = voiceName,
            locale = DEFAULT_LOCALE_TAG,
        )
    }

    private fun buildStatus(
        available: Boolean,
        message: String,
        locale: String = DEFAULT_LOCALE_TAG,
        speechRate: Double = DEFAULT_SPEECH_RATE,
        pitch: Double = DEFAULT_PITCH,
        outputPath: String? = null,
        cached: Boolean = false,
    ): Map<String, Any?> {
        return mapOf(
            "available" to available,
            "message" to message,
            "locale" to locale,
            "speechRate" to speechRate,
            "pitch" to pitch,
            "engine" to textToSpeech?.defaultEngine,
            "voice" to textToSpeech?.voice?.name,
            "outputPath" to outputPath,
            "cached" to cached,
        )
    }

    private fun resolveOutputFile(
        text: String,
        localeTag: String,
        speechRate: Float,
        pitch: Float,
        cacheKey: String?,
    ): File {
        val safeKey = cacheKey?.replace(Regex("[^A-Za-z0-9._-]"), "_")
        val sourceKey = buildString {
            append(safeKey ?: text)
            append('|')
            append(textToSpeech?.defaultEngine ?: "default")
            append('|')
            append(textToSpeech?.voice?.name ?: "default_voice")
            append('|')
            append(localeTag)
            append('|')
            append(speechRate)
            append('|')
            append(pitch)
        }
        val digest = sha1(sourceKey)
        val directory = File(activity.filesDir, "tts_cache")
        return File(directory, "tts_$digest.wav")
    }

    private fun sha1(input: String): String {
        val digest = MessageDigest.getInstance("SHA-1").digest(input.toByteArray())
        return digest.joinToString(separator = "") { byte -> "%02x".format(byte) }
    }

    private fun isLanguageSupported(status: Int?): Boolean {
        return status == TextToSpeech.LANG_AVAILABLE ||
            status == TextToSpeech.LANG_COUNTRY_AVAILABLE ||
            status == TextToSpeech.LANG_COUNTRY_VAR_AVAILABLE
    }

    private fun selectPreferredVoice(
        engine: TextToSpeech,
        locale: Locale,
    ) {
        val preferredVoice = engine.voices
            ?.asSequence()
            ?.filter { voice -> voice.locale.language == locale.language }
            ?.sortedWith(
                compareByDescending<Voice> { voice ->
                    voice.locale.toLanguageTag().equals(locale.toLanguageTag(), ignoreCase = true)
                }
                    .thenByDescending { voice -> voice.quality }
                    .thenBy { voice -> voice.latency }
                    .thenBy { voice -> voice.isNetworkConnectionRequired },
            )
            ?.firstOrNull()
            ?: return

        try {
            engine.voice = preferredVoice
            logTts(
                "preferred voice selected name=${preferredVoice.name} " +
                    "quality=${preferredVoice.quality} network=${preferredVoice.isNetworkConnectionRequired}",
            )
        } catch (error: RuntimeException) {
            logTts("preferred voice selection failed: ${error.javaClass.simpleName}")
        }
    }

    private fun runOnMain(action: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            action()
        } else {
            mainHandler.post(action)
        }
    }

    private fun logTts(message: String) {
        Log.d(TTS_LOG_TAG, "[TTS][Android] $message")
    }

    private val progressListener = object : UtteranceProgressListener() {
        override fun onStart(utteranceId: String?) {
            logTts("onStart utteranceId=$utteranceId")
        }

        override fun onDone(utteranceId: String?) {
            runOnMain {
                val pending = pendingSynthesis
                if (pending == null || pending.utteranceId != utteranceId) {
                    return@runOnMain
                }
                pendingSynthesis = null
                pending.result.success(
                    buildStatus(
                        available = true,
                        message = "Android native TTS synthesis completed.",
                        locale = pending.localeTag,
                        speechRate = pending.speechRate.toDouble(),
                        pitch = pending.pitch.toDouble(),
                        outputPath = pending.outputFile.absolutePath,
                        cached = false,
                    ),
                )
            }
        }

        @Deprecated("Deprecated in Java")
        override fun onError(utteranceId: String?) {
            handleSynthesisError(
                utteranceId = utteranceId,
                errorMessage = "Android native TTS synthesis failed.",
            )
        }

        override fun onError(utteranceId: String?, errorCode: Int) {
            handleSynthesisError(
                utteranceId = utteranceId,
                errorMessage = "Android native TTS synthesis failed with error code $errorCode.",
            )
        }

        override fun onStop(utteranceId: String?, interrupted: Boolean) {
            handleSynthesisError(
                utteranceId = utteranceId,
                errorMessage =
                    if (interrupted) {
                        "Android native TTS synthesis was interrupted."
                    } else {
                        "Android native TTS synthesis was stopped."
                    },
            )
        }
    }

    private fun handleSynthesisError(
        utteranceId: String?,
        errorMessage: String,
    ) {
        runOnMain {
            val pending = pendingSynthesis
            if (pending == null || pending.utteranceId != utteranceId) {
                return@runOnMain
            }
            pendingSynthesis = null
            pending.result.error(
                "tts_synthesize_failed",
                errorMessage,
                buildStatus(
                    available = false,
                    message = errorMessage,
                    locale = pending.localeTag,
                    speechRate = pending.speechRate.toDouble(),
                    pitch = pending.pitch.toDouble(),
                ),
            )
        }
    }

    private data class PendingSynthesis(
        val utteranceId: String,
        val result: MethodChannel.Result,
        val outputFile: File,
        val localeTag: String,
        val speechRate: Float,
        val pitch: Float,
    )

    private data class TtsInitState(
        val available: Boolean,
        val message: String,
        val engineName: String?,
        val voiceName: String?,
        val locale: String,
    ) {
        fun toMap(): Map<String, Any?> {
            return mapOf(
                "available" to available,
                "message" to message,
                "engine" to engineName,
                "voice" to voiceName,
                "locale" to locale,
            )
        }
    }

    companion object {
        private const val DEFAULT_LOCALE_TAG = "zh-CN"
        private const val DEFAULT_SPEECH_RATE = 1.0
        private const val DEFAULT_PITCH = 1.0
        private const val TTS_METHOD_CHANNEL = "gscappall/tts/methods"
        private const val TTS_LOG_TAG = "GSCTts"
    }
}
