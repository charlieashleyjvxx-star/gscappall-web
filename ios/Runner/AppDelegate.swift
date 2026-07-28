import AVFoundation
import Flutter
import Speech
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var speechBridge: NativeSpeechBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NativeSpeechBridge")
    speechBridge = NativeSpeechBridge(messenger: registrar.messenger())
  }
}

private final class NativeSpeechBridge: NSObject, FlutterStreamHandler {
  private let methodChannel: FlutterMethodChannel
  private let eventChannel: FlutterEventChannel
  private let audioEngine = AVAudioEngine()
  private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh_CN"))

  private var eventSink: FlutterEventSink?
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

  init(messenger: FlutterBinaryMessenger) {
    methodChannel = FlutterMethodChannel(
      name: "gscappall/speech/methods",
      binaryMessenger: messenger
    )
    eventChannel = FlutterEventChannel(
      name: "gscappall/speech/events",
      binaryMessenger: messenger
    )

    super.init()

    eventChannel.setStreamHandler(self)
    methodChannel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      initializeRecognizer(result: result)
    case "startListening":
      startListening(result: result)
    case "stopListening":
      stopListening(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func initializeRecognizer(result: @escaping FlutterResult) {
    guard speechRecognizer != nil else {
      result([
        "supported": false,
        "authorized": false,
        "message": "当前设备不支持 iOS 原生语音识别。",
      ])
      return
    }

    SFSpeechRecognizer.requestAuthorization { [weak self] status in
      guard let self = self else { return }
      self.authorizationStatus = status

      let message: String
      switch status {
      case .authorized:
        message = "iOS 原生语音识别可用。"
      case .denied:
        message = "语音识别权限被拒绝，请到系统设置中开启。"
      case .restricted:
        message = "当前设备受系统限制，无法使用语音识别。"
      case .notDetermined:
        message = "语音识别权限尚未确定。"
      @unknown default:
        message = "语音识别权限状态未知。"
      }

      DispatchQueue.main.async {
        result([
          "supported": true,
          "authorized": status == .authorized,
          "message": message,
        ])
      }
    }
  }

  private func startListening(result: @escaping FlutterResult) {
    guard speechRecognizer != nil else {
      result(
        FlutterError(
          code: "speech_unavailable",
          message: "当前设备不支持 iOS 原生语音识别。",
          details: nil
        )
      )
      return
    }

    guard authorizationStatus == .authorized else {
      result(
        FlutterError(
          code: "speech_not_authorized",
          message: "请先授予语音识别权限。",
          details: nil
        )
      )
      return
    }

    do {
      teardownRecognition()

      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
      try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

      let request = SFSpeechAudioBufferRecognitionRequest()
      request.shouldReportPartialResults = true
      recognitionRequest = request

      let inputNode = audioEngine.inputNode
      let recordingFormat = inputNode.outputFormat(forBus: 0)
      inputNode.removeTap(onBus: 0)
      inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
        self?.recognitionRequest?.append(buffer)
      }

      recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] recognitionResult, error in
        guard let self = self else { return }

        if let recognitionResult {
          self.eventSink?([
            "text": recognitionResult.bestTranscription.formattedString,
            "isFinal": recognitionResult.isFinal,
          ])
        }

        if let error {
          self.eventSink?(
            FlutterError(
              code: "speech_error",
              message: error.localizedDescription,
              details: nil
            )
          )
          self.teardownRecognition()
          return
        }

        if recognitionResult?.isFinal == true {
          self.teardownRecognition()
        }
      }

      audioEngine.prepare()
      try audioEngine.start()
      result(nil)
    } catch {
      result(
        FlutterError(
          code: "speech_start_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private func stopListening(result: @escaping FlutterResult) {
    teardownRecognition()
    result(nil)
  }

  private func teardownRecognition() {
    if audioEngine.isRunning {
      audioEngine.stop()
    }

    audioEngine.inputNode.removeTap(onBus: 0)
    recognitionRequest?.endAudio()
    recognitionTask?.cancel()
    recognitionTask = nil
    recognitionRequest = nil

    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
}
