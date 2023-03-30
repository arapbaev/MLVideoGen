//
//  BlendFilter.swift
//  VideoML
//
//  Created by Aslan Arapbaev on 3/26/23.
//

import CoreImage
import UIKit

class BlendFilter: CIFilter {
    var background: CIImage?
    var inputImage: CIImage?
    
    convenience init?(image: UIImage, background: UIImage) {
        guard let inputImage = image.ciImage ?? CIImage(image: image),
              let background = background.ciImage ?? CIImage(image: background) else {
            return nil
        }
        
        self.init()
        
        self.inputImage = inputImage
        self.background = background
    }
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage else { return .none }
        guard var background = background else { return .none }
        let originalSize = inputImage.extent.size
        let scaleX = originalSize.width / background.extent.width
        let scaleY = originalSize.height / background.extent.height
        background = background.transformed(by: .init(scaleX: scaleX, y: scaleY))
        
        return CIBlendKernel.multiply.apply(
            foreground: inputImage,
            background: background)
    }
}
