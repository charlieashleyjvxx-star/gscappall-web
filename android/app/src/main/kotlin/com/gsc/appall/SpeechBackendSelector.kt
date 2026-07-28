package com.gsc.appall

import io.flutter.embedding.android.FlutterActivity

internal class SpeechBackendSelector(
    private val activity: FlutterActivity,
) {
    fun selectBackend(): SpeechBackendSelection {
        val onDeviceProbe = SystemSpeechBackend.probe(activity, preferOnDevice = true)
        val defaultProbe = SystemSpeechBackend.probe(activity, preferOnDevice = false)
        val hmsProbe = if (isHuaweiOrHonorDevice()) HuaweiHmsSpeechBackend.probe(activity) else null

        val selectedProbe = when {
            onDeviceProbe.available -> onDeviceProbe
            defaultProbe.available -> defaultProbe
            else -> defaultProbe
        }
        val diagnostics = buildList {
            add(
                "backend=${onDeviceProbe.backendId} available=${onDeviceProbe.available} " +
                    "service=${onDeviceProbe.selectedServiceInfo ?: "<none>"} " +
                    "visible=${onDeviceProbe.visibleServices.joinToString()}",
            )
            add(
                "backend=${defaultProbe.backendId} available=${defaultProbe.available} " +
                    "service=${defaultProbe.selectedServiceInfo ?: "<none>"} " +
                    "visible=${defaultProbe.visibleServices.joinToString()}",
            )
            if (hmsProbe != null) {
                add(
                    "backend=${hmsProbe.backendId} available=${hmsProbe.available} " +
                        "service=${hmsProbe.selectedServiceInfo ?: "<none>"} " +
                        "visible=${hmsProbe.visibleServices.joinToString()}",
                )
            }
        }

        val backend: SpeechBackend = SystemSpeechBackend(activity, selectedProbe)
        return SpeechBackendSelection(
            backend = backend,
            selectedProbe = selectedProbe,
            diagnostics = diagnostics,
            hmsCandidateProbe = hmsProbe,
        )
    }
}
