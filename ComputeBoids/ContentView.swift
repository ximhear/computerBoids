//
//  ContentView.swift
//  ComputeBoids
//
//  Created by gzonelee on 11/28/24.
//

import SwiftUI
import MetalKit

struct ContentView: View {
    var body: some View {
        MetalView()
            .edgesIgnoringSafeArea(.all)
    }
}

struct MetalView: UIViewRepresentable {
    func makeUIView(context: Context) -> MTKView {
        let metalView = MTKView()
        if let device = MTLCreateSystemDefaultDevice() {
            metalView.device = device
            metalView.delegate = context.coordinator
            metalView.preferredFramesPerSecond = 60
            metalView.framebufferOnly = false
            metalView.enableSetNeedsDisplay = false
        } else {
            fatalError("Metal is not supported on this device")
        }
        return metalView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        // 업데이트 필요 없음
    }
    
    func makeCoordinator() -> MetalRenderer {
        return MetalRenderer()
    }
}


#Preview {
    ContentView()
}
