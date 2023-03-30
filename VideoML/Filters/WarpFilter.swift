//
//  WarpFilter.swift
//  VideoML
//
//  Created by Aslan Arapbaev on 3/26/23.
//

import CoreImage
import UIKit

class WarpFilter: CIFilter {
    static var kernel: CIWarpKernel = { () -> CIWarpKernel in
        guard let url = Bundle.main.url(
            forResource: "WarpFilterKernel.ci",
            withExtension: "metallib"),
              let data = try? Data(contentsOf: url) else {
            fatalError("Unable to load metallib")
        }
        
        guard let kernel = try? CIWarpKernel(
            functionName: "warpFilter",
            fromMetalLibraryData: data) else {
            fatalError("Unable to create warp kernel")
        }
        
        return kernel
    }()
    
    var inputImage: CIImage?
    
    convenience init?(image: UIImage) {
        guard let inputImage = image.ciImage ?? CIImage(image: image) else {
            return nil
        }
        
        self.init()
        
        self.inputImage = inputImage
    }
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage else { return .none }
        
        return WarpFilter.kernel.apply(
            extent: inputImage.extent,
            roiCallback: { _, rect in
                return rect
            },
            image: inputImage,
            arguments: [])
    }
}
