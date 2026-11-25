import SwiftUI
import UIKit

struct RingingView: View {
    @EnvironmentObject private var engine: AlarmEngine
    let session: RingingSession
    @State private var chain: MissionChain?

    var body: some View {
        ZStack {
            Theme.ringingGradient.ignoresSafeArea()
            if let chain, let current = chain.current {
                MissionView(session: current, stepText: chain.stepText,
                            onUpdate: { updated in advance(updated) },
                            onBack: { self.chain = nil })
                    .id(current.settings.id)
                    .padding()
            } else {
                ringing
            }
        }
        .foregroundColor(.white)
        .onChange(of: chain != nil) { active in
            AudioService.shared.duck(active)
        }
        .interactiveDismissDisabled()
    }

    private func advance(_ updated: MissionSession) {
        guard var c = chain else { return }
        c.update(updated)
        if c.isComplete {
            chain = nil
            engine.dismiss()
        } else {
            chain = c
        }
    }

    private var missions: [MissionSettings] { session.alarm.activeMissions }

    private var ringing: some View {
        VStack(spacing: 18) {
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(context.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 72, weight: .thin, design: .rounded))
                    .monospacedDigit()
            }
            Text(session.alarm.displayLabel)
                .font(.title3.weight(.medium))
            CryingBaby(emoji: session.voice.emoji)
                .padding(.vertical, 10)
            Text("\(session.voice.displayName) baby is crying!")
                .font(.title2.weight(.bold))
            if session.alarm.cryEscalation {
                Text("Wait too long and a fussier baby takes over.")
                    .font(.footnote)
                    .opacity(0.8)
            }
            if session.snoozeCount > 0 {
                Text("Snoozed \(session.snoozeCount)×")
                    .font(.footnote)
                    .opacity(0.8)
            }
            Spacer()
            VStack(spacing: 12) {
                if session.canSnooze {
                    PillButton(title: "Snooze \(session.alarm.snooze.minutes) min", systemImage: "zzz", filled: false) {
                        engine.snooze()
                    }
                }
                if let left = session.snoozesLeftText {
                    Text(left).font(.footnote).opacity(0.8)
                }
                PillButton(title: missions.isEmpty
                           ? "I'm up – calm the baby"
                           : "Calm the baby (\(missions.map { $0.kind.title.lowercased() }.joined(separator: " → ")))",
                           systemImage: "sun.max.fill") {
                    if missions.isEmpty {
                        engine.dismiss()
                    } else {
                        chain = MissionChain(missions: missions)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

/// One mission of the chain. Reports every change through `onUpdate`.
struct MissionView: View {
    @State private var session: MissionSession
    let stepText: String
    let onUpdate: (MissionSession) -> Void
    let onBack: () -> Void

    @State private var answer = ""
    @State private var wrong = false
    @State private var memoryTaps: Set<Int> = []
    @State private var memoryRevealed = true
    @State private var status = ""
    @State private var checkingPhoto = false
    @State private var showCamera = false
    @State private var showScanner = false
    @FocusState private var focused: Bool
    @StateObject private var motion = MotionMonitor()

    init(session: MissionSession, stepText: String, onUpdate: @escaping (MissionSession) -> Void, onBack: @escaping () -> Void) {
        _session = State(initialValue: session)
        self.stepText = stepText
        self.onUpdate = onUpdate
        self.onBack = onBack
    }

    private var kind: MissionKind { session.settings.kind }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button(action: onBack) {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                Spacer()
                if !stepText.isEmpty {
                    Text(stepText).font(.subheadline.weight(.semibold))
                    Spacer()
                }
                Text("\(session.completed) / \(session.required)")
                    .monospacedDigit()
                    .font(.headline)
            }
            ProgressView(value: session.progress)
                .tint(.white)
            Spacer(minLength: 0)
            content
            if !status.isEmpty {
                Text(status).font(.footnote).multilineTextAlignment(.center).opacity(0.9)
            }
            Spacer(minLength: 0)
        }
        .onAppear(perform: start)
        .onDisappear { motion.stop() }
        .sheet(isPresented: $showCamera) {
            CameraPicker(onImage: checkPhoto, onClose: { showCamera = false })
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showScanner) {
            BarcodeScannerSheet(title: "Scan your registered code") { code in
                if session.submit(code) {
                    onUpdate(session)
                } else {
                    status = "That's a different code. Find the one you registered."
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

    private func start() {
        focused = true
        switch kind {
        case .shake:
            if !MotionMonitor.motionAvailable { status = "No motion sensor here, so tap the baby instead." }
            motion.startShake { record(1) }
        case .squat:
            if !MotionMonitor.motionAvailable { status = "No motion sensor here, so tap the baby instead." }
            motion.startSquats { record(1) }
        case .steps:
            if !MotionMonitor.stepsAvailable { status = "Step counting isn't available here, so tap the baby instead." }
            motion.startSteps { steps in
                session.setProgress(steps)
                onUpdate(session)
            }
        case .memory:
            revealMemory()
        default:
            break
        }
    }

    private func record(_ n: Int) {
        session.registerAction(count: n)
        onUpdate(session)
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .math:
            VStack(spacing: 20) {
                Text("Solve to calm the baby").font(.headline)
                Text("\(session.problem?.prompt ?? "") = ?")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .offset(x: wrong ? -10 : 0)
                TextField("Answer", text: $answer)
                    .keyboardType(.numberPad)
                    .font(.title.monospacedDigit())
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .focused($focused)
                PillButton(title: "Submit", systemImage: "checkmark") { submitText() }
            }
        case .typing:
            VStack(spacing: 20) {
                Text("Type this sentence exactly").font(.headline)
                Text(session.phrase ?? "")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                TextField("Start typing…", text: $answer, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .focused($focused)
                    .onChange(of: answer) { text in
                        if let phrase = session.phrase, TypingPhrases.matches(text, phrase) {
                            session.submit(text)
                            answer = ""
                            onUpdate(session)
                        }
                    }
            }
        case .memory:
            memoryView
        case .shake, .squat, .steps:
            motionView
        case .photo:
            VStack(spacing: 16) {
                if let ref = PhotoStore.load(session.settings.photoFile) {
                    Image(uiImage: ref)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 220, height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                Text("Go to this spot and take the same photo").font(.headline).multilineTextAlignment(.center)
                if checkingPhoto {
                    ProgressView().tint(.white)
                } else {
                    PillButton(title: "Open camera", systemImage: "camera.fill") { showCamera = true }
                        .disabled(!CameraPicker.isAvailable)
                }
            }
        case .barcode:
            VStack(spacing: 16) {
                Image(systemName: "barcode.viewfinder").font(.system(size: 90))
                Text("Scan the code you registered").font(.headline)
                PillButton(title: "Open scanner", systemImage: "viewfinder") { showScanner = true }
                    .disabled(!BarcodeScannerView.isAvailable)
            }
        case .tap:
            tapButton(label: "Pat the baby \(max(0, session.required - session.completed)) more times")
        case .none:
            PillButton(title: "I'm up") { onUpdate(session) }
        }
    }

    private var motionView: some View {
        VStack(spacing: 16) {
            Image(systemName: kind.symbolName).font(.system(size: 90))
            Text(kind == .shake ? "Shake your phone to rock the baby"
                 : kind == .squat ? "Hold the phone and do squats"
                 : "Walk around: get out of bed!")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("\(max(0, session.required - session.completed)) to go")
                .font(.headline)
                .opacity(0.85)
            // Fallback for devices without the sensor (e.g. the simulator).
            if (kind == .steps && !MotionMonitor.stepsAvailable) || (kind != .steps && !MotionMonitor.motionAvailable) {
                tapButton(label: "Tap instead")
            }
        }
    }

    private func tapButton(label: String) -> some View {
        VStack(spacing: 16) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                record(1)
            } label: {
                Text("👶")
                    .font(.system(size: 110))
                    .frame(width: 220, height: 220)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Pat the baby")
            Text(label).font(.headline)
        }
    }

    private var memoryView: some View {
        VStack(spacing: 16) {
            Text(memoryRevealed ? "Remember the lit tiles…" : "Tap the tiles that were lit")
                .font(.headline)
            if let puzzle = session.memory {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: puzzle.gridSize)
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(0..<puzzle.cellCount, id: \.self) { cell in
                        let lit = memoryRevealed ? puzzle.lit.contains(cell) : memoryTaps.contains(cell)
                        RoundedRectangle(cornerRadius: 10)
                            .fill(lit ? Color.white : Color.white.opacity(0.2))
                            .aspectRatio(1, contentMode: .fit)
                            .onTapGesture {
                                guard !memoryRevealed else { return }
                                if memoryTaps.contains(cell) { memoryTaps.remove(cell) } else { memoryTaps.insert(cell) }
                            }
                    }
                }
                .frame(maxWidth: 320)
                PillButton(title: "Check (\(memoryTaps.count)/\(puzzle.lit.count))", systemImage: "checkmark") {
                    let ok = session.submitMemory(memoryTaps)
                    status = ok ? "" : "Not quite. Here's a new pattern."
                    if !ok { UINotificationFeedbackGenerator().notificationOccurred(.error) }
                    onUpdate(session)
                    if !session.isComplete { revealMemory() }
                }
                .disabled(memoryRevealed)
            }
        }
    }

    private func revealMemory() {
        memoryTaps = []
        memoryRevealed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { memoryRevealed = false }
    }

    private func submitText() {
        if session.submit(answer) {
            answer = ""
            onUpdate(session)
        } else {
            answer = ""
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            withAnimation(.default.repeatCount(3, autoreverses: true).speed(4)) { wrong = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { wrong = false }
        }
    }

    private func checkPhoto(_ image: UIImage) {
        guard let ref = PhotoStore.load(session.settings.photoFile) else {
            status = "The reference photo is missing. Edit the alarm to retake it."
            return
        }
        checkingPhoto = true
        DispatchQueue.global(qos: .userInitiated).async {
            let distance = PhotoStore.distance(ref, image)
            DispatchQueue.main.async {
                checkingPhoto = false
                if let distance, session.confirmPhotoMatch(distance: distance) {
                    onUpdate(session)
                } else {
                    status = "That doesn't look like the same spot. Try again from the same angle."
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }
}

struct WakeCheckView: View {
    @EnvironmentObject private var engine: AlarmEngine
    let check: WakeCheckSession

    var body: some View {
        ZStack {
            Theme.headerGradient.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Text("☀️").font(.system(size: 110))
                Text("Are you awake?")
                    .font(.largeTitle.weight(.bold))
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let left = max(0, Int(check.deadline.timeIntervalSince(context.date).rounded(.up)))
                    Text("Confirm within \(left) s or the baby starts crying again.")
                        .multilineTextAlignment(.center)
                        .monospacedDigit()
                        .opacity(0.9)
                }
                Spacer()
                PillButton(title: "I'm awake", systemImage: "checkmark.circle.fill") {
                    engine.confirmAwake()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .padding()
        }
        .foregroundColor(.white)
        .interactiveDismissDisabled()
    }
}
