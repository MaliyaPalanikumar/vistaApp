//
//  DetectionStabilizer.swift
//  VISTA
//
//  Created by Maliya Palanikumar on 25/08/26.
//

import Foundation

enum StabilizedResult {
    /// A class has won a majority of the recent window; show it.
    case show(TrafficSignDetection)
    /// No sign has been seen confidently for a while; clear the banner.
    case clear
    /// Not enough evidence yet either way; leave the banner as-is.
    case unchanged
}

/// Smooths per-frame classifications so the banner doesn't flicker between
/// classes when the model's confidence wavers from one frame to the next.
/// A class only reaches the view once it wins a majority of the last few
/// samples; low-confidence frames don't immediately blank the banner, they
/// only clear it after several misses in a row.
final class DetectionStabilizer {
    private let windowSize: Int
    private let minimumConfidence: Double
    private let requiredAgreement: Int
    private let maxConsecutiveMisses: Int

    private var recentLabels: [String] = []
    private var latestByLabel: [String: TrafficSignDetection] = [:]
    private var consecutiveMisses = 0

    init(
        windowSize: Int = 5,
        minimumConfidence: Double = 0.5,
        requiredAgreement: Int = 3,
        maxConsecutiveMisses: Int = 8
    ) {
        self.windowSize = windowSize
        self.minimumConfidence = minimumConfidence
        self.requiredAgreement = requiredAgreement
        self.maxConsecutiveMisses = maxConsecutiveMisses
    }

    func stabilize(_ detection: TrafficSignDetection?) -> StabilizedResult {
        guard let detection, detection.confidence >= minimumConfidence else {
            consecutiveMisses += 1
            guard consecutiveMisses >= maxConsecutiveMisses else { return .unchanged }
            let hadDetection = !recentLabels.isEmpty
            reset()
            return hadDetection ? .clear : .unchanged
        }
        consecutiveMisses = 0

        recentLabels.append(detection.id)
        latestByLabel[detection.id] = detection
        if recentLabels.count > windowSize {
            let dropped = recentLabels.removeFirst()
            if !recentLabels.contains(dropped) {
                latestByLabel.removeValue(forKey: dropped)
            }
        }

        let counts = Dictionary(grouping: recentLabels, by: { $0 }).mapValues(\.count)
        guard let winner = counts.max(by: { $0.value < $1.value }),
              winner.value >= requiredAgreement,
              let winningDetection = latestByLabel[winner.key] else {
            return .unchanged
        }

        return .show(winningDetection)
    }

    private func reset() {
        recentLabels.removeAll()
        latestByLabel.removeAll()
        consecutiveMisses = 0
    }
}
