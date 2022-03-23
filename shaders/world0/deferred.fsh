#version 130

#include "/libs/setting.glsl"
#include "/libs/uniform.glsl"

uniform vec3 upVector;
uniform vec3 sunVector;
uniform vec3 moonVector;
uniform vec3 lightVector;
uniform vec3 worldUpVector;
uniform vec3 worldSunVector;
uniform vec3 worldMoonVector;
uniform vec3 worldLightVector;

#include "/libs/common.glsl"
#include "/libs/gbuffers_data.glsl"
#include "/libs/volumetric/atmospheric_common.glsl"
#include "/libs/volumetric/atmospheric.glsl"

in vec2 texcoord;

float t(in float z){
  if(0.0 <= z && z < 0.5) return 2.0*z;
  if(0.5 <= z && z < 1.0) return 2.0 - 2.0*z;
  return 0.0;
}

float R2Dither(in vec2 coord){
  float a1 = 1.0 / 0.75487766624669276;
  float a2 = 1.0 / 0.569840290998;

  return mod(coord.x * a1 + coord.y * a2, 1.0);
}

float ComputeAO(in vec3 P, in vec3 N, in vec3 S) {
    vec3 V = S - P;
    float vodtv = dot(V, V);
    float ndotv = dot(N, V) * inversesqrt(vodtv);

    float falloff = vodtv * -pow2(SSAO_Falloff) + 1.0;

    // Use saturate(x) instead of max(x,0.f) because that is faster
    return saturate(ndotv - SSAO_Bias) * saturate(falloff);
}

float ScreenSpaceAmbientOcclusion(in vec3 normal, in vec3 rayOrigin, in float dist) {
#if SSAO_Quality == OFF
    return 1.0;
#else
    int steps = SSAO_Rotation_Step;
    float invsteps = 1.0 / float(steps);

    int rounds = SSAO_Direction_Step;

    float ao = 0.0;

    float radius = SSAO_Radius / (float(rounds) * dist);

    float dither = R2Dither(ApplyTAAJitter(texcoord) * resolution * 0.5);

    rayOrigin += normal * 0.05;

    for(int j = 0; j < rounds; j++){
        for(int i = 0; i < steps; i++) {
            float a = (float(i) + dither) * invsteps * 2.0 * Pi;
            vec2 offset = vec2(cos(a), sin(a)) * (float(j + 1) * radius);

            vec2 offsetCoord = texcoord + offset;
            if(abs(offsetCoord.x - 0.5) >= 0.5 || abs(offsetCoord.y - 0.5) >= 0.5) continue;

            float offsetDepth = texture(depthtex0, offsetCoord).x;

            vec3 S = nvec3(gbufferProjectionInverse * nvec4(vec3(ApplyTAAJitter(offsetCoord), offsetDepth) * 2.0 - 1.0));

            ao += ComputeAO(rayOrigin, normal, S);
        }
    }

    return 1.0 - ao / (float(rounds) * float(steps));
#endif
}

void main() {
    Vector v = GetVector(texcoord, texture(depthtex0, texcoord).x);

    vec3 atmosphere_color = vec3(0.0);
    vec3 atmosphere_transmittance = vec3(1.0);

    CalculateAtmosphericScattering(atmosphere_transmittance, atmosphere_color, vec3(0.0, planet_radius + max(1.0, (cameraPosition.y - 63.0) * Altitude_Scale), 0.0), v.worldViewDirection, worldSunVector, vec2(0.0));

    vec3 normal = DecodeSpheremap(texture(colortex2, texcoord).rg);

    float ao = 1.0;
    
    if(v.depth < 0.9999) {
        ao = ScreenSpaceAmbientOcclusion(normal, v.vP, v.linearDepth);
    }

    gl_FragData[0] = vec4(atmosphere_color, ao);
    gl_FragData[1] = vec4(atmosphere_transmittance, v.depth);
}
/* DRAWBUFFERS:34 */