//
//  MLManager.swift
//  VideoML
//
//  Created by Aslan Arapbaev on 3/25/23.
//

import CoreML
import UIKit
import CoreImage
import Vision


class MLManager {
    var request: VNCoreMLRequest?
    var visionModel: VNCoreMLModel?
    
    var onReady: ((UIImage) -> Void)?
    
    let segmentationModel: segmentation_8bit = {
        do {
            let config = MLModelConfiguration()
            return try segmentation_8bit(configuration: config)
        } catch {
            print("Error loading model.")
            abort()
        }
    }()
    
    init() {
        if let visionModel = try? VNCoreMLModel(for: segmentationModel.model) {
            self.visionModel = visionModel
            request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
            request?.imageCropAndScaleOption = .scaleFill
        } else {
            print("Could not create request.")
            abort()
        }
    }
    
    func process(image: UIImage) {
        predict(with: image.cgImage)
    }
    
    func predict(with cgImage: CGImage?) {
        guard let request = request else { fatalError() }
        guard let cgImage = cgImage else {
            return
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }
    
    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        let observations = request.results as! [VNPixelBufferObservation]
        let pixelBuffer = (observations.first?.pixelBuffer)!
            
        guard let maskUIImage = UIImage(pixelBuffer: pixelBuffer) else { return }
        onReady?(maskUIImage)
    }
}


