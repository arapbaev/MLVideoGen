//
//  BlendFilter.swift
//  VideoML
//
//  Created by Aslan Arapbaev on 3/25/23.
//

import UIKit

final class BlendOperation: Operation, ImageDataProvider {
    enum BlendType {
        case pattern1, pattern2
        
        var image: UIImage {
            switch self {
            case .pattern1:
                return UIImage(named: "pattern1")!
//                return UIImage(named: "mult_color")!
            case .pattern2:
                return UIImage(named: "pattern2")!
            }
        }
    }
    private static let context = CIContext()
    
    var outputImage: UIImage?
    var data: ImageData?
    private let inputImage: UIImage?
    private let maskImage: UIImage
    private let type: BlendType
    
    init(image: UIImage? = nil, type: BlendType) {
        self.inputImage = image
        self.maskImage = type.image
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
        
        guard let filter = BlendFilter(image: inputImage, background: maskImage),
              let output = filter.outputImage else {
            print("Failed to generate image")
            return
        }
        
        print("currentThread", Thread.current)
        let fromRect = CGRect(origin: .zero, size: inputImage.size)
        guard let cgImage = BlendOperation.context.createCGImage(output, from: fromRect) else {
            print("No image generated")
            return
        }
        
        outputImage = UIImage(cgImage: cgImage)
        switch type {
        case .pattern1:
            data?.backBlended = outputImage
        case .pattern2:
            data?.backBlended2 = outputImage
        }
    }
}
