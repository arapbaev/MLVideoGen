//
//  ColorOperation.swift
//  VideoML
//
//  Created by Aslan Arapbaev on 3/26/23.
//

import UIKit

final class ColorOperation: Operation, ImageDataProvider {
    private static let context = CIContext()
    
    var outputImage: UIImage?
    var data: ImageData?
    private let inputImage: UIImage?
    private let type: ColorFilter.FilterType
    
    init(image: UIImage? = nil, type: ColorFilter.FilterType = .filter1) {
        self.inputImage = image
        self.type = type
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
        
        guard let filter = ColorFilter(image: inputImage, type: type),
              let output = filter.outputImage else {
            print("Failed to generate image")
            return
        }
        
        print("currentThread", Thread.current)
        let fromRect = CGRect(origin: .zero, size: inputImage.size)
        guard let cgImage = ColorOperation.context.createCGImage(output, from: fromRect) else {
            print("No image generated")
            return
        }
        
        outputImage = UIImage(cgImage: cgImage)
        
        if type == .filter1 {
            data?.backColored1 = outputImage
        } else {
            data?.backColored2 = outputImage
        }
    }
}
