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

    return t(mod(coord.x * a1 + coord.y * a2, 1.0));
}

#include "/libs/noise.glsl"
#include "/libs/volumetric/clouds_common.glsl"
#include "/libs/volumetric/clouds_env.glsl"

vec3 SimpleLightExtinction(in vec3 rayOrigin, in vec3 L, float samplePoint, float sampleHeight) {
    vec2 tracingAtmosphere = RaySphereIntersection(rayOrigin, L, vec3(0.0), atmosphere_radius);
    if(tracingAtmosphere.y < 0.0) return vec3(1.0);

    vec2 tracingPlanet = RaySphereIntersection(rayOrigin, L, vec3(0.0), planet_radius);
    float planetShadow = tracingPlanet.x > 0.0 ? exp(-(tracingPlanet.y - tracingPlanet.x) * 0.00001) : 1.0;
    //if(tracingPlanet.x > 0.0) return vec3(0.0);

    float stepLength = tracingAtmosphere.y * samplePoint;

    float h = length(rayOrigin + (tracingAtmosphere.y * sampleHeight) * L) - planet_radius;

    float density_rayleigh  = stepLength * exp(-h / rayleigh_distribution);
    float density_mie       = stepLength * exp(-h / mie_distribution);

    vec3 tau = (rayleigh_scattering + rayleigh_absorption) * density_rayleigh + (mie_scattering + mie_absorption) * density_mie;
    vec3 transmittance = exp(-tau);

    return transmittance * planetShadow;
}
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

vec3 CalculateCloudsLightExtinction(in vec3 rayPosition, in vec3 L, in vec3 rayOrigin, in float dither, in float level) {
    int steps = level > High ? 8 : level == High ? 6 : 4;
    float invsteps = 1.0 / float(steps);

    vec2 tracingLight = RaySphereIntersection(vec3(0.0, rayPosition.y, 0.0), L, vec3(0.0), planet_radius + clouds_height + clouds_thickness);

    vec3 lightExtinction = vec3(1.0);
        
    if(tracingLight.y > 0.0) {
        float lightStepLength = min(8000.0, tracingLight.y * 0.5) * invsteps;
        vec3 lightPosition = rayPosition + dither * L * lightStepLength;

        float opticalDepth = 0.0;

        for(int j = 0; j < steps; j++) {
            float height = length(lightPosition - vec3(rayOrigin.x, 0.0, rayOrigin.z)) - planet_radius;

            float density = CalculateCloudsMedia(lightPosition, rayOrigin).a;

            opticalDepth += density * lightStepLength;

            lightPosition += lightStepLength * L;
        }

        vec3 PowderEffect = CloudsPowderEffect(max(clouds_scattering * 8.0, clouds_scattering * opticalDepth));//1.0 - exp(-clouds_scattering * (0.002 * tracingLight.y + opticalDepth) * 2.0);

        lightExtinction = (exp(-clouds_scattering * opticalDepth) + exp(-clouds_scattering * opticalDepth * 0.25) * 0.7 + exp(-clouds_scattering * opticalDepth * 0.03) * 0.24) / (1.7 + 0.24);
        lightExtinction *= PowderEffect;
    }

    return lightExtinction;
}

void CalculateClouds(inout vec3 outScattering, inout vec3 outTransmittance, in Vector v, inout float cloudsLength, in bool isSky) {
    vec3 direction = v.worldViewDirection;

    vec3 origin = vec3(cameraPosition.x, cameraPosition.y - 63.0, cameraPosition.z) * Altitude_Scale;
         origin.y = planet_radius + max(0.0, origin.y);
    
    float rayLength = v.viewLength * Altitude_Scale;

    float dither = R2Dither(ApplyTAAJitter(texcoord - jitter * 0.5) * resolution * 0.5);
    float dither2 = R2Dither(ApplyTAAJitter(1.0 - texcoord - jitter * 0.5) * resolution * 0.5);

    //vec2 tracingBarrel = IntersectNearClouds(vec3(0.0, origin.y, 0.0), direction, vec3(0.0, planet_radius + clouds_height, 0.0), vec3(0.0, planet_radius + clouds_height + clouds_thickness, 0.0), 8000.0);
    //float barrel = tracingBarrel.x > 0.0 ? tracingBarrel.x : max(0.0, tracingBarrel.y);

    vec2 tracingBottom = RaySphereIntersection(vec3(0.0, origin.y, 0.0), direction, vec3(0.0), planet_radius + clouds_height);
    vec2 tracingTop = RaySphereIntersection(vec3(0.0, origin.y, 0.0), direction, vec3(0.0), planet_radius + clouds_height + clouds_thickness);

    float bottom = tracingBottom.x > 0.0 ? tracingBottom.x : max(0.0, tracingBottom.y);
    float top = tracingTop.x > 0.0 ? tracingTop.x : max(0.0, tracingTop.y);

    float theta = dot(worldSunVector, direction);
    float sunPhase = max(invPi * rescale(0.1, 0.0, 0.1), mix(HG(theta, pow(0.5333, 1.1)) * (0.1 / (1.1 - 1.0)), HG(theta, 0.8), 0.54)) * HG(0.95, 0.76);
    float moonPhase = max(invPi * rescale(0.1, 0.0, 0.1), mix(HG(-theta, pow(0.5333, 1.2)) * (0.1 / (1.2 - 1.0)), HG(-theta, 0.8), 0.54)) * HG(0.95, 0.76);

    vec3 lightPosition = top * direction + vec3(0.0, origin.y, 0.0);

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
    vec3 MoonColor = MoonLightingColor;
    #endif

    vec3 MoonLight = MoonColor * moonPhase;

    const int steps = 12;
    const float invsteps = 1.0 / float(steps);

    if(bottom > top) {
        float temp = bottom;
        bottom = top;
        top = temp;
    }

    float start = bottom;
    float end = top;

    if(clamp(origin.y - planet_radius, clouds_height, clouds_height + clouds_thickness) == origin.y - planet_radius) {
        start = 0.0;
        end = 8.0 * Altitude_Scale * float(steps);
    }

    vec2 tracingPlanet = RaySphereIntersection(vec3(0.0, origin.y, 0.0), direction, vec3(0.0), planet_radius);
    float landDistance = isSky ? tracingPlanet.x : rayLength;

    float stepLength = (end - start) * invsteps;
    //stepLength = abs(stepLength);

    vec3 transmittance = vec3(1.0);
    vec3 scattering = vec3(0.0);

    vec3 rayStep = direction * stepLength;
    vec3 rayOrigin = origin;
    //vec3 currentPosition = bottom * direction + origin + rayStep * dither * 0.0;
    float currentLength = start + stepLength * mix(dither, 1.0, 0.05);

    int j = 0;

    float depth = 0.0;
    float total = 0.0;
    float depthStart = start;

    float clouds = 0.0;

    for(int i = 0; i < steps; i++) {
        vec3 currentPosition = currentLength * direction + origin;
        float height = length(currentPosition - vec3(origin.x, 0.0, origin.z)) - planet_radius;

        //vec2 tracingNear = IntersectNearClouds(currentPosition - vec3(origin.x, 0.0, origin.z), direction, vec3(0.0, planet_radius + clouds_height, 0.0), vec3(0.0, planet_radius + clouds_height + thickness, 0.0), 8000.0);

        if((landDistance > 0.0 && currentLength > landDistance) || maxComponent(transmittance) < 1e-5) break;

        vec4 mediaSample = CalculateCloudsMedia(currentPosition, origin);
        float density = mediaSample.a;

        if(density > 0.0) {
            vec3 extinction = exp(-mediaSample.rgb * abs(stepLength));

            #if Clouds_Tracing_Light_Source == Both
            vec3 S = SunLight * CalculateCloudsLightExtinction(currentPosition, worldSunVector, origin, dither2, Clouds_Sun_Lighting_Tracing) + MoonLight * CalculateCloudsLightExtinction(rayPosition, -worldSunVector, origin, dither2, Clouds_Moon_Lighting_Tracing);        
            #elif Clouds_Tracing_Light_Source == Sun
            vec3 S = SunLight * CalculateCloudsLightExtinction(currentPosition, worldSunVector, origin, dither2, High);
            #elif Clouds_Tracing_Light_Source == Moon
            vec3 S = MoonLight * CalculateCloudsLightExtinction(currentPosition, worldMoonVector, origin, dither2, High);        
            #else
            vec3 S = (MoonLight + SunLight) * CalculateCloudsLightExtinction(currentPosition, worldLightVector, origin, dither2, High);
            #endif

            vec3 CloudsScattering = S + SkyLightingColor * 0.047 * ((extinction + 0.5) / (1.0 + 0.5));
                 CloudsScattering *= mediaSample.rgb;

            scattering += (CloudsScattering - CloudsScattering * extinction) * transmittance / (clouds_scattering * rescale(density, -0.05, 1.0));

            transmittance *= extinction;

            depth += stepLength;
            total += 1.0;
        }else{
            depthStart += stepLength;
        }

        currentLength += stepLength;
    }

    outTransmittance = transmittance;
    outScattering = scattering;

    if(total > 0.0) {
        //vec3 cloudsPosition = v.viewDirection * (depthStart + depth / total);
        //cloudsDepth = nvec3(gbufferProjection * nvec4(cloudsPosition / Altitude_Scale)).z * 0.5 + 0.5;

        cloudsLength = (depthStart + depth / total);
    }else if(isSky){
        //vec3 cloudsPosition = v.viewDirection * (depthStart + 4000.0);
        //cloudsDepth = nvec3(gbufferProjection * nvec4(cloudsPosition / Altitude_Scale)).z * 0.5 + 0.5;        

        cloudsLength = depthStart + Sky_Distance_Above_Clouds;
        if(tracingPlanet.x > 0.0) cloudsLength = tracingPlanet.x;

        //if(tracingPlanet.x > 0.0) cloudsLength = max(cloudsLength, tracingPlanet.x);
    }
}

void LandAtmosphericScattering(inout vec3 outScattering, inout vec3 outTransmittance, in Vector v, in AtmosphericData atmospheric, in float tracingEnd, bool hitSphere) {
    int steps = 12;
    float invsteps = 1.0 / float(steps);

    vec3 direction = v.worldViewDirection;
    vec3 origin = vec3(cameraPosition.x, cameraPosition.y - 63.0, cameraPosition.z) * Altitude_Scale;

    float theta = dot(direction, worldSunVector);

    float lightHG = HG(0.95, 0.76);
    float sunLuminance = Sun_Light_Luminance * lightHG;
    float moonLuminance = Moon_Light_Luminance * lightHG;

    float phaseRayleigh = (3.0 / 16.0 / Pi) * (1.0 + theta * theta);
    vec3 rayleighSunLight = vec3(sunLuminance * phaseRayleigh);
    vec3 rayleighMoonLight = vec3(moonLuminance * phaseRayleigh);

    float phaseMieSun = HG(theta, 0.76);
    vec3 mieSunLight = vec3(sunLuminance * phaseMieSun);

    float phaseMieMoon = HG(-theta, 0.76);
    vec3 mieMoonLight = vec3(moonLuminance * phaseMieMoon);

    float phaseRayleigh2 = (3.0 / 16.0 / Pi) * (1.0 + worldSunVector.y * worldSunVector.y);
    vec3 rayleighSunLight2 = vec3(sunLuminance * phaseRayleigh2);
    vec3 rayleighMoonLight2 = vec3(moonLuminance * phaseRayleigh2);
    vec3 mieSunLight2 = vec3(sunLuminance * HG(worldSunVector.y, 0.76));
    vec3 mieMoonLight2 = vec3(moonLuminance * HG(-worldSunVector.y, 0.76));

    vec2 tracingPlanet = RaySphereIntersection(vec3(0.0, origin.y + planet_radius, 0.0), direction, vec3(0.0), planet_radius);
    vec2 tracingAtmosphere = RaySphereIntersection(vec3(0.0, origin.y + planet_radius, 0.0), direction, vec3(0.0), atmosphere_radius);

    //bool hitSphere = isSky;

    float rayEnd = hitSphere ? tracingPlanet.x : tracingEnd;

    //float start = 0.0;
    //float end = min(8000.0, tracingEnd);

    float start = max(0.0, tracingEnd - 8000.0);
    float end = tracingEnd;

    float stepLength = (end - start) * invsteps;

    float dither = R2Dither(ApplyTAAJitter(texcoord) * resolution + vec2(frameTimeCounter * 45.0, 0.0));

    vec3 scattering = vec3(0.0);
    vec3 transmittance = vec3(1.0);

    vec3 rayStep = stepLength * direction;
    vec3 rayStart = vec3(0.0, origin.y, 0.0);
    vec3 testPoint = rayStart + mix(dither, 1.0, 0.05) * rayStep;

    for(int i = 0; i < steps; i++) {
        vec3 currentPosition = testPoint;

        //if(length(currentPosition - rayStart) > rayEnd) break;

        float height = hitSphere ? length(currentPosition + vec3(0.0, planet_radius, 0.0)) - planet_radius : currentPosition.y;
              height = max(1e-5, height);

        vec3 shadowCoord = WorldPositionToShadowCoord(currentPosition - rayStart);
        float visibility = abs(shadowCoord.x - 0.5) >= 0.5 || abs(shadowCoord.y - 0.5) >= 0.5 || shadowCoord.z + 1e-5 > 1.0 ? 1.0 : step(shadowCoord.z, texture(shadowtex0, shadowCoord.xy).x);

        vec3 cloudsShadow = vec3(1.0);

        //cloudsShadow = CloudsShadow((currentPosition - rayStart), worldLightVector, origin + vec3(0.0, planet_radius, 0.0), vec2(0.05, 0.7), 1.0, High);

        vec3 cloudsOccluasion = vec3(1.0);
        
        //cloudsOccluasion = CloudsShadow(currentPosition - rayStart, worldUpVector, origin + vec3(0.0, planet_radius, 0.0), vec2(0.05, 1.0), 1.0, 1);

        vec3 lightVisibility = vec3(visibility) * cloudsShadow;

        float Dm = exp(-height / mie_distribution) * 1.0;
        vec3 Tm = (mie_absorption + mie_scattering) * Dm;

        float Dr = exp(-height / rayleigh_distribution) * 1.0;
        vec3 Tr = (rayleigh_absorption + rayleigh_scattering) * Dr;

        vec3 extinction = Tm + Tr;

        vec3 stepExtinction = exp(-stepLength * extinction);

        vec3 sunLightExtinction = SimpleLightExtinction(currentPosition + vec3(0.0, planet_radius, 0.0), worldSunVector, 1.0, 0.2);
        vec3 moonLightExtinction = SimpleLightExtinction(currentPosition + vec3(0.0, planet_radius, 0.0), worldMoonVector, 1.0, 0.2);

        vec3 m = Dm * mie_scattering;
        vec3 r = Dr * rayleigh_scattering;

        vec3 sunLight = (mieSunLight * lightVisibility + mieSunLight2 * cloudsOccluasion) * m + (rayleighSunLight * lightVisibility + rayleighSunLight2 * cloudsOccluasion) * r;
             sunLight *= sunLightExtinction;

        vec3 moonLight = (mieMoonLight * lightVisibility + mieMoonLight2 * cloudsOccluasion) * m + (rayleighMoonLight * lightVisibility + rayleighMoonLight2 * cloudsOccluasion) * r;
             moonLight *= moonLightExtinction;

        vec3 S = sunLight + moonLight;

        scattering += (S - S * stepExtinction) * stepExtinction / extinction;
        transmittance *= stepExtinction;

        testPoint += rayStep;
    }

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

    float envLength = v0.viewLength * Altitude_Scale;

    vec3 cloudsTransmittance = vec3(1.0);
    vec3 cloudsScattering = vec3(0.0);
    CalculateClouds(cloudsScattering, cloudsTransmittance, v1, envLength, m.maskSky > 0.5);

    float envDepth = nvec3(gbufferProjection * nvec4(v0.viewDirection * envLength / Altitude_Scale)).z * 0.5 + 0.5;

    vec3 scattering = vec3(0.0);
    vec3 transmittance = vec3(1.0);
    LandAtmosphericScattering(scattering, transmittance, v0, atmospheric, envLength, m.maskSky > 0.5);

    scattering = cloudsScattering * transmittance + scattering;

    gl_FragData[0] = vec4(envDepth, v0.depth, vec2(1.0));
    gl_FragData[1] = vec4(scattering, cloudsTransmittance.x);
    gl_FragData[2] = vec4(transmittance, 1.0);
}
/* RENDERTARGETS: 8,9,10 */