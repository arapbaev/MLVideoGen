//
//  CutInOperation.swift
//  VideoML
//
//  Created by Aslan Arapbaev on 3/25/23.
//

import UIKit

protocol ImageDataProvider {
    var outputImage: UIImage? { get }
    var data: ImageData? { get }
}

final class CutOperation: Operation, ImageDataProvider {
    private static let context = CIContext()
    
    var outputImage: UIImage?
    var data: ImageData?
    private let inputImage: UIImage?
    private let maskImage: UIImage?
    private let type: MaskFilter.MaskType
    
    init(image: UIImage? = nil, mask: UIImage? = nil, type: MaskFilter.MaskType) {
        self.inputImage = image
        self.maskImage = mask
        self.type = type
    
        super.init()
    }
    
    override func main() {
        let dependancyImages = dependencies
            .compactMap { op -> (image: UIImage?, mask: UIImage?) in
                let operation = op as? MaskDataProvider
                return (operation?.inputImage, operation?.maskImage)
            }
            .first
        
        data = dependencies.compactMap { op in
            return (op as? MaskDataProvider)?.data
        }.first
        
        guard let inputImage = inputImage ?? dependancyImages?.image,
              let maskImage = maskImage ?? dependancyImages?.mask else {
            return
        }
        
        guard let filter = MaskFilter(image: inputImage, mask: maskImage, type: type),
              let output = filter.outputImage else {
            print("Failed to generate image")
            return
        }
        
        print("currentThread", Thread.current)
        let fromRect = CGRect(origin: .zero, size: inputImage.size)
        guard let cgImage = CutOperation.context.createCGImage(output, from: fromRect) else {
            print("No image generated")
            return
        }
        
        outputImage = UIImage(cgImage: cgImage)
        
        if type == .inside {
            data?.front = outputImage
        } else {
            data?.back = outputImage
        }
    }
}
