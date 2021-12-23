#version 130

uniform sampler2D colortex3;
uniform sampler2D colortex4;

//const bool colortex9Clear = false;

#include "/libs/setting.glsl"
#include "/libs/common.glsl"
#include "/libs/uniform.glsl"
#include "/libs/vertex_data_inout.glsl"
#include "/libs/gbuffers_data.glsl"
#include "/libs/lighting/shadowmap_common.glsl"
#include "/libs/volumetric/atmospheric_common.glsl"

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

void LandAtmosphericScattering(inout vec3 outScattering, inout vec3 outTransmittance, in Vector v, in AtmosphericData atmospheric, bool isSky) {
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

    float dither = R2Dither(ApplyTAAJitter(texcoord) * resolution * 0.5 + vec2(frameTimeCounter * 45.0, 0.0));

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
    vec3 AmbientLightColor = SkyLightingColor * 0.047 + SunLightingColor * HG(worldSunVector.y, 0.76) + MoonLightingColor * HG(worldMoonVector.y, 0.76);

    float fogPhaseSun = mix(HG(theta, Fog_Eccentricity), HG(theta, atmospheric.fogSilverSpread) * atmospheric.fogSilverIntensity, atmospheric.fogFrontScattering);
    float fogPhaseMoon = mix(HG(-theta, Fog_Eccentricity), HG(-theta, atmospheric.fogSilverSpread) * atmospheric.fogSilverIntensity, atmospheric.fogFrontScattering);

    vec3 FogSunLightColor = SunLightingColor * fogPhaseSun * shadowFade;
    vec3 FogMoonLightColor =  MoonLightingColor * fogPhaseMoon * shadowFade;
    vec3 FogAmbientLightColor = SkyLightingColor * 0.047 + SunLightingColor * HG(worldSunVector.y, atmospheric.fogSilverSpread) * atmospheric.fogSilverIntensity * atmospheric.fogFrontScattering + MoonLightingColor * HG(worldMoonVector.y, atmospheric.fogSilverSpread) * atmospheric.fogSilverIntensity * atmospheric.fogFrontScattering;

    vec3 opticalDepth = vec3(0.0);

    for(int i = 0; i < steps; i++) {
        vec3 rayPosition = origin + direction * (float(i) * stepLength);

        vec3 shadowCoord = WorldPositionToShadowCoord(rayPosition - cameraPosition);
        float visibility = abs(shadowCoord.x - 0.5) >= 0.5 || abs(shadowCoord.y - 0.5) >= 0.5 || shadowCoord.z + 1e-5 > 1.0 ? 1.0 : step(shadowCoord.z, texture(shadowtex0, shadowCoord.xy).x);

        float height = max(rayPosition.y - 63.0, 0.0);

        float Hr = exp(-height * Near_Atmosphere_Distribution / rayleigh_distribution) * Near_Atmosphere_Density;
        vec3 Tr = (rayleigh_scattering + rayleigh_absorption) * Hr;

        float Hm = exp(-height * Near_Atmosphere_Distribution / mie_distribution) * Near_Atmosphere_Density;
        vec3 Tm = (mie_scattering + mie_absorption) * Hm;

        float Hfog = saturate((atmospheric.fogHeight - height) / atmospheric.fogDistribution);
        vec3 Tfog = atmospheric.fogTransmittance * Hfog;

        vec3 stepTransmittance = exp(-(Tr + Tm + Tfog) * stepLength);
        vec3 inverseTransmittance = 1.0 / max(vec3(1e-8), Tr + Tm + Tfog);

        #if Near_Atmosphere_Density < 6
        vec3 r = RayleighLightColor * visibility + AmbientLightColor;
        vec3 m = MieLightColor * visibility + AmbientLightColor;
        #else
        float traingLight = IntersectPlane(vec3(0.0, height, 0.0), worldLightVector, vec3(0.0, 1500.0, 0.0), vec3(0.0, 1.0, 0.0));

        vec3 SunLightExtinction = CalculateFogLight(max(0.0, traingLight), (rayleigh_scattering + rayleigh_absorption + mie_scattering + mie_absorption) * Near_Atmosphere_Density);
        vec3 UpLightExtinction = CalculateFogLight(max(0.0, IntersectPlane(vec3(0.0, height, 0.0), worldUpVector, vec3(0.0, 1500.0, 0.0), vec3(0.0, 1.0, 0.0))), (rayleigh_scattering + rayleigh_absorption + mie_scattering + mie_absorption) * Near_Atmosphere_Density);

        vec3 r = RayleighLightColor * SunLightExtinction * visibility + AmbientLightColor * UpLightExtinction;
        vec3 m = MieLightColor * SunLightExtinction * visibility + AmbientLightColor * UpLightExtinction;        
        #endif

        //atmospheric scattering
        scattering += (r - r * stepTransmittance) * transmittance * inverseTransmittance * rayleigh_scattering * Hr;
        scattering += (m - m * stepTransmittance) * transmittance * inverseTransmittance * mie_scattering * Hm;

        //fog
        float tracingFogSun = IntersectPlane(vec3(0.0, height, 0.0), worldSunVector, vec3(0.0, atmospheric.fogHeight, 0.0), vec3(0.0, 1.0, 0.0));
        float tracingFogMoon = max(0.0, -tracingFogSun); 
        float tracingFogUp = max(0.0, IntersectPlane(vec3(0.0, height, 0.0), worldUpVector, vec3(0.0, atmospheric.fogHeight, 0.0), vec3(0.0, 1.0, 0.0)));
              tracingFogSun = max(0.0, tracingFogSun);
        
        vec3 FogLightColor = FogSunLightColor * CalculateFogLight(tracingFogSun, Tfog) * visibility;
             FogLightColor += FogMoonLightColor * CalculateFogLight(tracingFogMoon, Tfog) * visibility;
             FogLightColor += FogAmbientLightColor * CalculateFogLight(tracingFogUp, Tfog);

        scattering += (FogLightColor - FogLightColor * stepTransmittance) * transmittance * inverseTransmittance * atmospheric.fogScattering * Hfog;

        transmittance *= stepTransmittance;
    }

    //color *= transmittance;
    //color += scattering;

    outScattering = scattering;
    outTransmittance = transmittance;
}

void main() {
    //materials
    Gbuffers m = GetGbuffersData(texcoord);

    WaterData t = GetWaterData(texcoord);

    //opaque
    Vector v0 = GetVector(texcoord, m.maskWeather > 0.5 ? texture(colortex4, texcoord).x : texture(depthtex0, texcoord).x);
    Vector v1 = GetVector(texcoord, texture(depthtex1, texcoord).x);

    AtmosphericData atmospheric = GetAtmosphericDate(timeFog, timeHaze);    

    vec3 scattering = vec3(0.0);
    vec3 transmittance = vec3(1.0);

    LandAtmosphericScattering(scattering, transmittance, v0, atmospheric, m.maskSky > 0.5);

    gl_FragData[0] = vec4(v0.depth);
    gl_FragData[1] = vec4(scattering, 1.0);
    gl_FragData[2] = vec4(transmittance, 1.0);
}
/* RENDERTARGETS: 8,9,10 */