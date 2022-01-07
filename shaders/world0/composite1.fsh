#version 130

uniform sampler2D colortex3;
uniform sampler2D colortex4;

uniform sampler2D colortex11;

const bool colortex11Clear = false;

#include "/libs/setting.glsl"
#include "/libs/common.glsl"
#include "/libs/uniform.glsl"
#include "/libs/vertex_data_inout.glsl"
#include "/libs/gbuffers_data.glsl"
#include "/libs/noise.glsl"
#include "/libs/lighting/brdf.glsl"
#include "/libs/lighting/shadowmap_common.glsl"

float t(in float z){
    if(0.0 <= z && z < 0.5) return 2.0*z;
    if(0.5 <= z && z < 1.0) return 2.0 - 2.0*z;
    return 0.0;
}

float R2Dither(in vec2 coord){
    float a1 = 1.0 / 0.75487766624669276;
    float a2 = 1.0 / 0.569840290998;

    return t(mod(coord.x * a1 + coord.y * a2, 1.0));
}

#include "/libs/lighting/shadowmap.glsl"

struct WaterData {
    float istranslucent;
    //float isblocks;
    float cutout;

    float TileMask;

    float water;
    //float ice;
    float slime_block;
    float honey_block;
    //float glass;
    ////float glass_pane;
    ////float stained_glass;
    ////float stained_glass_pane;
};

WaterData GetWaterData(in vec2 coord) {
    WaterData w;

    w.istranslucent = texture(colortex0, coord).a;
    //w.isblocks = 

    w.TileMask  = w.istranslucent > 0.9 ? round(texture(colortex2, coord).b * 65535.0) : 0.0;
    w.water     = MaskCheck(w.TileMask, Water);
    w.slime_block = MaskCheck(w.TileMask, SlimeBlock);
    w.honey_block = MaskCheck(w.TileMask, HoneyBlock);
    w.cutout      = MaskCheck(w.TileMask, Glass) + MaskCheck(w.TileMask, GlassPane);

    return w;
}

struct WaterBackface {
    vec3 normal;
    float depth;
    float linearDepth;
};

WaterBackface GetWaterBackfaceData(in vec2 coord) {
    WaterBackface w;

    w.normal = DecodeSpheremap(texture(colortex4, coord).rg);

    w.depth = texture(colortex4, coord).z;
    w.linearDepth = ExpToLinerDepth(w.depth);

    return w;
}

vec3 Diffusion(in float depth, in vec3 t) {
    return exp(-depth * t) / (4.0 * Pi * t * max(1.0, depth));
}

float CalculateSmallBlockDensity(in WaterData t, in vec3 halfVector, vec3 offset) {
    const float Tile = 0.0625;

    float density = 0.0;

    float dist = maxComponent(abs(halfVector - offset)) * 2.0;

    if(t.slime_block > 0.9) {
        density += (dist < Tile * 10.0 ? Small_SlimeBlock_Density : 0.0);
    }else if(t.honey_block > 0.9) {
        density += (dist < Tile * 14.0 ? Small_HoneyBlock_Density : 0.0);
    }

    return density;
}
#if 1
void CalculateSubSurfaceScattering(inout vec3 color, in Gbuffers m, in WaterData t, in Vector v, in vec3 blockCenter, in float backDepth) {
    int steps = 8;
    float invsteps = 1.0 / float(steps);

    vec3 scatt = vec3(0.0);
    vec3 trans = vec3(1.0);

    float dither = R2Dither(ApplyTAAJitter(texcoord) * resolution + vec2(frameTimeCounter * 45.0 * 0.0, 0.0));

    vec3 viewBorder = vec3( abs(IntersectPlane(vec3(0.0), v.worldViewDirection, vec3(far + 16.0, 0.0, 0.0), vec3(1.0, 0.0, 0.0))),
                            0.0,
                            abs(IntersectPlane(vec3(0.0), v.worldViewDirection, vec3(0.0, 0.0, far + 16.0), vec3(0.0, 0.0, 1.0))));

    float end = backDepth;
    float start = v.viewLength; 

    if(end <= start) return;

    //end = min(min(viewBorder.x, viewBorder.z), end);

    float stepLength = end - start;
    stepLength = min(stepLength, 48.0);

    stepLength = stepLength + m.alpha * 0.5;
    stepLength *= invsteps;

    vec3 rayOrigin = v.wP;
    vec3 rayDirection = v.worldViewDirection * stepLength;

    vec3 rayPosition = rayOrigin + rayDirection * dither;

    float phase = mix(HG(dot(lightVector, v.viewDirection), -0.1), HG(dot(lightVector, v.viewDirection), 0.5), 0.3);

    vec3 SunLight = LightingColor * phase * invPi;
    vec3 AmbientLight = SkyLightingColor * (pow2(m.lightmap.y) * m.lightmap.y) * 0.047;

    for(int i = 0; i < steps; i++) {
        vec2 tracingLight = IntersectCube(rayPosition + cameraPosition, worldLightVector, blockCenter, vec3(0.5));

        vec3 lightExtinction = vec3(1.0);

        vec3 shadowViewStepPosition = mat3(shadowModelView) * (rayPosition + (m.fullBlock > 0.5 ? worldLightVector * max(0.0, tracingLight.y) : vec3(0.0))) + shadowModelView[3].xyz;
        vec3 shadowCoord = vec3(shadowProjection[0].x, shadowProjection[1].y, shadowProjection[2].z) * shadowViewStepPosition + shadowProjection[3].xyz;
        vec2 shadowCoordOrigin = shadowCoord.xy;
        float distortion = ShadowMapDistortion(shadowCoord.xy);
             shadowCoord.xy *= distortion;
             shadowCoord = RemapShadowCoord(shadowCoord);
             shadowCoord = shadowCoord * 0.5 + 0.5;

        bool inShadowMap = abs(shadowCoord.x - 0.5) < 0.5 && abs(shadowCoord.y - 0.5) < 0.5;
        float visibility = inShadowMap ? step(shadowCoord.z - shadowTexelSize, texture(shadowtex1, shadowCoord.xy).x) : 1.0;


        if(inShadowMap && m.fullBlock < 0.5 && distortion > 2.0) {
            vec3 shadowViewPosition = vec3(shadowProjectionInverse[0].x, shadowProjectionInverse[1].y, shadowProjectionInverse[2].z) * vec3(shadowCoordOrigin, (texture(shadowtex0, shadowCoord.xy).x * 2.0 - 1.0) / Shadow_Depth_Mul) + shadowProjectionInverse[3].xyz;

            float opticalDepth = max(length(shadowViewStepPosition - shadowViewPosition) - 0.01, 0.0);
            lightExtinction = exp(-m.transmittance * opticalDepth);
        } else {
            lightExtinction = exp(-m.transmittance * max(0.0, tracingLight.y));
        }

        /*
        if(m.fullBlock < 0.5) {
            vec3 shadowViewPosition = vec3(shadowProjectionInverse[0].x, shadowProjectionInverse[1].y, shadowProjectionInverse[2].z) * vec3(shadowCoordOrigin, (texture(shadowtex0, shadowCoord.xy).x * 2.0 - 1.0) / Shadow_Depth_Mul) + shadowProjectionInverse[3].xyz;

            vec3 albedo = LinearToGamma(texture(shadowcolor0, shadowCoord.xy).rgb);
            float alpha = max(0.0, texture(shadowcolor0, shadowCoord.xy).a - 0.2) / 0.8;

            vec2 coe = unpack2x4(texture(shadowcolor1, shadowCoord.xy).a);
            float absorption0 = coe.x * 15.0 * alpha;
            float scattering0 = (1.0 - coe.y) * 16.0 * alpha;
            vec3 lightViewA = absorption0 * (1.0 - clamp(pow(albedo + 1e-5, vec3(1.0 / 2.718)), vec3(1e-3), vec3(0.9)));

            float opticalDepth = max(length(shadowViewStepPosition - shadowViewPosition) - 0.01, 0.0);
            lightExtinction = exp(-(lightViewA * opticalDepth + scattering0 * opticalDepth));
        } else {
            lightExtinction = exp(-m.transmittance * max(0.0, tracingLight.y));
        }
        */

        float density = 1.0;
        density += CalculateSmallBlockDensity(t, rayPosition + cameraPosition - blockCenter, vec3(0.0));
        
        if(length(rayPosition) < end){
            density +=  CalculateSmallBlockDensity(t, rayPosition + cameraPosition - blockCenter, vec3(0.0, 1.0, 0.0))
                      + CalculateSmallBlockDensity(t, rayPosition + cameraPosition - blockCenter, vec3(1.0, 0.0, 0.0))
                      + CalculateSmallBlockDensity(t, rayPosition + cameraPosition - blockCenter, vec3(0.0, 0.0, 1.0))
                      + CalculateSmallBlockDensity(t, rayPosition + cameraPosition - blockCenter, vec3(0.0, -1.0, 0.0))
                      + CalculateSmallBlockDensity(t, rayPosition + cameraPosition - blockCenter, vec3(-1.0, 0.0, 0.0))
                      + CalculateSmallBlockDensity(t, rayPosition + cameraPosition - blockCenter, vec3(0.0, 0.0, -1.0));
        }
        
        vec3 stepTransmittance = exp(-stepLength * density * m.transmittance);

        vec3 L = SunLight * lightExtinction * visibility + AmbientLight * trans;

        scatt += (L - L * stepTransmittance) * trans / (density * 2.0) * density;
        trans *= stepTransmittance;

        rayPosition += rayDirection;
    }

    vec3 scatteringColor = (scatt / m.transmittance * m.scattering * m.albedo);

    color *= m.fullBlock > 0.5 ? vec3(1.0) : trans;
    color += scatteringColor;
}
#endif
void CalculateTranslucent(inout vec3 color, in Gbuffers m, in WaterData t, in Vector v, in Vector v1, in vec2 coord) {
    WaterBackface back = GetWaterBackfaceData(coord);

    vec3 worldNormal = mat3(gbufferModelViewInverse) * m.geometryNormal;
    vec3 worldPosition = v.wP + cameraPosition;
    vec3 blockCenter = floor(worldPosition - worldNormal * 0.1) + 0.5;
    vec2 tracing = IntersectCube(worldPosition, v.worldViewDirection, blockCenter, vec3(0.5));

    float formBackFaceDepth = length(nvec3(gbufferProjectionInverse * nvec4(vec3(texcoord, back.depth) * 2.0 - 1.0)));
    float formVirtualBlock = tracing.y + v.viewLength;
    float backDepth = m.fullBlock > 0.9 ? formVirtualBlock : formBackFaceDepth;

    if(t.water > 0.1) {
        float tracing1 = abs(IntersectPlane(v1.wP + cameraPosition, v.worldViewDirection, vec3(0.0, blockCenter.y, 0.0), vec3(0.0, 1.0, 0.0)));
        float tracing2 = max(0.0, IntersectPlane(v1.wP + cameraPosition, worldLightVector, vec3(0.0, blockCenter.y, 0.0), vec3(0.0, 1.0, 0.0)));
        float depth = mix(tracing1, tracing2, 0.05);

        color *= (exp(-depth * m.transmittance) + exp(-depth * m.transmittance * 0.25) * 0.7) / (1.7);
    }

    float cutoutAlpha = step(m.alpha, 0.2);

    if(t.cutout > 0.5) {
        color *= cutoutAlpha;
    }

    if(m.material > 64.5 && (m.maskWater > 0.5 || m.fullBlock > 0.5)) {
        CalculateSubSurfaceScattering(color, m, t, v, blockCenter, backDepth);
    }
    
    if(t.istranslucent > 0.9) {
        vec3 diffuse = DiffuseLighting(m, lightVector, v.eyeDirection);
        vec3 specular = SpecularLighting(m, lightVector, v.eyeDirection);
        vec3 BlocksLight = (m.albedo) * (0.25 * Pi * m.lightmap.x * (m.lightmap.x * m.lightmap.x * m.lightmap.x) * (1.0 - m.metallic) * (1.0 - m.metal) * (1.0 - m.emissive));
        vec3 SkyLight = (m.albedo * SkyLightingColor) * (rescale(dot(m.texturedNormal, upVector) * 0.5 + 0.5, -0.5, 1.0) * pow2(m.lightmap.y) * m.lightmap.y * invPi);

        vec3 heldLightDiffuse = vec3(0.0);
        vec3 heldLightSpecluar = vec3(0.0);

        #if Held_Light_Quality == High
            vec3 handOffset = nvec3(gbufferProjectionInverse * nvec4(vec3(1.0, 0.5, 0.0) * 2.0 - 1.0)) * vec3(1.0, 1.0, 0.0);
            if(m.tile_mask == MaskIDHand) handOffset = vec3(0.0);

            vec3 lP1 = o.vP - handOffset * 4.0;
            vec3 lP2 = o.vP + handOffset * 4.0;

            float heldLightDistance1 = min(3.0, 1.0 / pow2(length(lP1))) * float(heldBlockLightValue) / 15.0 * 6.0;
            float heldLightDistance2 = min(3.0, 1.0 / pow2(length(lP2))) * float(heldBlockLightValue2) / 15.0 * 6.0;

            lP1 = normalize(lP1);
            lP2 = normalize(lP2);

            heldLightSpecluar += SpecularLighting(m, -lP1, v.eyeDirection) * heldLightDistance1;
            heldLightDiffuse  += DiffuseLighting(m, -lP1, v.eyeDirection) * max(0.0, rescale(heldLightDistance1, 1e-5, 1.0));

            heldLightSpecluar += SpecularLighting(m, -lP2, v.eyeDirection) * heldLightDistance2;
            heldLightDiffuse  += DiffuseLighting(m, -lP2, v.eyeDirection) * max(0.0, rescale(heldLightDistance2, 1e-5, 1.0));
        #else
            float heldLightDistance = min(3.0, 1.0 / pow2(v.viewLength)) * max(float(heldBlockLightValue), float(heldBlockLightValue2)) / 15.0 * 6.0;

            heldLightSpecluar = SpecularLighting(m, v.eyeDirection, v.eyeDirection) * heldLightDistance;
            heldLightDiffuse  = DiffuseLighting(m, v.eyeDirection, v.eyeDirection) * max(0.0, rescale(heldLightDistance, 1e-5, 1.0));
        #endif    

        vec3 shading = CalculateShading(vec3(texcoord, v.depth), lightVector, m.geometryNormal, 0.0) * LightingColor * shadowFade;

        if(m.maskWater > 0.5) {
            vec3 s = m.scattering * m.alpha * 0.1;
            
            float cutoutBlend = t.cutout * (1.0 - cutoutAlpha);
            s = mix(s, vec3(1.0), vec3(cutoutBlend));

            diffuse *= s;
            heldLightDiffuse *= s;

            SkyLight *= cutoutBlend;
        }else{
            color = vec3(0.0);
        }

        if(m.maskWeather > 0.5) {
            specular = vec3(0.0);

            float theta = dot(lightVector, v.viewDirection);
            float phase = mix(HG(theta, 0.1), HG(theta, 0.9), 0.2);

            diffuse = m.albedo * phase * invPi;
        }

        //float tracingFogSun = max(0.0, IntersectPlane(vec3(0.0, v.wP.y + cameraPosition.y - 63.0, 0.0), worldLightVector, vec3(0.0, 1000.0, 0.0), vec3(0.0, 1.0, 0.0)));
        //vec3 sunLightExtinction = exp(-tracingFogSun * vec3(0.003) * 0.9);
        //shading *= sunLightExtinction;

        //float tracingFogUp = max(0.0, IntersectPlane(vec3(0.0, v.wP.y + cameraPosition.y - 63.0, 0.0), worldUpVector, vec3(0.0, 1000.0, 0.0), vec3(0.0, 1.0, 0.0)));
        //vec3 skyLightExtinction = exp(-tracingFogUp * vec3(0.003) * 0.3);
        //SkyLight *= skyLightExtinction;

        color += specular * shading;
        color += diffuse * shading;
        color += SkyLight;
        color += BlockLightingColor * (BlocksLight + heldLightDiffuse + heldLightSpecluar);
    }
}

/*
vec3 CalculateRefraction(in Gbuffers m, in WaterData w, in Vector v, in Vector v1, in vec2 coord) {
    WaterBackface back = GetWaterBackfaceData(coord);

    vec3 color = texture(colortex3, coord).rgb;

    if(m.maskWater > 0.9) {
        vec3 direction = normalize(refract(v.viewDirection, m.texturedNormal, 1.000293 / F0ToIOR(max(0.02, m.metallic))));
        float rayLength = w.water > 0.9 ? clamp(v1.linearDepth - v.linearDepth, 0.0, 1.0) : max(0.0, back.linearDepth - v.linearDepth);

        vec3 rayDirection = v.vP + direction * rayLength;
        vec2 refractionCoord = nvec3(gbufferProjection * nvec4(v.vP + direction * rayLength)).xy * 0.5 + 0.5;

        color = texture(colortex3, refractionCoord).rgb;

        vec3 transmittance = exp(-rayLength * 8.0 * (m.scattering + m.absorption));
        color *= transmittance;
    }

    return color;
}
*/
#include "/libs/volumetric/atmospheric_common.glsl"
#if 0
void LandAtmosphericScattering(inout vec3 color, in Vector v, in AtmosphericData atmospheric, bool isSky) {
    //color = vec3(0.0);

    #if Near_Atmosphere_Quality == Ultra
    int steps = 16;
    float invsteps = 1.0 / float(steps);
    #elif Near_Atmosphere_Quality == High
    int steps = 8;
    float invsteps = 1.0 / float(steps);
    #else
    int steps = 4;
    float invsteps = 1.0 / float(steps);
    #endif

    float start = 0.0;
    float end = isSky ? 1500.0 : v.viewLength;

    float stepLength = (end - start) * invsteps;

    float dither = R2Dither(ApplyTAAJitter(texcoord) * resolution);

    vec3 direction = v.worldViewDirection;
    vec3 origin = cameraPosition + direction * stepLength * dither;

    vec3 scattering = vec3(0.0);
    vec3 transmittance = vec3(1.0);

    float theta = dot(direction, worldSunVector);
    float phaseRayleigh = (3.0 / 16.0 / Pi) * (1.0 + theta * theta);
    float phaseMieSun = HG(theta, 0.76);
    float phaseMieMoon = HG(-theta, 0.76);

    vec3 MieLightColor = SunLightingColor * phaseMieSun + MoonLightingColor * phaseMieMoon;
    vec3 RayleighLightColor = LightingColor * phaseRayleigh;

    float fogPhaseSun = mix(HG(theta, Fog_Eccentricity), HG(theta, atmospheric.fogSilverSpread) * atmospheric.fogSilverIntensity, atmospheric.fogFrontScattering);
    float fogPhaseMoon = mix(HG(-theta, Fog_Eccentricity), HG(-theta, atmospheric.fogSilverSpread) * atmospheric.fogSilverIntensity, atmospheric.fogFrontScattering);

    vec3 FogSunLightColor = SunLightingColor * fogPhaseSun;
    vec3 FogMoonLightColor =  MoonLightingColor * fogPhaseMoon;
    vec3 FogDirectLightColor = FogSunLightColor + FogMoonLightColor;

    vec3 opticalDepth = vec3(0.0);

    for(int i = 0; i < steps; i++) {
        vec3 rayPosition = origin + direction * (float(i) * stepLength);

        vec3 shadowCoord = WorldPositionToShadowCoord(rayPosition - cameraPosition);
        float visibility = abs(shadowCoord.x - 0.5) >= 0.5 || abs(shadowCoord.y - 0.5) >= 0.5 || shadowCoord.z + 1e-5 > 1.0 ? 1.0 : step(shadowCoord.z, texture(shadowtex0, shadowCoord.xy).x);
        float vRayleigh = mix(visibility, 1.0, 0.1);
        float vMie = mix(visibility, 1.0, 0.05);

        float height = max(rayPosition.y - 63.0, 0.0);

        float Hr = exp(-height * Near_Atmosphere_Distribution / rayleigh_distribution) * Near_Atmosphere_Density;
        vec3 Tr = (rayleigh_scattering + rayleigh_absorption) * Hr;

        float Hm = exp(-height * Near_Atmosphere_Distribution / mie_distribution) * Near_Atmosphere_Density;
        vec3 Tm = (mie_scattering + mie_absorption) * Hm;

        float Hfog = saturate((atmospheric.fogHeight - height) / atmospheric.fogDistribution);
        vec3 Tfog = atmospheric.fogTransmittance * Hfog;

        vec3 stepTransmittance = exp(-(Tr + Tm + Tfog) * stepLength);
        vec3 inverseTransmittance = 1.0 / max(vec3(1e-8), Tr + Tm + Tfog);

        //atmospheric scattering
        scattering += (RayleighLightColor - RayleighLightColor * stepTransmittance) * transmittance * inverseTransmittance * rayleigh_scattering * Hr * vRayleigh;
        scattering += (MieLightColor - MieLightColor * stepTransmittance) * transmittance * inverseTransmittance * mie_scattering * Hm * vMie;

        //fog
        float tracingFogSun = IntersectPlane(vec3(0.0, height, 0.0), worldSunVector, vec3(0.0, atmospheric.fogHeight, 0.0), vec3(0.0, 1.0, 0.0));
        float tracingFogMoon = max(0.0, -tracingFogSun); 
        float tracingFogUp = max(0.0, IntersectPlane(vec3(0.0, height, 0.0), worldUpVector, vec3(0.0, atmospheric.fogHeight, 0.0), vec3(0.0, 1.0, 0.0)));
              tracingFogSun = max(0.0, tracingFogSun);
        
        vec3 FogLightColor = FogSunLightColor * CalculateFogLight(tracingFogSun, Tfog) * visibility;
             FogLightColor += FogMoonLightColor * CalculateFogLight(tracingFogMoon, Tfog) * visibility;
             FogLightColor += SkyLightingColor * CalculateFogLight(tracingFogUp, Tfog) * 0.047;

        scattering += (FogLightColor - FogLightColor * stepTransmittance) * transmittance * inverseTransmittance * atmospheric.fogScattering * Hfog;

        transmittance *= stepTransmittance;
    }

    color *= transmittance;
    color += scattering;
}
#endif

vec3 SimpleLightExtinction(in vec3 rayOrigin, in vec3 L, float samplePoint, float sampleHeight) {
    vec2 tracingAtmosphere = RaySphereIntersection(rayOrigin, L, vec3(0.0), atmosphere_radius);
    if(tracingAtmosphere.y < 0.0) return vec3(1.0);

    vec2 tracingPlanet = RaySphereIntersection(rayOrigin, L, vec3(0.0), planet_radius);
    float planetShadow = tracingPlanet.y > tracingPlanet.x && tracingPlanet.x > 0.0 ? exp(-(tracingPlanet.y - tracingPlanet.x) * 0.00001) : 1.0;
    //if(tracingPlanet.x > 0.0) return vec3(0.0);

    float stepLength = tracingAtmosphere.y * samplePoint;

    float h = length(rayOrigin + (tracingAtmosphere.y * sampleHeight) * L) - planet_radius;

    float density_rayleigh  = stepLength * exp(-h / rayleigh_distribution);
    float density_mie       = stepLength * exp(-h / mie_distribution);

    vec3 tau = (rayleigh_scattering + rayleigh_absorption) * density_rayleigh + (mie_scattering + mie_absorption) * density_mie;
    vec3 transmittance = exp(-tau);

    return transmittance * planetShadow;
}

#include "/libs/volumetric/clouds_common.glsl"
//#include "/libs/volumetric/clouds_env.glsl"

vec3 CalculateHighQualityLightingColor(in vec3 rayOrigin, in vec3 L) {
    const int steps = 6;
    const float invsteps = 1.0 / float(steps);

    vec2 tracingPlanet = RaySphereIntersection(rayOrigin, L, vec3(0.0), planet_radius);
    float planetShadow = tracingPlanet.x > 0.0 ? exp(-(tracingPlanet.y - tracingPlanet.x) * 0.00001) : 1.0;

    vec2 tracingLight = RaySphereIntersection(rayOrigin, L, vec3(0.0), atmosphere_radius);
    float stepLength = tracingLight.y * invsteps;

    vec3 opticalDepth = vec3(0.0);

    for(int i = 0; i < steps; i++) {
        vec3 position = rayOrigin + (1.0 + float(i)) * stepLength * L;
        float height = length(position) - planet_radius;

        float Hm = exp(-height / mie_distribution);
        float Hr = exp(-height / rayleigh_distribution);
        float Ho = saturate(1.0 - abs(height - 25000.0) / 15000.0);

        opticalDepth += (mie_scattering + mie_absorption) * Hm + (rayleigh_scattering + rayleigh_absorption) * Hr + (ozone_absorption + ozone_scattering) * Ho;
    }

    vec3 transmittance = exp(-opticalDepth * stepLength);

    return transmittance * planetShadow;
}

vec3 CalculateCloudsLightExtinction(in vec3 rayPosition, in vec3 L, in vec3 rayOrigin, in float dither, in float level, in bool isSky) {
    int steps = level == High ? 6 : level < High ? 3 : 9;
    float invsteps = 1.0 / float(steps);

    vec2 tracingLight = RaySphereIntersection(vec3(0.0, rayPosition.y, 0.0), L, vec3(0.0), planet_radius + clouds_height + clouds_thickness);

    vec3 lightExtinction = vec3(1.0);
        
    if(tracingLight.y > 0.0) {
        float lightStepLength = min(8000.0, tracingLight.y) * invsteps;
        vec3 lightPosition = rayPosition + dither * L * lightStepLength;

        float opticalDepth = 0.0;

        for(int j = 0; j < steps; j++) {
            float height = isSky ? length(lightPosition - vec3(rayOrigin.x, 0.0, rayOrigin.z)) - planet_radius : lightPosition.y - planet_radius;

            float density = GetCloudsMap(lightPosition, height);

            #if Clouds_Self_Shadow_Detail == Low
            density = saturate(rescale(density, 0.2, 0.8));
            #else
            density = GetCloudsMapDetail(rayPosition, density, 0.1);
            #endif
            
            density = CalculateCloudsCoverage(height, density);

            opticalDepth += density * lightStepLength;

            lightPosition += lightStepLength * L;
        }

        vec3 PowderEffect = CloudsPowderEffect(max(clouds_scattering * 8.0, clouds_scattering * opticalDepth));//1.0 - exp(-clouds_scattering * (0.002 * tracingLight.y + opticalDepth) * 2.0);

        lightExtinction = (exp(-clouds_scattering * opticalDepth) + exp(-clouds_scattering * opticalDepth * 0.25) * 0.7 + exp(-clouds_scattering * opticalDepth * 0.03) * 0.24) / (1.7 + 0.24);
        lightExtinction *= PowderEffect;
    }

    return lightExtinction;
}

void CalculateClouds(inout vec3 color, in Vector v, in bool isSky) {
    vec3 direction = v.worldViewDirection;

    vec3 origin = vec3(cameraPosition.x, cameraPosition.y - 63.0, cameraPosition.z) * Altitude_Scale;
         origin.y = planet_radius + max(1.0, origin.y);

    const int steps = 12;
    const float invsteps = 1.0 / float(steps);

    vec2 tracingPlanet = RaySphereIntersection(vec3(0.0, origin.y, 0.0), direction, vec3(0.0), planet_radius);
    vec2 tracingAtmoshphere = RaySphereIntersection(vec3(0.0, origin.y, 0.0), direction, vec3(0.0), atmosphere_radius);

    float landDistance = v.viewLength * Altitude_Scale;

    vec2 tracingTop = RaySphereIntersection(vec3(0.0, origin.y, 0.0), direction, vec3(0.0), planet_radius + clouds_height + clouds_thickness);
    vec2 tracingBottom = RaySphereIntersection(vec3(0.0, origin.y, 0.0), direction, vec3(0.0), planet_radius + clouds_height);

    float bottom = tracingBottom.x > 0.0 ? tracingBottom.x : max(0.0, tracingBottom.y);
    float top = tracingTop.x > 0.0 ? tracingTop.x : max(0.0, tracingTop.y);

    float start = bottom;
    float end = top;

    if(start > end) {
        float v = start;
        start = end;
        end = v;
    }

    vec3 lightPosition = top * direction + vec3(0.0, origin.y, 0.0);

    float tracingPaneBottom = abs(IntersectPlane(vec3(0.0, origin.y, 0.0), direction, vec3(0.0, planet_radius + clouds_height, 0.0), vec3(0.0, 1.0, 0.0)));
    float tracingPaneTop = abs(IntersectPlane(vec3(0.0, origin.y, 0.0), direction, vec3(0.0, planet_radius + clouds_height + clouds_thickness, 0.0), vec3(0.0, 1.0, 0.0)));

    if(origin.y > planet_radius + clouds_height && tracingTop.x < 0.0) {
        start = 0.0;
        end = 256.0 * Altitude_Scale;
        tracingPaneTop = min(tracingPaneTop, end);
        lightPosition = vec3(tracingPaneTop * direction.x, planet_radius + clouds_height + clouds_thickness, tracingPaneTop * direction.z);
    }

    float stepLength = (end - start) * invsteps;
    float currentLength = start;

    //if((tracingTop.x < 0.0 && tracingTop.y < 0.0) || (tracingBottom.x < 0.0 && tracingBottom.y < 0.0)) return;
    if(tracingPlanet.x > 0.0 && start > tracingPlanet.x) return;

    vec3 transmittance = vec3(1.0);
    vec3 scattering = vec3(0.0);

    float theta = dot(worldSunVector, direction);
    float sunPhase = max(invPi * rescale(0.1, 0.0, 0.1), mix(HG(theta, pow(0.5333, 1.1)) * (0.1 / (1.1 - 1.0)), HG(theta, 0.8), 0.54)) * HG(0.95, 0.76);
    float moonPhase = max(invPi * rescale(0.1, 0.0, 0.1), mix(HG(-theta, pow(0.5333, 1.2)) * (0.1 / (1.2 - 1.0)), HG(-theta, 0.8), 0.54)) * HG(0.95, 0.76);

    #if Clouds_Sun_Lighting_Color == High
    vec3 SunColor = SimpleLightExtinction(lightPosition, worldSunVector, 0.5, 0.25) * Sun_Light_Luminance;
    #elif Clouds_Sun_Lighting_Color > High
    vec3 SunColor = CalculateHighQualityLightingColor(lightPosition, worldSunVector) * Sun_Light_Luminance;
    #else
    vec3 SunColor = SunLightingColor;
    #endif

    vec3 SunLight = SunColor * sunPhase;

    #if Clouds_Moon_Lighting_Color == High
    vec3 MoonColor = SimpleLightExtinction(lightPosition, worldMoonVector, 0.5, 0.25) * Moon_Light_Luminance;
    #elif Clouds_Moon_Lighting_Color > High
    vec3 MoonColor = CalculateHighQualityLightingColor(lightPosition, worldMoonVector) * Moon_Light_Luminance;
    #else
    vec3 MoonColor = MoonLightingColor * HG(0.95, 0.76);
    #endif

    vec3 MoonLight = MoonColor * moonPhase;

    float dither = R2Dither(ApplyTAAJitter(texcoord) * resolution);
    float dither2 = R2Dither(ApplyTAAJitter(1.0 - texcoord) * resolution);

    vec3 rayOrigin = origin + direction * stepLength * dither;

    float depth = start;
    float clouds = 0.0;

    for(int i = 0; i < steps; i++) {
        if(!isSky && landDistance - stepLength * 0.5 < currentLength) break;

        if(maxComponent(transmittance) < 1e-4) {
            transmittance = vec3(0.0, 0.0, 0.0);
            break;
        }

        vec3 rayPosition = direction * currentLength + rayOrigin;

        vec4 mediaSample = CalculateCloudsMedia(rayPosition, origin);
        float density = mediaSample.a;

        if(density > 0.0) {
            vec3 extinction = exp(-mediaSample.rgb * stepLength);

            #if Clouds_Tracing_Light_Source == Both
            vec3 S1 = SunLight * CalculateCloudsLightExtinction(rayPosition, worldSunVector, origin, dither2, Clouds_Sun_Lighting_Tracing, isSky) + MoonLight * CalculateCloudsLightExtinction(rayPosition, -worldSunVector, origin, dither2, Clouds_Moon_Lighting_Tracing, isSky);        
            #elif Clouds_Tracing_Light_Source == Sun
            vec3 S1 = SunLight * CalculateCloudsLightExtinction(rayPosition, worldSunVector, origin, dither2, High, isSky);
            #elif Clouds_Tracing_Light_Source == Moon
            vec3 S1 = MoonLight * CalculateCloudsLightExtinction(rayPosition, worldMoonVector, origin, dither2, High, isSky);        
            #else
            vec3 S1 = (MoonLight + SunLight) * CalculateCloudsLightExtinction(rayPosition, worldLightVector, origin, dither2, High, isSky);
            #endif

            vec3 CloudsScattering = S1 + SkyLightingColor * 0.047 * ((extinction + 0.5) / (1.0 + 0.5));
                 CloudsScattering *= mediaSample.rgb;

            scattering += (CloudsScattering - CloudsScattering * extinction) * transmittance / (clouds_scattering * max(density, 1e-5));

            transmittance *= extinction;

            clouds = 1.0;
        }

        currentLength += stepLength;
    }

    vec3 MieSunLight = SunColor * HG(theta, 0.76) + MoonColor * HG(-theta, 0.76);
    vec3 RayleightSunLight = (SunColor + MoonColor) * ((3.0 / 16.0 / Pi) * (1.0 + theta * theta));
    vec3 MieSunLight2 = SunColor * HG(worldSunVector.y, 0.76) + MoonColor * HG(-theta, 0.76);
    vec3 RayleightSunLight2 = (SunColor + MoonColor) * ((3.0 / 16.0 / Pi) * (1.0 + worldSunVector.y * worldSunVector.y));

    if(clouds > 0.5) {
        const int assteps = 12;
        const float asinvsteps = 1.0 / float(steps);

        vec2 tracingCloudsMiddle = RaySphereIntersection(vec3(0.0, origin.y, 0.0), direction, vec3(0.0), planet_radius + clouds_height + clouds_thickness * 0.5);

        float rayStart = max(0.0, max(0.0, tracingCloudsMiddle.x) - max(0.0, tracingAtmoshphere.x));
        float rayEnd = tracingPlanet.x > 0.0 ? tracingPlanet.x : tracingCloudsMiddle.y;

        if(!isSky) {
            rayStart = 0.0;
            rayEnd = landDistance;
        }

        float rayStepLength = (rayEnd - rayStart) * asinvsteps;

        vec3 currentPosition = origin + rayStart * direction;

        vec3 asScattering = vec3(0.0);
        vec3 asTransmittance = vec3(1.0);

        for(int i = 0; i < assteps; i++) {
            vec3 rayPosition = currentPosition;

            float height = length(rayPosition - vec3(origin.x, 0.0, origin.z)) - planet_radius;

            float density_rayleigh  = exp(-height / rayleigh_distribution) * float(Near_Atmosphere_Density);
            float density_mie       = exp(-height / mie_distribution) * float(Near_Atmosphere_Density);
            float density_ozone     = max(0.0, 1.0 - abs(height - 25000.0) / 15000.0);

            vec3 tau = (rayleigh_scattering + rayleigh_absorption) * (density_rayleigh) + (mie_scattering + mie_absorption) * (density_mie) + (ozone_absorption + ozone_scattering) * density_ozone;
            vec3 transmittance = exp(-stepLength * tau);

            vec3 r = RayleightSunLight * rayleigh_scattering * density_rayleigh;
            vec3 m = MieSunLight * mie_scattering * density_mie;

            vec3 S = r + m;
/*
            vec2 tracingCloudsBottom = RaySphereIntersection(rayPosition + vec3(0.0, origin.y, 0.0), direction, vec3(0.0), planet_radius + clouds_height);
            vec2 tracingCloudsTop = RaySphereIntersection(rayPosition + vec3(0.0, origin.y, 0.0), direction, vec3(0.0), planet_radius + clouds_height);

            float opticalDepth = abs((tracingCloudsBottom.x > 0.0 ? tracingCloudsBottom.x : max(0.0, tracingCloudsBottom.y)) - (tracingCloudsTop.x > 0.0 ? tracingCloudsTop.x : max(0.0, tracingCloudsTop.y)));

            vec3 cloudsPosition = rayPosition + worldLightVector * (tracingCloudsBottom.x > 0.0 ? tracingCloudsBottom.x : tracingCloudsBottom.y);

            float density = GetCloudsMap(cloudsPosition);
                  density = GetCloudsMapDetail(cloudsPosition, density, 0.2);
                  density = CalculateCloudsCoverage(length(cloudsPosition - vec3(origin.x, 0.0, origin.z) - planet_radius), density);

            S *= exp(-opticalDepth * density * clouds_scattering);
*/
            asScattering += (S - S * transmittance) * asTransmittance / (tau);
            asTransmittance *= transmittance;

            currentPosition += rayStepLength * direction;
        }

        scattering *= asTransmittance;
        scattering += asScattering * 1.0;
    }

    color *= transmittance;
    color += scattering;
}

uniform sampler2D colortex8;
uniform sampler2D colortex9;
uniform sampler2D colortex10;

void main() {
    //materials
    Gbuffers m = GetGbuffersData(texcoord);

    WaterData t = GetWaterData(texcoord);

    //opaque
    Vector v0 = GetVector(texcoord, m.maskWeather > 0.5 ? texture(colortex4, texcoord).x : texture(depthtex0, texcoord).x);
    Vector v1 = GetVector(texcoord, texture(depthtex1, texcoord).x);

    AtmosphericData atmospheric = GetAtmosphericDate(timeFog, timeHaze);

    vec3 color = texture(colortex3, texcoord).rgb;//CalculateRefraction(m, t, v0, v1, texcoord);
         color = LinearToGamma(color) * MappingToHDR;

    CalculateTranslucent(color, m, t, v0, v1, texcoord);

    //LandAtmosphericScattering(color, v0, atmospheric, m.maskSky > 0.5);
    /*
    WaterBackface back = GetWaterBackfaceData(texcoord);

    vec3 worldNormal = mat3(gbufferModelViewInverse) * m.geometryNormal;
    vec3 worldPosition = v0.wP + cameraPosition;
    vec3 blockCenter = floor(worldPosition - worldNormal * 0.1) + 0.5;
    vec2 tracing = IntersectCube(worldPosition, v0.worldViewDirection, blockCenter, vec3(0.5));

    float formBackFaceDepth = length(nvec3(gbufferProjectionInverse * nvec4(vec3(texcoord, back.depth) * 2.0 - 1.0)));
    float formVirtualBlock = tracing.y + v0.viewLength;
    float backDepth = m.fullBlock > 0.9 ? formVirtualBlock : formBackFaceDepth;
    */
    #if 1
    
    vec3 closest = vec3(0.0, 0.0, 2000.0);
    
    for(float i = -1.0; i <= 1.0; i += 1.0) {
        for(float j = -1.0; j <= 1.0; j += 1.0) {
            vec2 offset = vec2(i, j);
            vec2 sampleCoord = min(texcoord * 0.5 + offset * texelSize, vec2(0.5) - texelSize);

            float sampleDepth = ExpToLinerDepth(texture(colortex8, sampleCoord).x);

            float diffcent = abs(v0.linearDepth - sampleDepth);

            if(diffcent < closest.z) {
                closest = vec3(offset, diffcent);
            }
        }
    }  
    
    vec2 closestCoord = min(vec2(0.5) - texelSize, texcoord * 0.5 + closest.xy * texelSize);

    vec3 transmittance = texture(colortex10, closestCoord).rgb;
    vec3 scattering = texture(colortex9, closestCoord).rgb;
    
    /*
    float totalWeight = 0.0;
    vec3 transmittance = vec3(0.0);
    vec3 scattering = vec3(0.0);

    for(float i = -1.0; i <= 1.0; i += 1.0) {
        for(float j = -1.0; j <= 1.0; j += 1.0) {
            vec2 offset = vec2(i, j);
            vec2 sampleCoord = min(texcoord * 0.5 + offset * texelSize, vec2(0.5) - texelSize);

            float sampleDepth = ExpToLinerDepth(texture(colortex8, sampleCoord).x);

            float weight = 1.0 - min(1.0, abs(sampleDepth - v0.linearDepth) * 1.0);

            vec3 sampleScattering = texture(colortex9, sampleCoord).rgb;
            vec3 sampleTransmittance = texture(colortex10, sampleCoord).rgb;

            transmittance += sampleTransmittance * weight;
            scattering += sampleScattering * weight;
            totalWeight += weight;
        }
    }

    if(totalWeight > 0) {
    scattering /= totalWeight;
    transmittance /= totalWeight;
    }
    */

    //scattering = vec3(0.0);

    //if(m.material > 64.5 && (m.maskWater > 0.5 || m.fullBlock > 0.5)) {
    //    CalculateSubSurfaceScattering(color, scattering, m, t, v0, blockCenter, backDepth);
    //}

    vec2 velocity = GetVelocity(vec3(texcoord, v0.depth));
    if(m.maskHand > 0.5) velocity *= 0.001;
    vec2 previousCoord = texcoord - velocity;

    float depthWeight = (abs(ExpToLinerDepth(texture(colortex11, previousCoord).a) - v0.linearDepth) - 0.01) * 1000.0;
    float velocityWeight = length(velocity * resolution) * 0.1;

    float blend = 0.95 * step(abs(previousCoord.x - 0.5), 0.5) * step(abs(previousCoord.y - 0.5), 0.5);
          //blend *= 1.0 - clamp((abs(ExpToLinerDepth(texture(colortex11, previousCoord).a) - v0.linearDepth) - 0.01) * 2048.0, 0.0, 1.0);
          blend *= 1.0 - min(1.0, max(velocityWeight, depthWeight));

    //scattering = mix(vec3(1.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0), blend);
    scattering = mix(scattering, texture(colortex11, previousCoord).rgb, blend);

    if(m.maskWeather < 0.5) {
        //color *= transmittance;
        //color += scattering;
    }

    //if(totalWeight <= 1.0) color = vec3(1.0, 0.0, 0.0);
    #endif
    //color *= texture(colortex10, texcoord * 0.5).rgb;
    //color += texture(colortex9, texcoord * 0.5).rgb;

    //if(m.maskSky < 0.5) {
    //    vec3 origin = vec3(cameraPosition.x, cameraPosition.y - 63.0, cameraPosition.z) * Altitude_Scale;
    //         origin.y = planet_radius + origin.y;

    //    color *= CloudsShadowRayMarching(v0.wP, worldLightVector, origin, vec2(0.1, 0.7), Ultra);
    //}
    
    CalculateClouds(color, v1, m.maskSky > 0.5);

    color = color / (color + 1.0);
    color = GammaToLinear(color);

    gl_FragData[0] = vec4(color, 1.0);
    gl_FragData[1] = vec4(transmittance, 1.0);
    gl_FragData[2] = vec4(scattering, mix(v0.depth, texture(colortex11, previousCoord).a, blend));
}
/* DRAWBUFFERS:3AB */
/* RENDERTARGETS: 3,10,11 */