#version 130

#include "/libs/setting.glsl"
#include "/libs/vertex_data_inout.glsl"
#include "/libs/uniform.glsl"
#include "/libs/common.glsl"
#include "/libs/gbuffers_data.glsl"
#include "/libs/lighting/brdf.glsl"
#include "/libs/volumetric/atmospheric_common.glsl"
#include "/libs/lighting/shadowmap_common.glsl"
#include "/libs/misc/night_sky.glsl"

uniform sampler2D colortex3;
uniform sampler2D colortex4;

uniform float centerDepthSmooth;

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

#include "/libs/lighting/shadowmap.glsl"

void CalculatePlanetSurface(inout vec3 color, in vec3 LightColor0, in vec3 LightColor1, in vec3 L, in vec3 direction, in float h, in float t) {
    if(t <= 0.0) return;

    float cosTheta = dot(L, direction);

    vec2 phaseMie = vec2(HG(cosTheta, 0.76), HG(-cosTheta, 0.76));
    float phaseRayleigh = (3.0 / 16.0 / Pi) * (1.0 + cosTheta * cosTheta);

    float Hr = exp(-h / rayleigh_distribution) * float(Near_Atmosphere_Density) * 4.0;
    float Hm = exp(-h / mie_distribution) * float(Near_Atmosphere_Density) * 4.0;

    vec3 Tr = Hr * (rayleigh_absorption + rayleigh_scattering);
    vec3 Tm = Hm * (mie_absorption + mie_scattering);

    float stepLength = min(40000.0, sqrt(pow2(t) + pow2(h)));
    vec3 transmittance = pow(exp(-stepLength * (Tr + Tm) * 0.25), vec3(0.8)) * stepLength;

    color = LightColor0 * transmittance * (phaseMie.x * Hm * mie_scattering + phaseRayleigh * Hr * rayleigh_scattering);
    color += LightColor1 * transmittance * (phaseMie.y * Hm * mie_scattering + phaseRayleigh * Hr * rayleigh_scattering);
}

float ComputeAO(in vec3 P, in vec3 N, in vec3 S) {
    vec3 V = S - P;
    float vodtv = dot(V, V);
    float ndotv = dot(N, V) * inversesqrt(vodtv);

    float falloff = vodtv * -pow2(SSAO_Falloff) + 1.0;

    // Use saturate(x) instead of max(x,0.f) because that is faster
    return saturate(ndotv - SSAO_Bias) * saturate(falloff);
}

float ScreenSpaceAmbientOcclusion(in Gbuffers m, in Vector v) {
    #if SSAO_Quality == OFF
    return 1.0;
    #else
    int steps = SSAO_Rotation_Step;
    float invsteps = 1.0 / float(steps);

    int rounds = SSAO_Direction_Step;

    if(m.maskHand > 0.9) return 1.0;

    float ao = 0.0;

    float radius = SSAO_Radius / (float(rounds) * v.viewLength);

    float dither = 0.5;//R2Dither(ApplyTAAJitter(texcoord) * resolution);

    for(int j = 0; j < rounds; j++){
        for(int i = 0; i < steps; i++) {
            float a = (float(i) + dither) * invsteps * 2.0 * Pi;
            vec2 offset = vec2(cos(a), sin(a)) * (float(j + 1) * radius);

            vec2 offsetCoord = texcoord + offset;
            //if(abs(offsetCoord.x - 0.5) >= 0.5 || abs(offsetCoord.y - 0.5) >= 0.5) break;

            float offsetDepth = texture(depthtex0, offsetCoord).x;

            vec3 S = nvec3(gbufferProjectionInverse * nvec4(vec3(ApplyTAAJitter(offsetCoord), offsetDepth) * 2.0 - 1.0));

            ao += ComputeAO(v.vP, m.texturedNormal, S);
            //ao += ComputeAO(v.vP, m.texturedNormal, S) * step(max(abs(offsetCoord.x - 0.5), abs(offsetCoord.y - 0.5)), 0.5);
        }
    }

    return 1.0 - ao / (float(rounds) * float(steps));
    
    #endif
}

float ScreenSpaceContactShadow(in Gbuffers m, in Vector v, in vec3 LightDirection, in float material_bias) {
    float shading = 1.0;

    int steps = 8;
    float invsteps = 1.0 / float(steps);

    float ndotl = dot(LightDirection, m.geometryNormal);
    if(ndotl < 0.02 || material_bias > 0.0) return 1.0;

    float dist = ExpToLinerDepth(v.depth);
    float distanceStepLength = clamp((dist - shadowDistance * 0.5) / 2.0, 1.0, 16.0);

    vec3 bias = m.geometryNormal / dot(LightDirection, m.geometryNormal) * dist / 500.0;

    float dither = R2Dither(ApplyTAAJitter(texcoord) * vec2(viewWidth, viewHeight));

    float maxLength = 0.2 * distanceStepLength;
    float thickness = 0.1 * distanceStepLength;

    vec3 direction = LightDirection * invsteps * maxLength;
    vec3 position = v.vP + direction * dither + bias;

    for(int i = 0; i < steps; i++) {
        vec3 sampleCoord = nvec3(gbufferProjection * nvec4(position)) * 0.5 + 0.5;
        if(abs(sampleCoord.x - 0.5) > 0.5 || abs(sampleCoord.y - 0.5) > 0.5) break;

        float testDepth = texture(depthtex0, sampleCoord.xy).x;

        if(sampleCoord.z > testDepth && ExpToLinerDepth(testDepth) + thickness > ExpToLinerDepth(sampleCoord.z)) {
            shading = 0.0;
            break;
        }

        position += direction;
    }

    return shading;
}

vec3 Diffusion(in float depth, in vec3 t) {
    return exp(-depth * t) / t / (4.0 * Pi);
}

vec3 LeavesShading(vec3 L, vec3 eye, vec3 n, vec3 albedo, vec3 sigma_t, vec3 sigma_s) {
    albedo = pow(albedo, vec3(0.9));

    float depth = 0.1;

    vec3 R = exp(-sigma_t * depth);

    float mu = dot(L, -eye);
    float phase = mix(HG(mu, -0.1), HG(mu, 0.5), 0.7);

    float ndotl = max(0.0, dot(L, n));

    return (R * albedo) * (invPi * phase * (1.0 - ndotl));
}

#include "/libs/noise.glsl"
#include "/libs/volumetric/clouds_common.glsl"
#include "/libs/volumetric/clouds_env.glsl"

void main() {
    //material
    Gbuffers    m = GetGbuffersData(texcoord);

    //opaque
    Vector      v0 = GetVector(texcoord, texture(depthtex0, texcoord).x);

    AtmosphericData atmospheric = GetAtmosphericDate(timeFog, timeHaze);

    vec3 color = vec3(0.0);

    vec3 origin = vec3(cameraPosition.x, cameraPosition.y - 63.0, cameraPosition.z) * Altitude_Scale;
         origin.y = planet_radius + origin.y;


    float simplesss = m.fullBlock < 0.5 && m.material > 65.0 ? 1.0 : 0.0;

    vec3 shading = CalculateShading(vec3(texcoord, v0.depth), lightVector, m.geometryNormal, simplesss * 2.0);
         shading *= ScreenSpaceContactShadow(m, v0, lightVector, simplesss);

    vec3 sunLight = DiffuseLighting(m, lightVector, v0.eyeDirection) + SpecularLighting(m, lightVector, v0.eyeDirection);

    if(simplesss > 0.5 && m.material > 65.0) {
        sunLight += LeavesShading(lightVector, v0.eyeDirection, m.texturedNormal, m.albedo.rgb, m.transmittance, m.scattering);
    }

    float tracingFogSun = max(0.0, IntersectPlane(vec3(0.0, v0.wP.y + cameraPosition.y - 63.0, 0.0), worldLightVector, vec3(0.0, atmospheric.fogHeight, 0.0), vec3(0.0, 1.0, 0.0)));
    vec3 sunLightExtinction = min(vec3(1.0), CalculateFogLight(tracingFogSun, atmospheric.fogTransmittance) * CalculateFogPhaseFunction(1.0 - 1e-5, atmospheric) / HG(0.9, 0.76));

    #if Clouds_Shadow_Quality > OFF
        #if Clouds_Shadow_Quality < High
        shading *= CloudsShadow(v0.wP * Altitude_Scale, worldLightVector, origin, vec2(Clouds_Shadow_Tracing_Bottom, Clouds_Shadow_Tracing_Top), Clouds_Shadow_Transmittance, Clouds_Shadow_Quality);
        #else
        shading *= CloudsShadowRayMarching(v0.wP * Altitude_Scale, worldLightVector, origin, vec2(Clouds_Shadow_Tracing_Bottom, Clouds_Shadow_Tracing_Top), Clouds_Shadow_Transmittance, Clouds_Shadow_Quality);
        #endif
    #endif

    color += sunLight * LightingColor * shading * shadowFade * sunLightExtinction;

    float tracingFogUp = max(0.0, IntersectPlane(vec3(0.0, v0.wP.y + cameraPosition.y - 63.0, 0.0), worldUpVector, vec3(0.0, atmospheric.fogHeight, 0.0), vec3(0.0, 1.0, 0.0)));
    vec3 skyLightExtinction = CalculateFogLight(tracingFogUp, atmospheric.fogTransmittance);

    float ao = ScreenSpaceAmbientOcclusion(m, v0);

    float SkyLighting0 = saturate(rescale(ao * pow2(m.lightmap.y * m.lightmap.y), 0.7, 1.0));
    float SkyLighting1 = pow2(m.lightmap.y) * m.lightmap.y * pow(ao, max((1.0 - m.lightmap.y) * 8.0, 1.0));

    vec3 AmbientLightColor = SkyLightingColor;
         AmbientLightColor += LightingColor * atmospheric.fogScattering * (tracingFogUp * 0.5) * CalculateFogPhaseFunction(worldLightVector.y, atmospheric);

    vec3 AmbientLight = vec3(0.0);
         AmbientLight += m.albedo * LightingColor * (saturate(dot(m.texturedNormal, sunVector)) * HG(dot(m.texturedNormal, sunVector), 0.1) * HG(0.5, 0.76) * invPi);
         AmbientLight += m.albedo * AmbientLightColor * (rescale(dot(m.texturedNormal, upVector) * 0.5 + 0.5, -0.5, 1.0) * invPi);
         AmbientLight *= mix(SkyLighting0, SkyLighting1, 0.7) * (1.0 - m.metal) * (1.0 - m.metallic);

    #if Clouds_Sky_Occlusion_Quality > OFF
        #if Clouds_Sky_Occlusion_Quality < High
        AmbientLight *= CloudsShadow(v0.wP, worldUpVector, origin, vec2(Clouds_Sky_Occlusion_Tracing_Bottom, Clouds_Sky_Occlusion_Tracing_Top), Clouds_Sky_Occlusion_Transmittance, Clouds_Sky_Occlusion_Quality);
        #else
        AmbientLight *= CloudsShadowRayMarching(v0.wP, worldUpVector, origin, vec2(Clouds_Sky_Occlusion_Tracing_Bottom, Clouds_Sky_Occlusion_Tracing_Top), Clouds_Sky_Occlusion_Transmittance, Clouds_Sky_Occlusion_Quality);
        #endif
    #endif

    color += AmbientLight * skyLightExtinction;

    vec3 handHeldLight = m.albedo * invPi * BlockLightingColor * (float(heldBlockLightValue) + float(heldBlockLightValue2)) / 15.0;

    #if Held_Light_Quality == High
    vec3 handOffset = nvec3(gbufferProjectionInverse * nvec4(vec3(1.0, 0.5, 0.0) * 2.0 - 1.0)) * vec3(1.0, 1.0, 0.0);
    if(m.tile_mask == MaskIDHand) handOffset = vec3(0.0);

    vec3 lP1 = v0.vP - handOffset * 4.0;
    vec3 lP2 = v0.vP + handOffset * 4.0;

    float heldLightDistance1 = min(3.0, 1.0 / pow2(length(lP1)));
    float heldLightDistance2 = min(3.0, 1.0 / pow2(length(lP2)));

    lP1 = normalize(lP1);
    lP2 = normalize(lP2);

    vec3 heldLight1  = BlockLightingColor * SpecularLighting(m, -lP1, v0.eyeDirection) * heldLightDistance1;
         heldLight1 += BlockLightingColor * DiffuseLighting(m, -lP1, v0.eyeDirection) * max(0.0, rescale(heldLightDistance1, 1e-3, 1.0));
         heldLight1 *= float(heldBlockLightValue) / 15.0;
    
    vec3 heldLight2  = BlockLightingColor * SpecularLighting(m, -lP2, v0.eyeDirection) * heldLightDistance2;
         heldLight2 += BlockLightingColor * DiffuseLighting(m, -lP2, v0.eyeDirection) * max(0.0, rescale(heldLightDistance2, 1e-3, 1.0)) * 6.0;
         heldLight2 *= float(heldBlockLightValue2) / 15.0;

    color += heldLight1 + heldLight2;
    #else
    float heldLightDistance = min(3.0, 1.0 / pow2(v0.viewLength));

    vec3 heldLight  = BlockLightingColor * SpecularLighting(m, v0.eyeDirection, v0.eyeDirection) * heldLightDistance;
         heldLight += BlockLightingColor * DiffuseLighting(m, v0.eyeDirection, v0.eyeDirection) * max(0.0, rescale(heldLightDistance, 1e-3, 1.0)) * 6.0;
         heldLight *= max(float(heldBlockLightValue), float(heldBlockLightValue2)) / 15.0;
    
    color += heldLight;
    #endif

    float blockLight0 = (m.lightmap.x * m.lightmap.x * m.lightmap.x) * (ao * ao * ao);
    float blockLight1 = 1.0 / pow2(max(1.0, (1.0 - m.lightmap.x) * 15.0));

    vec3 blockLight = (BlockLightingColor * m.albedo);
         blockLight *= (1.0 / 4.0 * Pi) * m.lightmap.x * (blockLight0 + blockLight1) * (1.0 - m.metallic) * (1.0 - m.metal) * (1.0 - m.emissive);

    color += blockLight;

    vec3 emissiveColor = m.albedo;
         emissiveColor *= invPi * m.emissive;// * (1.0 - SchlickFresnel(dot(v0.eyeDirection, normalize(v0.eyeDirection + normalize(reflect(v0.viewDirection, m.geometryNormal))))));

    color += emissiveColor;
    
    if(m.tile_mask == Mask_ID_Sky) {
        vec3 rayOrigin = vec3(0.0, planet_radius + max(1.0, (cameraPosition.y - 63.0) * Altitude_Scale), 0.0);
        vec3 rayDirection = v0.worldViewDirection;

        vec2 tracingAtmosphere = RaySphereIntersection(rayOrigin, rayDirection, vec3(0.0), atmosphere_radius);
        vec2 tracingPlanet = RaySphereIntersection(rayOrigin, rayDirection, vec3(0.0), planet_radius);

        color = vec3(0.0);

        DrawStars(color, v0.worldViewDirection, starsFade, tracingPlanet.x);
        DrawMoon(color, worldMoonVector, v0.worldViewDirection, tracingPlanet.x);
        CalculatePlanetSurface(color, SunLightingColor, MoonLightingColor, worldSunVector, v0.worldViewDirection, 1000.0, tracingPlanet.x - max(0.0, tracingAtmosphere.x));

        vec2 tracingSun = RaySphereIntersection(rayOrigin + tracingPlanet.x * rayDirection, worldSunVector, vec3(0.0), atmosphere_radius);
        vec2 tracingMoon = RaySphereIntersection(rayOrigin + tracingPlanet.x * rayDirection, worldMoonVector, vec3(0.0), atmosphere_radius);
        float penmubra = (tracingSun.x > 0.0 ? 1.0 : exp(-tracingSun.y * 0.00001)) + (tracingMoon.x > 0.0 ? 1.0 : exp(-tracingMoon.y * 0.00001));
        //color += vec3(1.0) * invPi * step(0.0, tracingPlanet.x) * penmubra;

        vec2 halfcoord = min(texcoord * 0.5 + texelSize, vec2(0.5) - texelSize);

        vec3 atmosphere_transmittance = texture(colortex4, halfcoord).rgb;
        vec3 atmosphere_color = texture(colortex3, halfcoord).rgb;
        color = color * atmosphere_transmittance + atmosphere_color;
    }

    color *= MappingToSDR;
    color = GammaToLinear(color);

    //color = color / (color + 1.0);
    //color = GammaToLinear(color);

    gl_FragData[0] = vec4(texture(colortex0, texcoord).rgb, 0.0);
    gl_FragData[1] = vec4(color, texture(colortex1, texcoord).r);
    //gl_FragData[1] = vec4(texture(gnormal, texcoord).zw, v.depth, 1.0);
    gl_FragData[2] = vec4(vec2(0.0), v0.depth, 1.0);
}
/* DRAWBUFFERS:034 */