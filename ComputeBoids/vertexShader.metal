//
//  vertexShader.metal
//  ComputeBoids
//
//  Created by gzonelee on 11/28/24.
//

#include <metal_stdlib>
#include <metal_stdlib>
using namespace metal;

struct Particle {
    float2 pos;
    float2 vel;
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

vertex VertexOut vertexShader(
    uint vertexId [[vertex_id]],
    uint instanceId [[instance_id]],
    device const Particle* particles [[buffer(0)]],
    device const float2* vertexPositions [[buffer(1)]]
) {
    VertexOut out;
    float2 a_particlePos = particles[instanceId].pos;
    float2 a_particleVel = particles[instanceId].vel;
    float2 a_pos = vertexPositions[vertexId];
    
    float angle = -atan2(a_particleVel.x, a_particleVel.y);
    float cosAngle = cos(angle);
    float sinAngle = sin(angle);
    float2 pos;
    pos.x = (a_pos.x * cosAngle) - (a_pos.y * sinAngle);
    pos.y = (a_pos.x * sinAngle) + (a_pos.y * cosAngle);
    
    out.position = float4(pos + a_particlePos, 0.0, 1.0);
    out.color = float4(
        1.0 - sin(angle + 1.0) - a_particleVel.y,
        pos.x * 100.0 - a_particleVel.y + 0.1,
        a_particleVel.x + cos(angle + 0.5),
        1.0);
    return out;
}
