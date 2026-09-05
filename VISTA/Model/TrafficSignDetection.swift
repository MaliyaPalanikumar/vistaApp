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

    var imageName: String { id }

    init(id: String, name: String, confidence: Double) {
        self.id = id
        self.name = name
        self.confidence = confidence
    }
}
