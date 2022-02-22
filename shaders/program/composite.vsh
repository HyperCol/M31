#define io out

#include "/libs/setting.glsl"
#include "/libs/vertex_data_inout.glsl"
#include "/libs/uniform.glsl"
#include "/libs/common.glsl"
#include "/libs/volumetric/atmospheric_common.glsl"

uniform int worldTime;

#if !defined(MC_VERSION)
uniform vec3 upPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 shadowLightPosition;
#endif

vec3 SimpleLightExtinction(in vec3 rayOrigin, in vec3 L, float samplePoint, in float density) {
    vec2 tracingAtmosphere = RaySphereIntersection(rayOrigin, L, vec3(0.0), atmosphere_radius);
    if(tracingAtmosphere.y < 0.0) return vec3(1.0);

    vec2 tracingPlanet = RaySphereIntersection(rayOrigin, L, vec3(0.0), planet_radius);
    float planetShadow = tracingPlanet.x > 0.0 ? exp(-(tracingPlanet.y - tracingPlanet.x) * 0.00001) : 1.0;
    //if(tracingPlanet.x > 0.0) return vec3(0.0);

    float stepLength = tracingAtmosphere.y;

    float height = length(rayOrigin + L * stepLength * 0.2) - planet_radius;

    float density_rayleigh  = exp(-height / rayleigh_distribution) * density;
    float density_mie       = exp(-height / mie_distribution) * density;

    vec3 tau = (rayleigh_scattering + rayleigh_absorption) * density_rayleigh + (mie_scattering + mie_absorption) * density_mie;
    vec3 transmittance = exp(-tau * stepLength);

    return transmittance * planetShadow;
}

vec3 SimpleInScattering(in vec3 samplePosition, in vec3 direction, in vec3 L, in float s, in float h) {
    vec2 tracing = RaySphereIntersection(samplePosition, direction, vec3(0.0), atmosphere_radius);

    float stepLength = tracing.y;
    float height = length(samplePosition + direction * stepLength * 0.5) - planet_radius;

    float Hr = exp(-height / rayleigh_distribution);
    float Hm = exp(-height / mie_distribution);

    vec3 Tr = (rayleigh_scattering + rayleigh_absorption) * Hr;
    vec3 Tm = (mie_scattering + mie_absorption) * Hm;

    vec3 transmittance = exp(-(Tr + Tm) * stepLength);

    vec3 lighting = (transmittance) * stepLength * (rayleigh_scattering + mie_scattering);

    return lighting;
}

// Values from: http://blenderartists.org/forum/showthread.php?270332-OSL-Goodness&p=2268693&viewfull=1#post2268693   
vec3 ColorTemperatureToRGB(const in float temperature){
    mat3 m = (temperature <= 6500.0) ?  mat3(vec3(0.0, -2902.1955373783176, -8257.7997278925690),
                                             vec3(0.0, 1669.5803561666639, 2575.2827530017594),
                                             vec3(1.0, 1.3302673723350029, 1.8993753891711275)) : 
                                        mat3(vec3(1745.0425298314172, 1216.6168361476490, -8257.7997278925690),
                                             vec3(-2666.3474220535695, -2173.1012343082230, 2575.2827530017594),
                                             vec3(0.55995389139931482, 0.70381203140554553, 1.8993753891711275)); 
    return mix(clamp(vec3(m[0] / (vec3(clamp(temperature, 1000.0, 40000.0)) + m[1]) + m[2]), vec3(0.0), vec3(1.0)), vec3(1.0), smoothstep(1000.0, 0.0, temperature));
}

void main() {
    gl_Position = ftransform();

    texcoord = gl_MultiTexCoord0.xy;

    #if !defined(MC_VERSION)
    lightVector = normalize(shadowLightPosition);
    worldLightVector = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);

    sunVector = normalize(sunPosition);
    worldSunVector = normalize(mat3(gbufferModelViewInverse) * sunPosition);

    moonVector = normalize(moonPosition);
    worldMoonVector = normalize(mat3(gbufferModelViewInverse) * moonPosition);

    upVector = normalize(upPosition);
    worldUpVector = vec3(0.0, 1.0, 0.0);
    #endif

    //make sure samplePosition.y > planet_radius
    vec3 samplePosition = vec3(0.0, planet_radius + 1.0, 0.0);

    float theta     = mix(0.0, dot(upVector, sunVector), 1.0);
    float silverIntensity = 1.0;
    float phasem    = min(HG(theta, 0.76) * silverIntensity, 1.0);
    float phasem2   = min(HG(-theta, 0.76) * silverIntensity, 1.0);
    float phaser    = min((3.0 / 16.0 / Pi) * (1.0 + theta * theta) * silverIntensity, 1.0);

    SunLightingColor    = SimpleLightExtinction(samplePosition, worldSunVector, 0.2, 1.0) * Sun_Light_Luminance;
    MoonLightingColor   = SimpleLightExtinction(samplePosition, worldMoonVector, 0.2, 1.0) * Moon_Light_Luminance;
    LightingColor       = SunLightingColor + MoonLightingColor;

    float lighting2 = Sun_Light_Luminance * invPi;
    float lighting3 = Moon_Light_Luminance * invPi;

    vec3 rayleighLighting = rayleigh_scattering * phaser * (LightingColor + lighting2 + lighting3);
    vec3 mieLighting = mie_scattering * phasem * (sum3(SunLightingColor) + lighting2) + mie_scattering * phasem2 * (sum3(MoonLightingColor) + lighting3);
    vec3 skyLighting = SimpleInScattering(samplePosition, worldUpVector, worldSunVector, 0.5, 0.5);

    SkyLightingColor = skyLighting * (mieLighting + rayleighLighting) / (rayleigh_scattering + mie_scattering);

    #if Blocks_Light_Color == Color_Temperature
    BlockLightingColor  = ColorTemperatureToRGB(Blocks_Light_Color_Temperture) * Blocks_Light_Intensity * Blocks_Light_Luminance;
    #else
    BlockLightingColor  = vec3(Blocks_Light_Color_R, Blocks_Light_Color_G, Blocks_Light_Color_B) * (Blocks_Light_Intensity * Blocks_Light_Luminance / max(Blocks_Light_Color_R, max(Blocks_Light_Color_G, Blocks_Light_Color_B)));
    #endif

    shadowFade = saturate(rescale(abs(worldSunVector.y), 0.05, 0.1));

    starsFade = saturate(rescale(worldMoonVector.y, Stars_Fade_Out, Stars_Fade_In));

    float time = float(worldTime);

    float fogEnd = float(Fog_End);
    float fogStart = float(Fog_Start);

    #if Fog_End < Fog_Start
        timeFog = saturate(rescale(time, fogStart, fogStart + Fog_Clear_Time)) + (1.0 - saturate(rescale(time, fogEnd, fogEnd + Fog_Clear_Time)));
    #else
        timeFog = saturate(rescale(time, fogStart, fogStart + Fog_Clear_Time)) * (1.0 - saturate(rescale(time, fogEnd, fogEnd + Fog_Clear_Time)));
    #endif
}