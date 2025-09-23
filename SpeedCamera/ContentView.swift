import SwiftUI
import UIKit
import AVFoundation

// MARK: - SwiftUI App Entry
@main
struct SilentCameraApp: App {
    var body: some Scene {
        WindowGroup {
            StartView()
        }
    }
}

// MARK: - StartView
struct StartView: View {
    @State private var isStarted = false

    var body: some View {
        ZStack {
            if isStarted {
                ContentView()
            } else {
                Color.white
                    .edgesIgnoringSafeArea(.all)

                Image("Start")
                    .resizable()
                    .scaledToFit()
                    .frame(width: UIScreen.main.bounds.width * 1.05,
                           height: UIScreen.main.bounds.height * 1.05)
                    .position(x: UIScreen.main.bounds.width / 2,
                              y: UIScreen.main.bounds.height * 0.45)
                    .onTapGesture {
                        withAnimation {
                            isStarted = true
                        }
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation {
                                isStarted = true
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - ContentView
struct ContentView: View {
    @State private var lastCapturedImage: UIImage?
    @State private var timerSeconds: Int = 0
    @State private var countdown: Int = 0
    @State private var isVideoMode = false
    @State private var isRecording = false
    @State private var recordingTime = 0
    @State private var recordingTimer: Timer? = nil
    @State private var isHidden = false // Hideボタン用

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            // カメラプレビューは常に表示、透明化でhide対応
            CameraView(lastCapturedImage: $lastCapturedImage)
                .frame(width: 380, height: 500)
                .cornerRadius(8)
                .shadow(color: .white.opacity(0.1), radius: 10, x: 0, y: 5)
                .position(x: UIScreen.main.bounds.width / 2,
                          y: UIScreen.main.bounds.height * 0.44)
                .opacity(isHidden ? 0 : 1)

            // hide中は黒オーバーレイも可（好みで）
            if isHidden {
                Color.black
                    .edgesIgnoringSafeArea(.all)
            }

            // 上部UI
            if !isHidden {
                VStack {
                    HStack(spacing: 30) {
                        if !isVideoMode {
                            Menu {
                                Button("3秒") { timerSeconds = 3 }
                                Button("5秒") { timerSeconds = 5 }
                                Button("10秒") { timerSeconds = 10 }
                                Button("なし") { timerSeconds = 0 }
                            } label: {
                                Image(systemName: "timer")
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(.orange)
                            }
                        }

                        Button(action: { NotificationCenter.default.post(name: .switchCamera, object: nil) }) {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.white)
                        }

                        Button(action: { isVideoMode.toggle() }) {
                            Image(systemName: isVideoMode ? "video.fill" : "camera.fill")
                                .resizable()
                                .frame(width: 30, height: 25)
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(12)
                    .padding(.top, 50)

                    Spacer()
                }
            }

            // 録画表示
            if isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .opacity((recordingTime % 2 == 0 ? 1 : 0.3) * (isHidden ? 0 : 1)) // hide時は透明
                    Text("REC \(formatTime(recordingTime))")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                        .opacity(isHidden ? 0 : 1) // hide時は透明
                }
                .padding(.leading, 20)
                .padding(.top, 35)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            }

            // シャッターボタン
            if !isHidden {
                VStack {
                    Spacer()
                    Group {
                        if isVideoMode {
                            Button(action: {
                                if isRecording {
                                    NotificationCenter.default.post(name: .stopRecording, object: nil)
                                    isRecording = false
                                    recordingTimer?.invalidate()
                                    recordingTimer = nil
                                    recordingTime = 0
                                } else {
                                    NotificationCenter.default.post(name: .startRecording, object: nil)
                                    isRecording = true
                                    startRecordingTimer()
                                }
                            }) {
                                Image(systemName: isRecording ? "stop.circle.fill" : "record.circle.fill")
                                    .resizable()
                                    .frame(width: 80, height: 80)
                                    .foregroundColor(isRecording ? .white : .red)
                                    .shadow(color: .red.opacity(0.7), radius: 10, x: 0, y: 5)
                            }
                        } else {
                            Button(action: { startTimer(seconds: timerSeconds) }) {
                                Image(systemName: "camera.circle.fill")
                                    .resizable()
                                    .frame(width: 80, height: 80)
                                    .foregroundColor(.white)
                                    .shadow(color: .white.opacity(0.7), radius: 10, x: 0, y: 5)
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }

            // 左下サムネイル
            if let image = lastCapturedImage, !isHidden {
                VStack {
                    Spacer()
                    HStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: .white.opacity(0.3), radius: 8)
                            .padding(.leading, 20)
                        Spacer()
                    }
                    .padding(.bottom, 20)
                }
            }

            // カウントダウン
            if countdown > 0 && !isHidden {
                Text("\(countdown)")
                    .font(.system(size: 100, weight: .bold, design: .monospaced))
                    .foregroundColor(.red)
                    .shadow(radius: 10)
            }

            // Hideボタン（常に表示）
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation {
                            isHidden.toggle()
                        }
                    }) {
                        Text(isHidden ? "Show" : "Hide")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(10)
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: - 写真タイマー
    func startTimer(seconds: Int) {
        if seconds == 0 {
            NotificationCenter.default.post(name: .capturePhoto, object: nil)
            return
        }
        countdown = seconds
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            DispatchQueue.main.async {
                countdown -= 1
                if countdown <= 0 {
                    timer.invalidate()
                    NotificationCenter.default.post(name: .capturePhoto, object: nil)
                }
            }
        }
    }

    // MARK: - 録画タイマー
    func startRecordingTimer() {
        recordingTime = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            recordingTime += 1
            if recordingTime >= 7200 {
                timer.invalidate()
                recordingTimer = nil
                NotificationCenter.default.post(name: .stopRecording, object: nil)
                isRecording = false
                recordingTime = 0
            }
        }
    }

    func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
}
// MARK: - Notification Names
extension Notification.Name {
    static let capturePhoto = Notification.Name("capturePhoto")
    static let switchCamera = Notification.Name("switchCamera")
    static let startRecording = Notification.Name("startRecording")
    static let stopRecording = Notification.Name("stopRecording")
}

// MARK: - CameraView
struct CameraView: UIViewControllerRepresentable {
    @Binding var lastCapturedImage: UIImage?

    func makeUIViewController(context: Context) -> CameraViewController {
        let cameraVC = CameraViewController()
        cameraVC.lastCapturedImage = $lastCapturedImage
        return cameraVC
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

// MARK: - CameraViewController
class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureFileOutputRecordingDelegate {

    var captureSession: AVCaptureSession!
    var videoOutput: AVCaptureVideoDataOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var currentCamera: AVCaptureDevice.Position = .back

    var movieOutput: AVCaptureMovieFileOutput?

    var lastCapturedImage: Binding<UIImage?>?
    private var capturedImage: UIImage?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera(position: currentCamera)

        NotificationCenter.default.addObserver(self, selector: #selector(capturePhoto), name: .capturePhoto, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(switchCamera), name: .switchCamera, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(startRecordingNotification), name: .startRecording, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stopRecordingNotification), name: .stopRecording, object: nil)
    }

    // MARK: カメラセットアップ
    func setupCamera(position: AVCaptureDevice.Position) {
        captureSession?.stopRunning()
        previewLayer?.removeFromSuperlayer()

        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: camera) else { return }

        // 入力設定
        if let currentInputs = captureSession.inputs as? [AVCaptureInput] {
            for input in currentInputs { captureSession.removeInput(input) }
        }
        captureSession.addInput(input)

        // 写真用
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(videoOutput)

        // 動画用
        movieOutput = AVCaptureMovieFileOutput()
        if let movieOutput = movieOutput {
            captureSession.addOutput(movieOutput)
        }

        // プレビュー
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        captureSession.startRunning()
    }

    // MARK: 撮影
    @objc func capturePhoto() {
        if let image = capturedImage {
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
            lastCapturedImage?.wrappedValue = image
        }
    }

    // MARK: カメラ切替
    @objc func switchCamera() {
        currentCamera = (currentCamera == .back) ? .front : .back
        setupCamera(position: currentCamera)
    }

    // MARK: 録画開始/停止
    @objc func startRecordingNotification() {
        startRecording()
    }

    @objc func stopRecordingNotification() {
        stopRecording()
    }

    func startRecording() {
        guard let movieOutput = movieOutput, !movieOutput.isRecording else { return }
        let outputPath = NSTemporaryDirectory() + UUID().uuidString + ".mov"
        let outputURL = URL(fileURLWithPath: outputPath)
        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
    }

    func stopRecording() {
        movieOutput?.stopRecording()
    }

    // MARK: フレームをUIImageに変換
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            capturedImage = UIImage(cgImage: cgImage, scale: UIScreen.main.scale,
                                    orientation: currentCamera == .back ? .right : .leftMirrored)
        }
    }

    // MARK: 録画完了
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        if let error = error {
            print("録画失敗: \(error.localizedDescription)")
            return
        }
        UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.path, nil, nil, nil)
        print("動画を保存しました: \(outputFileURL)")
    }

    // MARK: 保存完了
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            print("保存エラー: \(error.localizedDescription)")
        } else {
            print("写真を保存しました（無音）")
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
}

