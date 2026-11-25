import AVFoundation
import SwiftUI
import UIKit

/// Configure one mission in an alarm's chain, including registering the
/// photo or barcode that the mission will ask for in the morning.
struct MissionEditorView: View {
    @Binding var mission: MissionSettings
    @State private var showCamera = false
    @State private var showScanner = false
    @State private var manualCode = ""

    var body: some View {
        Form {
            Section {
                Picker("Mission", selection: Binding(
                    get: { mission.kind },
                    set: { kind in
                        mission.kind = kind
                        mission.rounds = kind.defaultRounds
                    })) {
                    ForEach(MissionKind.selectable) { kind in
                        Label(kind.title, systemImage: kind.symbolName).tag(kind)
                    }
                }
                Text(mission.kind.blurb)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            if mission.kind.usesDifficulty {
                Section("Difficulty") {
                    Picker("Difficulty", selection: $mission.difficulty) {
                        ForEach(MathDifficulty.allCases) { d in Text(d.title).tag(d) }
                    }
                    .pickerStyle(.segmented)
                }
            }

            if mission.kind.roundsRange.count > 1 {
                Section("Amount") {
                    Stepper(value: $mission.rounds, in: mission.kind.roundsRange, step: mission.kind.roundsStep) {
                        Text(mission.kind.roundsLabel(mission.rounds))
                    }
                }
            }

            if mission.kind == .photo {
                Section {
                    if let image = PhotoStore.load(mission.photoFile) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Button {
                        showCamera = true
                    } label: {
                        Label(mission.photoFile == nil ? "Take the reference photo" : "Retake reference photo",
                              systemImage: "camera")
                    }
                    .disabled(!CameraPicker.isAvailable)
                } header: {
                    Text("Reference photo")
                } footer: {
                    Text(CameraPicker.isAvailable
                         ? "Photograph a spot away from your bed, like the bathroom sink. In the morning you must take a matching photo of the same spot."
                         : "This device has no camera, so the photo mission can't be set up here.")
                }
            }

            if mission.kind == .barcode {
                Section {
                    if let code = mission.barcodePayload, !code.isEmpty {
                        LabeledContent("Registered", value: code)
                    }
                    Button {
                        showScanner = true
                    } label: {
                        Label("Scan a barcode or QR code", systemImage: "barcode.viewfinder")
                    }
                    .disabled(!BarcodeScannerView.isAvailable)
                    HStack {
                        TextField("…or type the code", text: $manualCode)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("Use") {
                            mission.barcodePayload = manualCode.trimmingCharacters(in: .whitespacesAndNewlines)
                            manualCode = ""
                        }
                        .disabled(manualCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } header: {
                    Text("Registered code")
                } footer: {
                    Text("Scan something that lives in another room, like a toothpaste tube or a coffee bag. In the morning you must scan the same code.")
                }
            }
        }
        .navigationTitle(mission.kind.title)
        .sheet(isPresented: $showCamera) {
            CameraPicker(onImage: { image in
                if let name = PhotoStore.save(image) { mission.photoFile = name }
            }, onClose: { showCamera = false })
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showScanner) {
            BarcodeScannerSheet(title: "Scan the code to register") { code in
                mission.barcodePayload = code
            }
        }
    }
}

/// System camera for reference and mission photos.
struct CameraPicker: UIViewControllerRepresentable {
    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    let onImage: (UIImage) -> Void
    let onClose: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            parent.onClose()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onClose()
        }
    }
}

/// Full-screen barcode / QR scanner with a close button.
struct BarcodeScannerSheet: View {
    let title: String
    let onCode: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                BarcodeScannerView { code in
                    onCode(code)
                    dismiss()
                }
                .ignoresSafeArea()
                Text(title)
                    .font(.headline)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 40)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
    }
}

/// Camera preview that reports the first barcode or QR code it sees.
struct BarcodeScannerView: UIViewControllerRepresentable {
    static var isAvailable: Bool { AVCaptureDevice.default(for: .video) != nil }

    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerController {
        let c = ScannerController()
        c.onCode = onCode
        return c
    }

    func updateUIViewController(_ controller: ScannerController, context: Context) {}

    final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var onCode: ((String) -> Void)?
        private let session = AVCaptureSession()
        private var preview: AVCaptureVideoPreviewLayer?
        private var reported = false

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async { if granted { self?.configure() } }
            }
        }

        private func configure() {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else { return }
            session.addInput(input)
            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            let wanted: [AVMetadataObject.ObjectType] = [.qr, .ean13, .ean8, .upce, .code128, .code39, .code93,
                                                         .pdf417, .dataMatrix, .aztec, .itf14, .interleaved2of5]
            output.metadataObjectTypes = wanted.filter { output.availableMetadataObjectTypes.contains($0) }
            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            layer.frame = view.bounds
            view.layer.addSublayer(layer)
            preview = layer
            DispatchQueue.global(qos: .userInitiated).async { [session] in session.startRunning() }
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            preview?.frame = view.bounds
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            let s = session
            DispatchQueue.global(qos: .userInitiated).async { s.stopRunning() }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard !reported,
                  let code = metadataObjects.compactMap({ ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }).first,
                  !code.isEmpty else { return }
            reported = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onCode?(code)
        }
    }
}
