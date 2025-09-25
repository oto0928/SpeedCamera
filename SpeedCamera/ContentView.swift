import SwiftUI
import UIKit
import AVFoundation
import AudioToolbox

// MARK: - Enums
enum FlashMode: String, CaseIterable {
    case off = "off"
    case on = "on"
    case auto = "auto"
    
    var icon: String {
        switch self {
        case .off: return "bolt.slash.fill"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.a.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .off: return .gray
        case .on: return .yellow
        case .auto: return .orange
        }
    }
}

enum CameraFilter: String, CaseIterable {
    case none = "なし"
    case sepia = "セピア"
    case mono = "モノクロ"
    case vivid = "ビビッド"
    case vintage = "ヴィンテージ"
    case cool = "クール"
    
    var ciFilterName: String? {
        switch self {
        case .none: return nil
        case .sepia: return "CISepiaTone"
        case .mono: return "CIPhotoEffectMono"
        case .vivid: return "CIVibrance"
        case .vintage: return "CIPhotoEffectInstant"
        case .cool: return "CIPhotoEffectProcess"
        }
    }
}

enum PhotoResolution: String, CaseIterable {
    case low = "低画質"
    case medium = "標準"
    case high = "高画質"
    case ultra = "最高画質"
    
    var preset: AVCaptureSession.Preset {
        switch self {
        case .low: return .medium
        case .medium: return .high
        case .high: return .hd1920x1080
        case .ultra: return .hd4K3840x2160
        }
    }
}

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
    @State private var shutterSoundEnabled = true // シャッター音設定（デフォルト：オン）
    @State private var showSettings = false // 設定画面表示
    @State private var flashMode: FlashMode = .off // フラッシュモード
    @State private var zoomFactor: CGFloat = 1.0 // ズーム倍率
    @State private var showGridLines = false // グリッドライン表示
    @State private var currentFilter: CameraFilter = .none // フィルター
    @State private var burstModeEnabled = false // 連写モード
    @State private var showZoomSlider = false // ズームスライダー表示
    @State private var photoResolution: PhotoResolution = .high // 解像度設定
    @State private var showWatermark = false // 透かし表示
    @State private var burstPhotos: [UIImage] = [] // 連写写真
    @State private var showPhotoGallery = false // ギャラリー表示

    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.gray.opacity(0.8)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            // カメラプレビューは常に表示、透明化でhide対応
            ZStack {
                CameraView(
                    lastCapturedImage: $lastCapturedImage, 
                    shutterSoundEnabled: $shutterSoundEnabled,
                    flashMode: $flashMode,
                    zoomFactor: $zoomFactor,
                    currentFilter: $currentFilter,
                    photoResolution: $photoResolution
                )
                .frame(width: 380, height: 500)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(LinearGradient(
                            gradient: Gradient(colors: [Color.white.opacity(0.3), Color.clear]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ), lineWidth: 2)
                )
                .shadow(color: .white.opacity(0.2), radius: 15, x: 0, y: 8)
                
                // グリッドライン
                if showGridLines && !isHidden {
                    GridLinesView()
                        .frame(width: 380, height: 500)
                        .cornerRadius(20)
                }
                
                // 透かし・タイムスタンプ
                if showWatermark && !isHidden {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(Date().formatted(date: .abbreviated, time: .omitted))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 2)
                                Text(Date().formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 2)
                            }
                            .padding(.trailing, 15)
                            .padding(.bottom, 15)
                        }
                    }
                    .frame(width: 380, height: 500)
                }
            }
                .position(x: UIScreen.main.bounds.width / 2,
                          y: UIScreen.main.bounds.height * 0.44)
                .opacity(isHidden ? 0 : 1)
            .scaleEffect(isHidden ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: isHidden)

            // hide中は黒オーバーレイも可（好みで）
            if isHidden {
                Color.black
                    .edgesIgnoringSafeArea(.all)
            }

            // 上部UI
            if !isHidden {
                VStack(spacing: 15) {
                    // 第1行：基本機能
                    HStack(spacing: 20) {
                        // 設定ボタン
                        Button(action: { showSettings.toggle() }) {
                            Image(systemName: "gearshape.fill")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.white)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.3))
                                        .frame(width: 40, height: 40)
                                )
                        }
                        
                        // フラッシュボタン
                        Button(action: { 
                            let modes: [FlashMode] = [.off, .on, .auto]
                            if let currentIndex = modes.firstIndex(of: flashMode) {
                                flashMode = modes[(currentIndex + 1) % modes.count]
                            }
                        }) {
                            Image(systemName: flashMode.icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                                .foregroundColor(flashMode.color)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.3))
                                        .frame(width: 40, height: 40)
                                )
                        }
                        
                        if !isVideoMode {
                            Menu {
                                Button("3秒") { timerSeconds = 3 }
                                Button("5秒") { timerSeconds = 5 }
                                Button("10秒") { timerSeconds = 10 }
                                Button("なし") { timerSeconds = 0 }
                            } label: {
                                Image(systemName: "timer")
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.orange)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.3))
                                            .frame(width: 40, height: 40)
                                    )
                            }
                        }

                        Button(action: { 
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                                NotificationCenter.default.post(name: .switchCamera, object: nil)
                            }
                        }) {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.white)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.3))
                                        .frame(width: 40, height: 40)
                                )
                        }

                        Button(action: { 
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isVideoMode.toggle()
                            }
                        }) {
                            Image(systemName: isVideoMode ? "video.fill" : "camera.fill")
                                .resizable()
                                .frame(width: 24, height: 20)
                                .foregroundColor(isVideoMode ? .red : .white)
                                .background(
                                    Circle()
                                        .fill(isVideoMode ? Color.white.opacity(0.2) : Color.red.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.4))
                            .blur(radius: 10)
                    )
                    
                    // 第2行：追加機能
                    HStack(spacing: 20) {
                        // グリッドライン
                        Button(action: { showGridLines.toggle() }) {
                            Image(systemName: "grid")
                                .resizable()
                                .frame(width: 22, height: 22)
                                .foregroundColor(showGridLines ? .green : .gray)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.3))
                                        .frame(width: 36, height: 36)
                                )
                        }
                        
                        // フィルター
                        Menu {
                            ForEach(CameraFilter.allCases, id: \.self) { filter in
                                Button(filter.rawValue) { 
                                    currentFilter = filter 
                                }
                            }
                        } label: {
                            Image(systemName: "camera.filters")
                                .resizable()
                                .frame(width: 22, height: 22)
                                .foregroundColor(currentFilter == .none ? .gray : .purple)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.3))
                                        .frame(width: 36, height: 36)
                                )
                        }
                        
                        // 連写モード
                        Button(action: { burstModeEnabled.toggle() }) {
                            Image(systemName: "burst")
                                .resizable()
                                .frame(width: 22, height: 22)
                                .foregroundColor(burstModeEnabled ? .blue : .gray)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.3))
                                        .frame(width: 36, height: 36)
                                )
                        }
                        
                        // 透かし
                        Button(action: { showWatermark.toggle() }) {
                            Image(systemName: "textformat")
                                .resizable()
                                .frame(width: 22, height: 22)
                                .foregroundColor(showWatermark ? .cyan : .gray)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.3))
                                        .frame(width: 36, height: 36)
                                )
                        }
                        
                        // ギャラリー
                        Button(action: { showPhotoGallery.toggle() }) {
                            Image(systemName: "photo.on.rectangle")
                                .resizable()
                                .frame(width: 22, height: 22)
                                .foregroundColor(.white)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.3))
                                        .frame(width: 36, height: 36)
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.3))
                            .blur(radius: 8)
                    )

                    Spacer()
                }
                .padding(.top, 50)
            }

            // 録画表示
            if isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 14, height: 14)
                        .opacity((recordingTime % 2 == 0 ? 1 : 0.3) * (isHidden ? 0 : 1)) // hide時は透明
                        .animation(.easeInOut(duration: 0.5), value: recordingTime % 2)
                    
                    Text("REC \(formatTime(recordingTime))")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                        .opacity(isHidden ? 0 : 1) // hide時は透明
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.7))
                        .overlay(
                            Capsule()
                                .stroke(Color.red.opacity(0.5), lineWidth: 1)
                        )
                )
                .padding(.leading, 20)
                .padding(.top, 35)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .opacity(isHidden ? 0 : 1)
                .animation(.easeInOut(duration: 0.3), value: isHidden)
            }

            // シャッターボタン
            if !isHidden {
                VStack {
                    Spacer()
                    Group {
                        if isVideoMode {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
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
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                gradient: Gradient(colors: [
                                                    isRecording ? Color.white.opacity(0.8) : Color.red.opacity(0.8),
                                                    isRecording ? Color.gray : Color.red
                                                ]),
                                                center: .center,
                                                startRadius: 5,
                                                endRadius: 45
                                            )
                                        )
                                        .frame(width: 90, height: 90)
                                        .shadow(color: isRecording ? .white.opacity(0.5) : .red.opacity(0.7), radius: 15, x: 0, y: 8)
                                    
                                    Image(systemName: isRecording ? "stop.fill" : "record.circle")
                                    .resizable()
                                        .frame(width: isRecording ? 30 : 50, height: isRecording ? 30 : 50)
                                        .foregroundColor(isRecording ? .black : .white)
                                }
                                .scaleEffect(isRecording ? 0.9 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: isRecording)
                            }
                        } else {
                            Button(action: { 
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                                    if burstModeEnabled {
                                        startBurstCapture()
                                    } else {
                                        startTimer(seconds: timerSeconds)
                                    }
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                gradient: Gradient(colors: [
                                                    burstModeEnabled ? Color.blue.opacity(0.9) : Color.white.opacity(0.9), 
                                                    burstModeEnabled ? Color.blue : Color.gray.opacity(0.7)
                                                ]),
                                                center: .center,
                                                startRadius: 5,
                                                endRadius: 45
                                            )
                                        )
                                        .frame(width: 90, height: 90)
                                        .shadow(color: burstModeEnabled ? .blue.opacity(0.6) : .white.opacity(0.6), radius: 15, x: 0, y: 8)
                                    
                                    Image(systemName: burstModeEnabled ? "burst.fill" : "camera.fill")
                                    .resizable()
                                        .frame(width: 40, height: 32)
                                        .foregroundColor(burstModeEnabled ? .white : .black)
                                }
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
                        Button(action: {
                            // 写真アプリを開く（実装可能であれば）
                        }) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.white.opacity(0.4), lineWidth: 2)
                                )
                                .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
                                .scaleEffect(1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: image)
                        }
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
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            isHidden.toggle()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: isHidden ? "eye.fill" : "eye.slash.fill")
                                .font(.system(size: 16, weight: .semibold))
                        Text(isHidden ? "Show" : "Hide")
                                .font(.system(size: 16, weight: .semibold))
                        }
                            .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.6))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding()
                }
            }
            
            // ズームスライダー
            if !isHidden && zoomFactor > 1.0 {
                VStack {
                    Spacer()
                    HStack {
                        Text("1x")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                        
                        Slider(value: $zoomFactor, in: 1.0...5.0, step: 0.1)
                            .accentColor(.white)
                            .frame(width: 150)
                        
                        Text("5x")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.6))
                    )
                    .padding(.bottom, 120)
                }
            }
            
            // 設定画面
            if showSettings {
                SettingsView(
                    shutterSoundEnabled: $shutterSoundEnabled,
                    showSettings: $showSettings,
                    showGridLines: $showGridLines,
                    currentFilter: $currentFilter,
                    photoResolution: $photoResolution,
                    showWatermark: $showWatermark
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showSettings)
            }
            
            // ギャラリー画面
            if showPhotoGallery {
                PhotoGalleryView(
                    burstPhotos: $burstPhotos,
                    showPhotoGallery: $showPhotoGallery
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showPhotoGallery)
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
    
    // MARK: - 連写機能
    func startBurstCapture() {
        burstPhotos.removeAll()
        var captureCount = 0
        let maxCaptures = 10
        
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
            if captureCount < maxCaptures {
                NotificationCenter.default.post(name: .capturePhoto, object: nil)
                captureCount += 1
            } else {
                timer.invalidate()
            }
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Binding var shutterSoundEnabled: Bool
    @Binding var showSettings: Bool
    @Binding var showGridLines: Bool
    @Binding var currentFilter: CameraFilter
    @Binding var photoResolution: PhotoResolution
    @Binding var showWatermark: Bool
    
    var body: some View {
        ZStack {
            // 背景オーバーレイ
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    showSettings = false
                }
            
            VStack(spacing: 0) {
                Spacer()
                
                // 設定パネル
                VStack(spacing: 25) {
                    // ヘッダー
                    HStack {
                        Text("設定")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: { showSettings = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 25)
                    .padding(.top, 25)
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                        .padding(.horizontal, 25)
                    
                    // 設定項目
                    VStack(spacing: 20) {
                        // シャッター音設定
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("シャッター音")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("オフにすると無音で撮影できます（デフォルト：オン）")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $shutterSoundEnabled)
                                .toggleStyle(CustomToggleStyle())
                        }
                        .padding(.horizontal, 25)
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.horizontal, 25)
                        
                        // グリッドライン設定
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("グリッドライン")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("三分割法のガイドラインを表示")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $showGridLines)
                                .toggleStyle(CustomToggleStyle())
                        }
                        .padding(.horizontal, 25)
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.horizontal, 25)
                        
                        // 透かし設定
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("タイムスタンプ")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("撮影日時を写真に表示")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $showWatermark)
                                .toggleStyle(CustomToggleStyle())
                        }
                        .padding(.horizontal, 25)
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.horizontal, 25)
                        
                        // 解像度設定
                        VStack(alignment: .leading, spacing: 10) {
                            Text("画質設定")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 25)
                            
                            HStack(spacing: 15) {
                                ForEach(PhotoResolution.allCases, id: \.self) { resolution in
                                    Button(action: { photoResolution = resolution }) {
                                        Text(resolution.rawValue)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(photoResolution == resolution ? .black : .white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(photoResolution == resolution ? Color.white : Color.clear)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                                    )
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal, 25)
                        }
                        
                        // 注意事項
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 16))
                                
                                Text("注意事項")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.blue)
                                
                                Spacer()
                            }
                            
                            Text("• アプリはデフォルトでシャッター音が鳴るように設定されています")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.leading)
                            
                            Text("• 無音撮影は適切な場所でのみ使用し、プライバシーを尊重してください")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.leading)
                            
                            Text("• 一部の地域では法的要件により、設定に関わらず音が鳴る場合があります")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.horizontal, 25)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                        )
                        .padding(.horizontal, 25)
                    }
                    
                    Spacer(minLength: 30)
                }
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.black.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 50)
            }
        }
    }
}

// MARK: - Custom Toggle Style
struct CustomToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(configuration.isOn ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 50, height: 30)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 26, height: 26)
                        .offset(x: configuration.isOn ? 10 : -10)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isOn)
                )
                .onTapGesture {
                    configuration.isOn.toggle()
                }
        }
    }
}

// MARK: - Grid Lines View
struct GridLinesView: View {
    var body: some View {
        ZStack {
            // 縦線
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(height: 1)
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(height: 1)
                Spacer()
            }
            
            // 横線
            HStack {
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 1)
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 1)
                Spacer()
            }
        }
    }
}

// MARK: - Photo Gallery View
struct PhotoGalleryView: View {
    @Binding var burstPhotos: [UIImage]
    @Binding var showPhotoGallery: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                // ヘッダー
                HStack {
                    Text("ギャラリー")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: { showPhotoGallery = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 25)
                .padding(.top, 50)
                
                if burstPhotos.isEmpty {
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("撮影した写真がここに表示されます")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3), spacing: 5) {
                            ForEach(0..<burstPhotos.count, id: \.self) { index in
                                Image(uiImage: burstPhotos[index])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 110, height: 110)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                }
            }
        }
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
    @Binding var shutterSoundEnabled: Bool
    @Binding var flashMode: FlashMode
    @Binding var zoomFactor: CGFloat
    @Binding var currentFilter: CameraFilter
    @Binding var photoResolution: PhotoResolution

    func makeUIViewController(context: Context) -> CameraViewController {
        let cameraVC = CameraViewController()
        cameraVC.lastCapturedImage = $lastCapturedImage
        cameraVC.shutterSoundEnabled = $shutterSoundEnabled
        cameraVC.flashMode = $flashMode
        cameraVC.zoomFactor = $zoomFactor
        cameraVC.currentFilter = $currentFilter
        cameraVC.photoResolution = $photoResolution
        return cameraVC
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        uiViewController.shutterSoundEnabled = $shutterSoundEnabled
        uiViewController.flashMode = $flashMode
        uiViewController.zoomFactor = $zoomFactor
        uiViewController.currentFilter = $currentFilter
        uiViewController.photoResolution = $photoResolution
    }
}

// MARK: - CameraViewController
class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureFileOutputRecordingDelegate {

    var captureSession: AVCaptureSession!
    var videoOutput: AVCaptureVideoDataOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var currentCamera: AVCaptureDevice.Position = .back

    var movieOutput: AVCaptureMovieFileOutput?

    var lastCapturedImage: Binding<UIImage?>?
    var shutterSoundEnabled: Binding<Bool>?
    var flashMode: Binding<FlashMode>?
    var zoomFactor: Binding<CGFloat>?
    var currentFilter: Binding<CameraFilter>?
    var photoResolution: Binding<PhotoResolution>?
    private var capturedImage: UIImage?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupAudioSession()
        setupCamera(position: currentCamera)

        NotificationCenter.default.addObserver(self, selector: #selector(capturePhoto), name: .capturePhoto, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(switchCamera), name: .switchCamera, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(startRecordingNotification), name: .startRecording, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stopRecordingNotification), name: .stopRecording, object: nil)
    }
    
    // MARK: オーディオセッション初期化
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("オーディオセッション初期化エラー: \(error)")
        }
    }

    // MARK: カメラセットアップ
    func setupCamera(position: AVCaptureDevice.Position) {
        captureSession?.stopRunning()
        previewLayer?.removeFromSuperlayer()

        captureSession = AVCaptureSession()
        
        // 解像度設定
        if let resolution = photoResolution?.wrappedValue {
            captureSession.sessionPreset = resolution.preset
        } else {
            captureSession.sessionPreset = .high
        }

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: camera) else { return }

        // カメラ設定（フラッシュ、ズーム）
        do {
            try camera.lockForConfiguration()
            
            // フラッシュ設定
            if camera.hasFlash {
                switch flashMode?.wrappedValue {
                case .off:
                    camera.flashMode = .off
                case .on:
                    camera.flashMode = .on
                case .auto:
                    camera.flashMode = .auto
                default:
                    camera.flashMode = .off
                }
            }
            
            // ズーム設定
            if let zoom = zoomFactor?.wrappedValue {
                let maxZoom = min(camera.activeFormat.videoMaxZoomFactor, 5.0)
                camera.videoZoomFactor = min(max(zoom, 1.0), maxZoom)
            }
            
            camera.unlockForConfiguration()
        } catch {
            print("カメラ設定エラー: \(error)")
        }

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
            // シャッター音の制御
            if shutterSoundEnabled?.wrappedValue == true {
                // シャッター音を鳴らす
                playShutterSound()
            } else {
                // 無音撮影のためにオーディオセッションを一時的に無効化
                disableShutterSound()
            }
            
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
            lastCapturedImage?.wrappedValue = image
        }
    }
    
    // MARK: シャッター音制御
    private func playShutterSound() {
        // 通常のオーディオセッションに戻してシャッター音を有効化
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("オーディオセッション設定エラー: \(error)")
        }
        
        // システムのシャッター音を再生
        AudioServicesPlaySystemSound(1108)
    }
    
    private func disableShutterSound() {
        // 無音撮影のためにオーディオセッションを無音モードに設定
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("オーディオセッション設定エラー: \(error)")
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
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // フィルター適用
        if let filter = currentFilter?.wrappedValue, let filterName = filter.ciFilterName {
            if let ciFilter = CIFilter(name: filterName) {
                ciFilter.setValue(ciImage, forKey: kCIInputImageKey)
                
                // フィルター固有の設定
                switch filter {
                case .sepia:
                    ciFilter.setValue(0.8, forKey: kCIInputIntensityKey)
                case .vivid:
                    ciFilter.setValue(0.5, forKey: kCIInputAmountKey)
                default:
                    break
                }
                
                if let outputImage = ciFilter.outputImage {
                    ciImage = outputImage
                }
            }
        }
        
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

