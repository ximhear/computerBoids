//
//  fragmentShader.metal
//  ComputeBoids
//
//  Created by gzonelee on 11/28/24.
//

#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
    return in.color;
}
