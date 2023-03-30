//
//  MLOperation.swift
//  VideoML
//
//  Created by Aslan Arapbaev on 3/26/23.
//

import UIKit

protocol MaskDataProvider {
    var maskImage: UIImage? { get }
    var inputImage: UIImage { get }
    var data: ImageData { get }
}

final class MLOperation: AsyncOperation, MaskDataProvider {
    var inputImage: UIImage
    var maskImage: UIImage?
    var data: ImageData
    let managerML = MLManager()
    
    init(image: UIImage) {
        self.inputImage = image
        self.data = .init(original: image)
        super.init()
    }
    
    override func main() {
        managerML.onReady = { [weak self] image in
            guard let self = self else { return }
            self.maskImage = image
            self.data.mask = image
            self.state = .finished
        }
        
        managerML.process(image: inputImage)
    }
}
