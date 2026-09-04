//
//  TrafficSignClassifier.swift
//  VISTA
//
//  Created by Maliya Palanikumar on 25/08/26.
//

import CoreML

/// Runs MobileNetV2.mlpackage predictions on preprocessed camera frames and
/// turns the raw output into a `TrafficSignDetection` the view can display.
final class TrafficSignClassifier {
    /// GTSRB class labels in the same order as the model's training data and
    /// its 43-way softmax output. Order must match `sign_names` in
    /// notebooks/02_MobileNetV2.ipynb — do not reorder without retraining.
    private static let classLabels = [
        "limit_zone_20", "limit_zone_30", "limit_zone_50", "limit_zone_60", "limit_zone_70",
        "limit_zone_80", "end_of_speed_limit", "limit_zone_100", "limit_zone_120",
        "no_passing", "no_passing_for_trucks", "right_of_way", "priority_road",
        "yield_right_of_way", "stop", "prohibited_for_all_vehicles", "tractors_and_trucks_prohibited",
        "entry_prohibited", "danger", "single_curve_left", "single_curve_right", "double_curve",
        "rough_road", "slippery_road", "road_narrows", "construction_site", "signal_lights_ahead",
        "pedestrian_crosswalk_ahead", "children", "bicycle_crossing", "snow_ahead",
        "wild_animal_crossing", "end_of_all_restrictions", "mandatory_right", "mandatory_left",
        "mandatory_ahead", "mandatory_ahead_right", "mandatory_ahead_left", "mandatory_down_right",
        "mandatory_down_left", "traffic_circle", "end_of_no_passing_zone", "end_of_no_passing_zone_trucks"
    ]

    private let model: MobileNetV2?

    /// Set whenever loading or prediction fails, so the caller can surface it
    /// in the UI instead of it being silently lost to the console on-device.
    /// Cleared on the next successful prediction.
    private(set) var lastError: String?

    init() {
        do {
            model = try MobileNetV2(configuration: MLModelConfiguration())
        } catch {
            model = nil
            lastError = "Failed to load MobileNetV2: \(error.localizedDescription)"
        }
    }

    /// Runs the model on a preprocessed `(1, 224, 224, 3)` frame tensor and
    /// returns the winning class, or `nil` if loading/prediction failed.
    func classify(_ input: MLMultiArray) -> TrafficSignDetection? {
        guard let model else {
            lastError = "MobileNetV2 is not loaded."
            return nil
        }

        do {
            let probabilities = try model.prediction(input_layer_35: input).Identity

            guard let (bestIndex, bestScore) = Self.argmax(probabilities) else {
                lastError = "Model returned an empty prediction."
                return nil
            }

            lastError = nil
            let label = Self.classLabels[bestIndex]
            return TrafficSignDetection(
                id: label,
                name: label.replacingOccurrences(of: "_", with: " ").capitalized,
                confidence: Double(bestScore)
            )
        } catch {
            lastError = "Prediction failed: \(error.localizedDescription)"
            return nil
        }
    }

    /// Index and value of the highest-scoring entry in a softmax output.
    private static func argmax(_ probabilities: MLMultiArray) -> (index: Int, score: Float)? {
        guard probabilities.count > 0 else { return nil }

        var bestIndex = 0
        var bestScore = Float(truncating: probabilities[0])
        for index in 1..<probabilities.count {
            let score = Float(truncating: probabilities[index])
            if score > bestScore {
                bestScore = score
                bestIndex = index
            }
        }
        return (bestIndex, bestScore)
    }
}
