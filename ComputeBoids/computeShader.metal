//
//  computeShader.metal
//  ComputeBoids
//
//  Created by gzonelee on 11/28/24.
//

#include <metal_stdlib>
using namespace metal;

struct Particle {
    float2 pos;
    float2 vel;
};

struct SimParams {
    float deltaT;
    float rule1Distance;
    float rule2Distance;
    float rule3Distance;
    float rule1Scale;
    float rule2Scale;
    float rule3Scale;
    uint numParticles; // 추가된 필드
};

kernel void computeShader(
    constant SimParams& params [[buffer(0)]],
    device const Particle* particlesA [[buffer(1)]],
    device Particle* particlesB [[buffer(2)]],
    uint id [[thread_position_in_grid]]
) {
    uint index = id;
    if (index >= params.numParticles) return;

    float2 vPos = particlesA[index].pos;
    float2 vVel = particlesA[index].vel;
    float2 cMass = float2(0.0);
    float2 cVel = float2(0.0);
    float2 colVel = float2(0.0);
    uint cMassCount = 0;
    uint cVelCount = 0;
    float2 pos;
    float2 vel;

    for (uint i = 0; i < params.numParticles; i++) {
        if (i == index) continue;
        pos = particlesA[i].pos;
        vel = particlesA[i].vel;
        float dist = distance(pos, vPos);
        if (dist < params.rule1Distance) {
            cMass += pos;
            cMassCount++;
        }
        if (dist < params.rule2Distance) {
            colVel -= (pos - vPos);
        }
        if (dist < params.rule3Distance) {
            cVel += vel;
            cVelCount++;
        }
    }
    if (cMassCount > 0) {
        cMass = (cMass / float(cMassCount)) - vPos;
    }
    if (cVelCount > 0) {
        cVel /= float(cVelCount);
    }
    vVel += (cMass * params.rule1Scale) + (colVel * params.rule2Scale) + (cVel * params.rule3Scale);
    // 속도 제한
    float speed = length(vVel);
    if (speed > 0.1) {
        vVel = normalize(vVel) * 0.1;
    }
    // 위치 업데이트
    vPos += vVel * params.deltaT;
    // 경계 처리
    if (vPos.x < -1.0) vPos.x += 2.0;
    if (vPos.x > 1.0) vPos.x -= 2.0;
    if (vPos.y < -1.0) vPos.y += 2.0;
    if (vPos.y > 1.0) vPos.y -= 2.0;
    // 결과 저장
    particlesB[index].pos = vPos;
    particlesB[index].vel = vVel;
}
