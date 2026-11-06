//
//  BodyPhotoValidator.swift
//  StilYa
//
//  On-device check for a user's own reference photo: one person, visible
//  head to ankles. Runs Vision body-pose detection; nothing leaves the device.
//

import UIKit
import Vision

enum BodyPhotoValidator {
    enum Result: Equatable {
        case ok
        case noPerson
        case multiplePeople
        case notFullBody
    }

    /// Minimum Vision confidence for a joint to count as visible.
    private static let minConfidence: Float = 0.3

    static func validate(_ image: UIImage) async -> Result {
        guard let cgImage = image.cgImage else { return .ok }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        return await Task.detached(priority: .userInitiated) {
            let request = VNDetectHumanBodyPoseRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            do {
                try handler.perform([request])
            } catch {
                // Vision unavailable (e.g. some simulators) — don't block the user
                return .ok
            }

            let people = request.results ?? []
            if people.isEmpty { return .noPerson }
            if people.count > 1 { return .multiplePeople }

            guard let points = try? people[0].recognizedPoints(.all) else { return .ok }
            func visible(_ joint: VNHumanBodyPoseObservation.JointName) -> Bool {
                (points[joint]?.confidence ?? 0) >= minConfidence
            }

            let headVisible = visible(.nose) || visible(.neck) || visible(.leftEye) || visible(.rightEye)
            let feetVisible = visible(.leftAnkle) || visible(.rightAnkle)
            return (headVisible && feetVisible) ? .ok : .notFullBody
        }.value
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
