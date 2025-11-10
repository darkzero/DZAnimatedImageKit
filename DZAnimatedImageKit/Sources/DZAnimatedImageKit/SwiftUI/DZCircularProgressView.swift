//
//  DZCircularProgressView.swift
//  DZAnimatedImageKit
//
//  Created by Yuhua Hu on 2025/9/26.
//

import SwiftUI
public enum DZProgressState: Equatable {
    case determinate(CGFloat)   // 0...1
    case indeterminate          // unkown
}

public struct DZCircularProgressView: View {
    // MARK: - Public config
    public var state: DZProgressState
    public var size: CGFloat = 64
    public var lineWidth: CGFloat = 6
    public var trackColor: Color = Color.primary.opacity(0.33)
    public var roundedCaps: Bool = true
    // 0...1
    public var progressColor: Color = .accentColor
    public var spinnerColor: Color = .accentColor
    public var showsPercentage: Bool = true
    // unkown max
    public var clockwise: Bool = true
    @State public var spinnerSweep: CGFloat = 0.33
    public var spinnerSpeed: Double = 0.9
    // MARK: - Private
    @State private var spinning = false
    
    public init(
        state: DZProgressState,
        size: CGFloat = 64,
        lineWidth: CGFloat = 6,
        trackColor: Color = Color.primary.opacity(0.33),
        progressColor: Color = .primary,
        spinnerColor: Color = .primary,
        showsPercentage: Bool = true,
        roundedCaps: Bool = true,
        clockwise: Bool = true,
        spinnerSweep: CGFloat = 0.22,
        spinnerSpeed: Double = 0.9
    ) {
        self.state = state
        self.size = size
        self.lineWidth = lineWidth
        self.trackColor = trackColor
        self.progressColor = progressColor
        self.spinnerColor = spinnerColor
        self.showsPercentage = showsPercentage
        self.roundedCaps = roundedCaps
        self.clockwise = clockwise
        self.spinnerSweep = max(0.05, min(spinnerSweep, 0.95))
        self.spinnerSpeed = max(0.2, spinnerSpeed)
    }
    
    public var body: some View {
        let circleSize = size * 0.7
        ZStack {
            // background circle
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)
                .frame(width: circleSize, height: circleSize)

            switch state {
            case .determinate(let rawP):
                let p = max(0, min(1, rawP))
                Circle()
                    .trim(from: 0, to: p)
                    .stroke(
                        progressColor,
                        style: StrokeStyle(
                            lineWidth: lineWidth,
                            lineCap: roundedCaps ? .round : .butt
                        )
                    )
                    .frame(width: circleSize, height: circleSize)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.2), value: p)
                    .frame(width: circleSize, height: circleSize)

                if showsPercentage {
                    Text("\(Int(p * 100))%")
                        .font(.system(size: size * 0.2, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .accessibilityHidden(true)
                }

            case .indeterminate:
                let start = Angle(degrees: -90)
                let end   = Angle(degrees: -90 + Double(spinnerSweep) * 360)
                let tailAlpha: CGFloat = 0.35
                let gradient = AngularGradient(
                    gradient: Gradient(stops: [
                        .init(color: spinnerColor.opacity(0.0), location: 0.0),
                        .init(color: spinnerColor.opacity(Double(tailAlpha)), location: 0.35),
                        .init(color: spinnerColor, location: 1.0),
                    ]),
                    center: .center,
                    startAngle: start,
                    endAngle: end
                )

                RingArc(startAngle: start, endAngle: end, clockwise: false)
                    .stroke(
                        gradient,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: roundedCaps ? .round : .butt)
                    )
                    .frame(width: circleSize, height: circleSize)
                    .rotationEffect(.degrees(self.spinning ? (clockwise ? 360 : -360) : 0))
                    .animation(.linear(duration: spinnerSpeed).repeatForever(autoreverses: false),
                               value: self.spinning)
                    .animation(.easeInOut(duration: 0.2).repeatForever(autoreverses: true), value: self.spinnerSweep)
                    .onAppear { self.spinning = true }
                    .onDisappear { self.spinning = false }
            }
        }
        .frame(width: size, height: size)
        .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
        .cornerRadius(16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading progress")
        .accessibilityValue(accessibilityValueText)
    }

    private var accessibilityValueText: String {
        switch state {
        case .determinate(let p):
            return "\(Int(max(0, min(1, p)) * 100)) percents"
        case .indeterminate:
            return "Loading..."
        }
    }
    
    private struct RingArc: Shape {
        var startAngle: Angle   // 例：-90° 代表从 12 点方向开始
        var endAngle: Angle
        var clockwise: Bool = false

        func path(in rect: CGRect) -> Path {
            var p = Path()
            let c = CGPoint(x: rect.midX, y: rect.midY)
            let r = min(rect.width, rect.height) / 2
            p.addArc(center: c, radius: r, startAngle: startAngle, endAngle: endAngle, clockwise: clockwise)
            return p
        }
    }
}
