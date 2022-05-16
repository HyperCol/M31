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

void CalculatePlanetSurface(inout vec3 color, in vec3 sunColor, in vec3 moonColor, in vec3 L, in vec3 direction, in float h, in float t) {
    if(t <= 0.0) return;

    float cosTheta = dot(L, direction);

    float phaseMieSun = HG(cosTheta, 0.76);
    float phaseMieMoon = HG(-cosTheta, 0.76);
    float phaseRayleigh = (3.0 / 16.0 / Pi) * (1.0 + cosTheta * cosTheta);

    float Hr = exp(-h / rayleigh_distribution) * float(Near_Atmosphere_Density);
    float Hm = exp(-h / mie_distribution) * float(Near_Atmosphere_Density);

    vec3 Tr = Hr * (rayleigh_absorption + rayleigh_scattering);
    vec3 Tm = Hm * (mie_absorption + mie_scattering);

    float stepLength = t;
    vec3 transmittance = exp(-stepLength * (Tr + Tm) * 0.125);

    vec3 sunLight = sunColor * (phaseMieSun * Hm * mie_scattering + phaseRayleigh * Hr * rayleigh_scattering);
    vec3 moonLight = moonColor * (phaseMieMoon * Hm * mie_scattering + phaseRayleigh * Hr * rayleigh_scattering);

    color = (sunLight + moonLight) / (sum3(Tr + Tm) * Pi);
    //color = mix((sunLight + moonLight) / (Tr + Tm), color, transmittance);

    //color = LightColor0 * transmittance * (phaseMie.x * Hm * mie_scattering + phaseRayleigh * Hr * rayleigh_scattering) * invPi;
    //color += LightColor1 * transmittance * (phaseMie.y * Hm * mie_scattering + phaseRayleigh * Hr * rayleigh_scattering) * invPi;
}

float ComputeAO(in vec3 P, in vec3 N, in vec3 S) {
    vec3 V = S - P;
    float vodtv = dot(V, V);
    float ndotv = dot(N, V) * inversesqrt(vodtv);

    float falloff = vodtv * -pow2(SSAO_Falloff) + 1.0;

    // Use saturate(x) instead of max(x,0.f) because that is faster
    return saturate(ndotv - SSAO_Bias) * saturate(falloff);
}

float GetAO(in vec2 coord) {
    return texture(colortex3, coord).a;
}

float ScreenSpaceAmbientOcclusion(in Gbuffers m, in Vector v) {
#if SSAO_Quality == OFF
    return 1.0;
#else
    vec2 coord = texcoord * 0.375;

    float ao = 0.0;
    float totalWeight = 0.0;

    vec3 closest = vec3(0.0, 0.0, 1000.0);

    for(float i = -1.0; i <= 1.0; i += 1.0) {
        for(float j = -1.0; j <= 1.0; j += 1.0) {
            vec2 offset = vec2(i, j) * texelSize;
            vec2 offsetCoord = coord + offset;

            float sampleDepth = texture(colortex4, offsetCoord).a;

            float difference = abs(ExpToLinerDepth(sampleDepth) - v.linearDepth);

            if(difference < closest.z) {
                closest = vec3(offset, difference);
            }
        }
    }

    coord += closest.xy;

    #if SSAO_Quality < High
    float radius = 1.0;
    #else
    float radius = 2.0;
    #endif

    for(float i = -radius; i <= radius; i += 1.0) {
        for(float j = -radius; j <= radius; j += 1.0) {
            vec2 offsetCoord = coord + vec2(i, j) * texelSize;

            float sampleDepth = texture(colortex4, offsetCoord).a;

            float weight = 1.0 - saturate(abs(ExpToLinerDepth(sampleDepth) - v.linearDepth) * 16.0);
            if(i == 0.0 && j == 0.0) weight = 1.0;

            float sampleAO = texture(colortex3, offsetCoord).a;

            ao += sampleAO * weight;
            totalWeight += weight;
        }
    }

    ao /= totalWeight;

    return saturate(rescale(ao, 0.5, 1.0));
#endif
}

float ScreenSpaceContactShadow(in Gbuffers m, in Vector v, in vec3 LightDirection, in float material_bias) {
    float shading = 1.0;

    int steps = 8;
    float invsteps = 1.0 / float(steps);

    float ndotl = dot(LightDirection, m.geometryNormal);
    if(ndotl < 0.02 || material_bias > 0.0) return 1.0;

    float dist = ExpToLinerDepth(v.depth);
    float distanceStepLength = clamp((dist - shadowDistance * 0.25) / 2.0, 1.0, 16.0);

    vec3 bias = m.geometryNormal * (abs(LightDirection.z) * 50.0 + v.linearDepth) / 700.0;

    #ifdef MC_RENDER_QUALITY
    bias /= MC_RENDER_QUALITY;
    #endif

    float dither = R2Dither(ApplyTAAJitter(texcoord) * vec2(viewWidth, viewHeight));

    float maxLength = 0.2 * distanceStepLength;
    float thickness = 0.1 * distanceStepLength;

    vec3 direction = (LightDirection) * invsteps * maxLength;
    vec3 rayStart = v.vP;
    vec3 position = rayStart + direction * dither + bias;

    for(int i = 0; i < steps; i++) {
        vec3 coord = nvec3(gbufferProjection * nvec4(position)) * 0.5 + 0.5;
        if(abs(coord.x - 0.5) > 0.5 || abs(coord.y - 0.5) > 0.5) break;

        float sampleDepth = texture(depthtex0, coord.xy).x;

        float linearRay = ExpToLinerDepth(coord.z);
        float linearSample = ExpToLinerDepth(sampleDepth);

        float delta = linearRay - linearSample;

        if(delta > 0.0 && delta < thickness) {
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

    float screenSpaceShadow = m.maskHand > 0.5 ? 1.0 : ScreenSpaceContactShadow(m, v0, lightVector, simplesss) * m.selfShadow;

    vec3 shading = CalculateShading(vec3(texcoord, v0.depth), lightVector, m.geometryNormal, simplesss * 2.0);
         shading *= screenSpaceShadow;

    vec3 sunLightShading = DiffuseLighting(m, lightVector, v0.eyeDirection);
    
    if(dot(m.geometryNormal, lightVector) > 0.0) {
        sunLightShading += SpecularLighting(m, lightVector, v0.eyeDirection);
    }

    if(simplesss > 0.5 && m.material > 65.0) {
        sunLightShading += LeavesShading(lightVector, v0.eyeDirection, m.texturedNormal, m.albedo.rgb, m.transmittance, m.scattering);
    }

    float height = max(0.05, v0.wP.y + cameraPosition.y - 63.0);
    float halfHeight = mix(height, 2000.0, 0.1);
    vec3 Tfog = fog_scattering * mix(exp(-halfHeight / Fog_Exponential_Fog_Vaule) * Fog_Density * timeFog, exp(-halfHeight / Rain_Fog_Exponential_Fog_Vaule) * Rain_Fog_Density, rainStrength);

    float tracingFogSun = max(0.0, IntersectPlane(vec3(0.0, height, 0.0), worldLightVector, vec3(0.0, 2000.0, 0.0), vec3(0.0, 1.0, 0.0)));
    vec3 sunLightExtinction = min(CalculateFogLight(tracingFogSun, Tfog) / 0.999, vec3(1.0));

    float tracingFogUp = max(0.0, IntersectPlane(vec3(0.0, height, 0.0), worldUpVector, vec3(0.0, 2000.0, 0.0), vec3(0.0, 1.0, 0.0)));
    vec3 skyLightExtinction = min(CalculateFogLight(tracingFogUp, Tfog) / 0.999, vec3(1.0));

    vec3 cloudsShadow = vec3(1.0);

    #if Clouds_Shadow_Quality > OFF
        #if Clouds_Shadow_Quality < High
        cloudsShadow = CloudsShadow(v0.wP * Altitude_Scale, worldLightVector, origin, vec2(Clouds_Shadow_Tracing_Bottom, Clouds_Shadow_Tracing_Top), Clouds_Shadow_Transmittance, Clouds_Shadow_Quality);
        #else
        cloudsShadow = CloudsShadowRayMarching(v0.wP * Altitude_Scale, worldLightVector, origin, vec2(Clouds_Shadow_Tracing_Bottom, Clouds_Shadow_Tracing_Top), Clouds_Shadow_Transmittance, Clouds_Shadow_Quality);
        #endif
    #else
        cloudsShadow = vec3(mix(1.0, 0.5, rainStrength));
    #endif

    vec3 sunLight = sunLightShading * LightingColor * shading * cloudsShadow * shadowFade * sunLightExtinction;

    color += sunLight;

    float ao = ScreenSpaceAmbientOcclusion(m, v0);

    float SkyLighting0 = saturate(rescale(pow2(m.lightmap.y * m.lightmap.y), 0.7, 1.0)) * ao;
    float SkyLighting1 = pow2(m.lightmap.y) * m.lightmap.y * pow(ao, max((1.0 - m.lightmap.y) * 8.0, 1.0));
    float skylightMap = mix(SkyLighting0, SkyLighting1, 0.7);

    vec3 weatherLighting = SunLightingColor * Tfog * tracingFogSun * sunLightExtinction;

    vec3 weatherLighting2 = sunLight * weatherLighting * mix(HG(0.8, -0.1), HG(0.8, 0.7), 0.4);
    //color += weatherLighting2 * skylightMap;

    vec3 weatherLighting1 = invPi * m.albedo * weatherLighting * mix(HG(abs(worldSunVector.y), -0.1), HG(abs(worldSunVector.y), 0.7), 0.4);
    //color += weatherLighting1 * skylightMap * (1.0 - m.metal) * (1.0 - m.metallic);

    vec3 AmbientLightColor = SkyLightingColor;

    //vec3 SkyLighting = AmbientLightColor * rescale(dot(m.texturedNormal, upVector) * 0.5 + 0.5, -0.5, 1.0);

    float ndotl = dot(m.texturedNormal, sunVector);
    float nndotl = -ndotl;

    float lightLuminance = min(1.0, HG(0.95, 0.76));

    //vec3 SunGlowLighting = SunLightingColor * HG(ndotl, 0.76) * saturate(ndotl + 0.5) + MoonLightingColor * HG(nndotl, 0.76) * saturate(nndotl + 0.5);
    //     SunGlowLighting *= cloudsShadow;
    //     SunGlowLighting *= screenSpaceShadow * lightLuminance * 0.01;

    //vec3 AmbientLight = (SkyLighting + SunGlowLighting) * m.albedo * invPi;
    //     AmbientLight *= skylightMap * (1.0 - m.metal) * (1.0 - m.metallic);

    vec3 cloudsSkyOcclusion = vec3(1.0);

    #if Clouds_Sky_Occlusion_Quality > OFF
        #if Clouds_Sky_Occlusion_Quality < High
        cloudsSkyOcclusion = CloudsShadow(v0.wP * Altitude_Scale, worldUpVector, origin, vec2(Clouds_Sky_Occlusion_Tracing_Bottom, Clouds_Sky_Occlusion_Tracing_Top), Clouds_Sky_Occlusion_Transmittance, Clouds_Sky_Occlusion_Quality);
        #else
        cloudsSkyOcclusion = CloudsShadowRayMarching(v0.wP * Altitude_Scale, worldUpVector, origin, vec2(Clouds_Sky_Occlusion_Tracing_Bottom, Clouds_Sky_Occlusion_Tracing_Top), Clouds_Sky_Occlusion_Transmittance, Clouds_Sky_Occlusion_Quality);
        #endif
    #else
        cloudsSkyOcclusion = vec3(mix(1.0, 0.5, rainStrength));
    #endif

    //color += AmbientLight * skyLightExtinction * cloudsSkyOcclusion;

    vec3 msLighting = SunLightingColor * HG(ndotl, 0.76) + MoonLightingColor * HG(nndotl, 0.76);

    vec3 AmbientLight = AmbientLightColor + msLighting / 21.0;//HG(0.5, 0.76);

    color += AmbientLight * m.albedo * invPi * skylightMap * saturate(rescale(dot(m.texturedNormal, upVector), -1.5, 1.0));

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
         blockLight *= (1.0 / 4.0 * Pi) * m.lightmap.x * (blockLight0 + blockLight1) * (1.0 - m.metallic) * (1.0 - m.metal);

    color += blockLight;

    vec3 emissiveColor = m.albedo;
         emissiveColor *= invPi * m.emissive;// * (1.0 - SchlickFresnel(dot(v0.eyeDirection, normalize(v0.eyeDirection + normalize(reflect(v0.viewDirection, m.geometryNormal))))));

    color += emissiveColor;
    
    //color = cloudsShadow * SunLightingColor + cloudsSkyOcclusion * SkyLightingColor;
    //color *= 0.25 * invPi;
    //color = vec3(screenSpaceShadow);

    if(m.tile_mask == Mask_ID_Sky) {
        vec3 rayOrigin = vec3(0.0, planet_radius + max(1.0, (cameraPosition.y - 63.0) * Altitude_Scale), 0.0);
        vec3 rayDirection = v0.worldViewDirection;

        vec2 tracingAtmosphere = RaySphereIntersection(rayOrigin, rayDirection, vec3(0.0), atmosphere_radius);
        vec2 tracingPlanet = RaySphereIntersection(rayOrigin, rayDirection, vec3(0.0), planet_radius);

        color = vec3(0.0);

        float ndotl = dot(worldSunVector, rayDirection);
        color += step(tracingPlanet.x, 0.0) * step(0.9995, ndotl) * mix(1.0 / 21.0, 1.0, saturate(rescale(ndotl, 0.9995, 1.0))) * HG(0.95, 0.76) * Sun_Light_Luminance * 32.0;

        DrawStars(color, v0.worldViewDirection, starsFade, tracingPlanet.x);
        DrawMoon(color, worldMoonVector, v0.worldViewDirection, tracingPlanet.x);
        CalculatePlanetSurface(color, SunLightingColor, MoonLightingColor, worldSunVector, v0.worldViewDirection, 1000.0, tracingPlanet.x - max(0.0, tracingAtmosphere.x));

        vec2 tracingSun = RaySphereIntersection(rayOrigin + tracingPlanet.x * rayDirection, worldSunVector, vec3(0.0), atmosphere_radius);
        vec2 tracingMoon = RaySphereIntersection(rayOrigin + tracingPlanet.x * rayDirection, worldMoonVector, vec3(0.0), atmosphere_radius);
        float penmubra = (tracingSun.x > 0.0 ? 1.0 : exp(-tracingSun.y * 0.00001)) + (tracingMoon.x > 0.0 ? 1.0 : exp(-tracingMoon.y * 0.00001));
        //color += vec3(1.0) * invPi * step(0.0, tracingPlanet.x) * penmubra;

        vec2 halfcoord = min(texcoord * 0.375, vec2(0.375) - texelSize);

        vec3 atmosphere_transmittance = texture(colortex4, halfcoord).rgb;
        vec3 atmosphere_color = texture(colortex3, halfcoord).rgb;
        color = color * atmosphere_transmittance + atmosphere_color;
    }

    color *= MappingToSDR;
    color = GammaToLinear(color);

    //color = color / (color + 1.0);
    //color = GammaToLinear(color);

    gl_FragData[0] = vec4(texture(colortex0, texcoord).rgb, 0.0);
    gl_FragData[1] = vec4(color, ao);
    gl_FragData[2] = vec4(vec2(0.0), v0.depth, 1.0);
}
/* DRAWBUFFERS:034 */