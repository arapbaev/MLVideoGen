//
//  ColorFilter.swift
//  VideoML
//
//  Created by Aslan Arapbaev on 3/26/23.
//

import UIKit
import CoreImage

class ColorFilter: CIFilter {
    enum FilterType {
        case filter1, filter2
    }
    var inputImage: CIImage?
    var type: FilterType = .filter1
    
    var kernel: CIColorKernel {
        guard let url = Bundle.main.url(
            forResource: "ColorFilterKernel.ci",
            withExtension: "metallib"),
              let data = try? Data(contentsOf: url) else {
            fatalError("Unable to load metallib")
        }
        let funcName = type == .filter1 ? "colorFilterKernel" : "colorFilterKernel2"
        guard let kernel = try? CIColorKernel(
            functionName: funcName,
            fromMetalLibraryData: data) else {
            fatalError("Unable to create color kernel")
        }
        
        return kernel
    }
    
    convenience init?(image: UIImage, type: FilterType) {
        guard let inputImage = image.ciImage ?? CIImage(image: image) else {
            return nil
        }
        
        self.init()
        
        self.inputImage = inputImage
        self.type = type
    }
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage else { return nil }
        return kernel.apply(
            extent: inputImage.extent,
            roiCallback: { _, rect in
                return rect
            },
            arguments: [inputImage])
    }
}
