//
//  ImageData.swift
//  VideoML
//
//  Created by Aslan Arapbaev on 3/30/23.
//

import UIKit

class ImageData {
    let original: UIImage
    var mask: UIImage?
    var front: UIImage?
    var back: UIImage?
    var backWarped: UIImage?
    var backColored1: UIImage?
    var backColored2: UIImage?
    var backBlended: UIImage?
    var backBlended2: UIImage?
    
    var images: [UIImage] {
        return [original, front, back, backWarped, backBlended, backBlended2, backColored1, backColored2].compactMap { $0 }
    }
    
    var randomBack: UIImage {
        let backs = [original, backBlended, backBlended2, backColored1, backColored2].compactMap { $0 }
        return backs[Int.random(in: 0...4)]
    }
    
    init(original: UIImage) {
        self.original = original
    }
}

