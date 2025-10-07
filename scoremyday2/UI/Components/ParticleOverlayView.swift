import SwiftUI
import UIKit

struct ParticleOverlayView: UIViewRepresentable {
    var events: [Event]

    func makeUIView(context: Context) -> ParticleOverlayUIView {
        let view = ParticleOverlayUIView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: ParticleOverlayUIView, context: Context) {
        uiView.update(events: events)
    }
}

extension ParticleOverlayView {
    struct Event: Identifiable, Equatable {
        enum Style: Equatable {
            case sparkle
            case confetti
        }

        let id: UUID
        let frame: CGRect
        let color: UIColor
        let style: Style

        init(id: UUID = UUID(), frame: CGRect, color: UIColor, style: Style) {
            self.id = id
            self.frame = frame
            self.color = color
            self.style = style
        }
    }
}

fileprivate final class ParticleOverlayUIView: UIView {
    private var activeEmitters: [UUID: CAEmitterLayer] = [:]
    private lazy var particleImage: CGImage? = Self.makeParticleImage()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.frame = bounds
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updatePauseState()
    }

    func update(events: [ParticleOverlayView.Event]) {
        let incoming = Set(events.map { $0.id })
        let existing = Set(activeEmitters.keys)

        for id in existing.subtracting(incoming) {
            if let emitter = activeEmitters[id] {
                emitter.birthRate = 0
                emitter.removeFromSuperlayer()
            }
            activeEmitters[id] = nil
        }

        for event in events where activeEmitters[event.id] == nil {
            trigger(event: event)
        }
    }

    private func trigger(event: ParticleOverlayView.Event) {
        guard let particleImage else { return }

        let emitter = CAEmitterLayer()
        emitter.emitterShape = .circle
        emitter.emitterMode = .outline
        emitter.frame = bounds
        emitter.emitterPosition = CGPoint(x: event.frame.midX, y: event.frame.midY)
        let baseSize = max(event.frame.width, event.frame.height)
        let radius = max(22, baseSize * 0.6)
        emitter.emitterSize = CGSize(width: radius, height: radius)

        let cell = CAEmitterCell()
        cell.contents = particleImage
        cell.birthRate = event.style == .confetti ? 140 : 80
        cell.lifetime = 0.6
        cell.velocity = event.style == .confetti ? 220 : 150
        cell.velocityRange = event.style == .confetti ? 120 : 80
        cell.emissionRange = .pi * 2
        cell.spinRange = .pi * 2
        cell.scale = event.style == .confetti ? 0.22 : 0.14
        cell.scaleRange = 0.06
        cell.alphaSpeed = -0.9
        cell.color = event.color.withAlphaComponent(0.35).cgColor

        emitter.emitterCells = [cell]
        emitter.birthRate = 1
        layer.addSublayer(emitter)
        activeEmitters[event.id] = emitter
        applyPauseState(to: emitter)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self, weak emitter] in
            emitter?.birthRate = 0
            self?.scheduleRemoval(for: event.id)
        }
    }

    private func scheduleRemoval(for id: UUID) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, let emitter = self.activeEmitters[id] else { return }
            emitter.birthRate = 0
            emitter.removeFromSuperlayer()
            self.activeEmitters[id] = nil
        }
    }

    private func updatePauseState() {
        let isPaused = window == nil
        for emitter in activeEmitters.values {
            applyPauseState(to: emitter, paused: isPaused)
        }
    }

    private func applyPauseState(to emitter: CAEmitterLayer, paused: Bool? = nil) {
        let shouldPause = paused ?? (window == nil)
        if shouldPause {
            if emitter.speed != 0 {
                emitter.speed = 0
                emitter.timeOffset = emitter.convertTime(CACurrentMediaTime(), from: nil)
            }
        } else {
            if emitter.speed == 0 {
                let pausedTime = emitter.timeOffset
                emitter.speed = 1
                emitter.timeOffset = 0
                emitter.beginTime = 0
                let timeSincePause = emitter.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
                emitter.beginTime = timeSincePause
            }
        }
    }

    private static func makeParticleImage() -> CGImage? {
        let size: CGFloat = 12
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        context.setFillColor(UIColor.white.cgColor)
        context.addEllipse(in: rect.insetBy(dx: 2, dy: 2))
        context.fillPath()

        let image = UIGraphicsGetImageFromCurrentImageContext()?.cgImage
        UIGraphicsEndImageContext()
        return image
    }
}
