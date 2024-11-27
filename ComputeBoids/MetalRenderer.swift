//
//  MetalRenderer.swift
//  ComputeBoids
//
//  Created by gzonelee on 11/28/24.
//

import MetalKit

class MetalRenderer: NSObject, MTKViewDelegate {
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    
    var computePipelineState: MTLComputePipelineState!
    var renderPipelineState: MTLRenderPipelineState!
    
    var particleBuffers: [MTLBuffer] = []
    var currentBufferIndex = 0
    
    var numParticles: Int = 1500
    var simParamsBuffer: MTLBuffer!
    var vertexBuffer: MTLBuffer!
    var vertexCount: Int = 0
    
    struct Particle {
        var pos: SIMD2<Float>
        var vel: SIMD2<Float>
    }
    
    struct SimParams {
        var deltaT: Float
        var rule1Distance: Float
        var rule2Distance: Float
        var rule3Distance: Float
        var rule1Scale: Float
        var rule2Scale: Float
        var rule3Scale: Float
        var numParticles: UInt32 // 추가된 필드
    }
    
    override init() {
        super.init()
        self.device = MTLCreateSystemDefaultDevice()
        self.commandQueue = device.makeCommandQueue()
        setupBuffers()
        setupPipeline()
    }
    
    func setupBuffers() {
        // 시뮬레이션 파라미터 초기화
        var simParams = SimParams(
            deltaT: 0.04,
            rule1Distance: 0.1,
            rule2Distance: 0.025,
            rule3Distance: 0.025,
            rule1Scale: 0.02,
            rule2Scale: 0.05,
            rule3Scale: 0.005,
            numParticles: UInt32(numParticles) // 파티클 수 전달
        )
        
        simParamsBuffer = device.makeBuffer(bytes: &simParams, length: MemoryLayout<SimParams>.stride, options: [])
        
        // 파티클 초기화
        var initialParticles = [Particle](repeating: Particle(pos: SIMD2<Float>(0,0), vel: SIMD2<Float>(0,0)), count: numParticles)
        
        for i in 0..<numParticles {
            let posX = 2 * (Float.random(in: 0..<1) - 0.5)
            let posY = 2 * (Float.random(in: 0..<1) - 0.5)
            let velX = 2 * (Float.random(in: 0..<1) - 0.5) * 0.1
            let velY = 2 * (Float.random(in: 0..<1) - 0.5) * 0.1
            initialParticles[i] = Particle(pos: SIMD2<Float>(posX, posY), vel: SIMD2<Float>(velX, velY))
        }
        
        // 파티클 버퍼 생성 (핑퐁 버퍼링)
        for _ in 0..<2 {
            let particleBuffer = device.makeBuffer(bytes: initialParticles, length: MemoryLayout<Particle>.stride * numParticles, options: [])
            particleBuffers.append(particleBuffer!)
        }
        
        // 버텍스 데이터 생성
        let vertexData: [SIMD2<Float>] = [
            SIMD2<Float>(-0.01, -0.02),
            SIMD2<Float>( 0.01, -0.02),
            SIMD2<Float>( 0.0 ,  0.02),
        ]
        vertexBuffer = device.makeBuffer(bytes: vertexData, length: MemoryLayout<SIMD2<Float>>.stride * vertexData.count, options: [])
        vertexCount = vertexData.count
    }
    
    func setupPipeline() {
        // 셰이더 로드
        let library = device.makeDefaultLibrary()
        
        // 컴퓨트 파이프라인 설정
        let computeFunction = library?.makeFunction(name: "computeShader")
        do {
            computePipelineState = try device.makeComputePipelineState(function: computeFunction!)
        } catch {
            fatalError("Failed to create compute pipeline state: \(error)")
        }
        
        // 렌더 파이프라인 설정
        let vertexFunction = library?.makeFunction(name: "vertexShader")
        let fragmentFunction = library?.makeFunction(name: "fragmentShader")
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // 버텍스 디스크립터 설정
        let vertexDescriptor = MTLVertexDescriptor()
        // 버퍼 인덱스 0: 파티클 데이터 (인스턴스)
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD2<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<Particle>.stride
        vertexDescriptor.layouts[0].stepFunction = .perInstance
        
        // 버퍼 인덱스 1: 버텍스 위치
        vertexDescriptor.attributes[2].format = .float2
        vertexDescriptor.attributes[2].offset = 0
        vertexDescriptor.attributes[2].bufferIndex = 1
        vertexDescriptor.layouts[1].stride = MemoryLayout<SIMD2<Float>>.stride
        vertexDescriptor.layouts[1].stepFunction = .perVertex
        
        renderPipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch {
            fatalError("Failed to create render pipeline state: \(error)")
        }
    }
    
    func draw(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let drawable = view.currentDrawable else {
            return
        }
        
        // 컴퓨트 패스
        if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
            computeEncoder.setComputePipelineState(computePipelineState)
            computeEncoder.setBuffer(simParamsBuffer, offset: 0, index: 0)
            computeEncoder.setBuffer(particleBuffers[currentBufferIndex], offset: 0, index: 1)
            computeEncoder.setBuffer(particleBuffers[(currentBufferIndex + 1) % 2], offset: 0, index: 2)
            
            let threadsPerThreadgroup = MTLSize(width: computePipelineState.threadExecutionWidth, height: 1, depth: 1)
            let numThreadgroups = MTLSize(width: (numParticles + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width, height: 1, depth: 1)
            
            computeEncoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
            computeEncoder.endEncoding()
        }
        
        // 렌더 패스
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            renderEncoder.setRenderPipelineState(renderPipelineState)
            renderEncoder.setVertexBuffer(particleBuffers[(currentBufferIndex + 1) % 2], offset: 0, index: 0)
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 1)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount, instanceCount: numParticles)
            renderEncoder.endEncoding()
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        currentBufferIndex = (currentBufferIndex + 1) % 2
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // 필요 시 처리
    }
}

