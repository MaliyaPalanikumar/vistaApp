//
//  TrafficSignDetection.swift
//  VISTA
//
//  Created by Maliya Palanikumar on 22/08/26.
//

import Foundation

/// A single classification result produced by the MobileNetV2 pipeline for the current frame.
struct TrafficSignDetection: Identifiable, Equatable {
    let id: String
    let name: String
    let confidence: Double

    /// Asset catalog image name for this sign class. Falls back to a system
    /// symbol in the UI when no matching asset has been added yet.
    var imageName: String { id }

    init(id: String, name: String, confidence: Double) {
        self.id = id
        self.name = name
        self.confidence = confidence
    }
}
