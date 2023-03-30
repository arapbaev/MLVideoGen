//
//  MaskFilter.swift
//  VideoML
//
//  Created by Aslan Arapbaev on 3/26/23.
//

import UIKit
import CoreGraphics

public class MaskFilter: CIFilter {
    enum MaskType {
        case inside, outside
    }
    var inputImage: CIImage?
    var maskImage: CIImage?
    var type: MaskType = .inside
    
    override public var outputImage: CIImage? {
        guard let inputImage = inputImage, var maskImage = maskImage else {
            return nil
        }
        
        let originalSize = inputImage.extent.size
        let scaleX = originalSize.width / maskImage.extent.width
        let scaleY = originalSize.height / maskImage.extent.height
        maskImage = maskImage.transformed(by: .init(scaleX: scaleX, y: scaleY))
        maskImage = maskImage.applyingGaussianBlur(sigma: 0)
        
        let maskParameters = [
            kCIInputImageKey: maskImage
        ]
        
        if type == .outside {
            guard let invertedMask = ciImage(from: "CIColorInvert", parameters: maskParameters) else {
                return nil
            }
            maskImage = invertedMask
        }
        
        let combinedParameters = [
            kCIInputMaskImageKey: maskImage as Any,
            kCIInputImageKey: inputImage as Any
        ]
        return ciImage(from: "CIBlendWithMask", parameters: combinedParameters)
    }
    
    convenience init?(image: UIImage, mask: UIImage, type: MaskType = .inside) {
        guard let inputImage = image.ciImage ?? CIImage(image: image),
              let maskImage = mask.ciImage ?? CIImage(image: mask) else {
            return nil
        }
        
        self.init()
        
        self.type = type
        self.inputImage = inputImage
        self.maskImage = maskImage
        
    }
}

extension CIFilter {
    func ciImage(from filterName: String, parameters: [String: Any]) -> CIImage? {
        guard let filtered = CIFilter(name: filterName, parameters: parameters) else {
            return nil
        }
        
        return filtered.outputImage
    }
}
