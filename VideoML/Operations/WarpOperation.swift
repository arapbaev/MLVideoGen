//
//  WarpOperation.swift
//  VideoML
//
//  Created by Aslan Arapbaev on 3/26/23.
//

import UIKit

final class WarpOperation: Operation, ImageDataProvider {
    private static let context = CIContext()
    
    var outputImage: UIImage?
    var data: ImageData?
    
    private let inputImage: UIImage?
    
    init(image: UIImage? = nil) {
        inputImage = image
        super.init()
    }
    
    override func main() {
        let dependencyImage = dependencies
            .compactMap { ($0 as? ImageDataProvider)?.outputImage }
            .first
        
        data = dependencies.compactMap { op in
            return (op as? ImageDataProvider)?.data
        }.first
        
        guard let inputImage = inputImage ?? dependencyImage else {
            return
        }
        
        guard let filter = WarpFilter(image: inputImage),
              let output = filter.outputImage else {
            print("Failed to generate image")
            return
        }
        
        print("currentThread", Thread.current)
        let fromRect = CGRect(origin: .zero, size: inputImage.size)
        guard let cgImage = WarpOperation.context.createCGImage(output, from: fromRect) else {
            print("No image generated")
            return
        }
        
        outputImage = UIImage(cgImage: cgImage)
        data?.backWarped = outputImage
    }
}
