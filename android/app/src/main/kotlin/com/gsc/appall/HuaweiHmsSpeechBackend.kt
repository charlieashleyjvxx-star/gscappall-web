package com.gsc.appall

import android.content.Intent
import android.content.pm.PackageManager
import android.speech.ModelDownloadListener
import io.flutter.embedding.android.FlutterActivity
import java.util.concurrent.Executor

internal class HuaweiHmsSpeechBackend(
    private val activity: FlutterActivity,
    override val selectedServiceInfo: String?,
) : SpeechBackend {
    override val backendId: String = "huawei_hms"

    override fun bindCallback(callback: SpeechBackendCallback) = Unit

    override fun unbindCallback() = Unit

    override fun ensureRecognizer() = Unit

    override fun hasRecognizer(): Boolean = false

    override fun isListenerBound(): Boolean = false

    override fun checkRecognitionSupport(
        intent: Intent,
        executor: Executor,
        listener: SpeechRecognitionSupportListener,
    ) {
        listener.onSupportError(android.speech.SpeechRecognizer.ERROR_CLIENT)
    }

    override fun triggerModelDownload(
        intent: Intent,
        executor: Executor,
        listener: ModelDownloadListener,
    ) {
        listener.onError(android.speech.SpeechRecognizer.ERROR_CLIENT)
    }

    override fun startListening(intent: Intent) {
        throw IllegalStateException("Huawei HMS speech backend is not implemented yet.")
    }

    override fun stopListening() = Unit

    override fun cancel() = Unit

    override fun destroy() = Unit

    companion object {
        fun probe(activity: FlutterActivity): SpeechBackendProbe {
            val packageManager = activity.packageManager
            val candidatePackages = listOf("com.huawei.hms", "com.huawei.hwid")
            val installedPackages = candidatePackages.filter { packageName ->
                packageExists(packageManager, packageName)
            }
            val available = installedPackages.isNotEmpty()
            val message =
                if (available) {
                    "Huawei HMS speech backend candidate is available: ${installedPackages.joinToString()}."
                } else {
                    "Huawei HMS speech backend candidate is unavailable."
                }

            return SpeechBackendProbe(
                backendId = "huawei_hms",
                available = available,
                useOnDeviceRecognizer = false,
                selectedServiceInfo = installedPackages.firstOrNull(),
                visibleServices = installedPackages,
                message = message,
            )
        }

        private fun packageExists(
            packageManager: PackageManager,
            packageName: String,
        ): Boolean {
            return try {
                packageManager.getPackageInfo(packageName, 0)
                true
            } catch (_: PackageManager.NameNotFoundException) {
                false
            }
        }
    }
}
