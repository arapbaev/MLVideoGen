//
//  ContentView.swift
//  VideoML
//
//  Created by Aslan Arapbaev on 3/25/23.
//

import SwiftUI
import Combine
import AVKit

struct ContentView: View {
    
    @ObservedObject var vm = ViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    List(vm.imagesToProcess, id: \.self) { image in
                        VStack(alignment: .center) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                        }
                    }
                    .listStyle(.plain)
                    
                    HStack {
                        Button("Generate Video") {
                            vm.processImages(effect: .sequence)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Generate Random") {
                            vm.processImages(effect: .sequenceRandom)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                }
            }
            .overlay(alignment: .center, content: {
                if vm.isProcessing {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.thinMaterial)
                            .frame(width: 50, height: 50)
                        
                        ProgressView()
                    }
                }
            })
            .sheet(item: $vm.avPlayer, content: { player in
                VideoPlayer(player: player)
            })
            .navigationTitle("Images to process")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

class ViewModel: ObservableObject {
    let imagesToProcess: [UIImage] = [
        .init(named: "img1")!, .init(named: "img2")!, .init(named: "img3")!,
        .init(named: "img4")!, .init(named: "img5")!, .init(named: "img6")!,
        .init(named: "img7")!, .init(named: "img8")!]
    private let videoManager = VideoManager()
    private let queue = OperationQueue()
    private var cancellables = Set<AnyCancellable>()
    private var images: [ImageData] = []
    private var videoProcessEffect: VideoManager.VideoEffect = .sequence
    
    @Published var isProcessing = false
    @Published var avPlayer: AVPlayer?
    
    init() {
            // Combine
        queue.publisher(for: \.operationCount, options: .new)
            .sink { [weak self] count in
                guard let self = self else { return }
                if self.isProcessing && count == 0 {
                    Task {
                        await self.generateVideo(effect: self.videoProcessEffect)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
        // async await
    func generateVideo(effect: VideoManager.VideoEffect) async {
        do {
            if let emptyURL = try await videoManager.createEmptyVideo(),
               let videoURL = try await videoManager.createVideo(emptyURL, images: images, effect: effect) {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.avPlayer = AVPlayer(url: videoURL)
                }
            }
        } catch {
            debugPrint("Something wrong with video processing.")
            debugPrint(error.localizedDescription)
        }
    }
    
        // GCD
    func processImages(effect: VideoManager.VideoEffect) {
        videoProcessEffect = effect
        isProcessing = true
        images = []
        DispatchQueue.global().async {
            let arr = self.videoProcessEffect == .sequence ? self.imagesToProcess : self.imagesToProcess.shuffled()
            for image in arr {
                self.createLayers(for: image)
            }
        }
    }
    
        // Operations
    func createLayers(for image: UIImage) {
        let mlOp = MLOperation(image: image)
        
        let cutInOp = CutOperation(type: .inside)
        cutInOp.addDependency(mlOp)
        
        let cutOutOp = CutOperation(type: .outside)
        cutOutOp.addDependency(mlOp)
        
        let blendOp = BlendOperation(type: .pattern1)
        blendOp.addDependency(cutOutOp)
        
        let blendOp2 = BlendOperation(type: .pattern2)
        blendOp2.addDependency(cutOutOp)
        
        let warpOp = WarpOperation()
        warpOp.addDependency(cutOutOp)
        
        let colorOp = ColorOperation(type: .filter1)
        colorOp.addDependency(cutOutOp)
        
        let colorOp2 = ColorOperation(type: .filter2)
        colorOp2.addDependency(cutOutOp)
        colorOp2.addDependency(cutInOp)
        colorOp2.addDependency(blendOp)
        colorOp2.addDependency(blendOp2)
        colorOp2.addDependency(warpOp)
        colorOp2.addDependency(colorOp)
        
        colorOp2.completionBlock = { [weak self] in
            guard let data = colorOp2.data else {
                return
            }
            self?.images.append(data)
        }
        
        queue.addOperations([mlOp, cutInOp, cutOutOp, blendOp, blendOp2, warpOp, colorOp, colorOp2], waitUntilFinished: false)
    }
}

extension AVPlayer: Identifiable { }
