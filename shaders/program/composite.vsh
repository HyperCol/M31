#define io out

#include "/libs/setting.glsl"
#include "/libs/vertex_data_inout.glsl"
#include "/libs/uniform.glsl"
#include "/libs/common.glsl"
#include "/libs/volumetric/atmospheric_common.glsl"

#if !defined(MC_VERSION)
uniform vec3 upPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 shadowLightPosition;
#endif

vec3 SimpleLightExtinction(in vec3 rayOrigin, in vec3 L, float samplePoint, float sampleHeight) {
    vec2 tracingAtmosphere = RaySphereIntersection(rayOrigin, L, vec3(0.0), atmosphere_radius);
    vec2 tracingPlanet = RaySphereIntersection(rayOrigin, L, vec3(0.0), planet_radius);
    if(tracingAtmosphere.y < 0.0) return vec3(1.0);

    float stepLength = tracingAtmosphere.y * samplePoint;

    float h = length(rayOrigin + (tracingAtmosphere.y * sampleHeight) * L) - planet_radius;

    float density_rayleigh  = stepLength * exp(-h / rayleigh_distribution);
    float density_mie       = stepLength * exp(-h / mie_distribution);

    vec3 tau = (rayleigh_scattering + rayleigh_absorption) * density_rayleigh + (mie_scattering + mie_absorption) * density_mie;
    vec3 transmittance = exp(-tau);

    return transmittance;
}

vec3 CalculateLocalInScattering(in vec3 rayOrigin, in vec3 rayDirection) {
    int steps = 6;
    float invsteps = 1.0 / float(steps);

    vec2 tracingAtmosphere = RaySphereIntersection(rayOrigin, rayDirection, vec3(0.0), atmosphere_radius);
    if(tracingAtmosphere.y < 0.0) return vec3(1.0);

    float stepLength = tracingAtmosphere.y * invsteps;

    vec3 opticalDepth = vec3(0.0);

    for(int i = 0; i < steps; i++) {
        vec3 p = rayOrigin + rayDirection * (stepLength + stepLength * float(i));
        float h = max(1e-5, length(p) - planet_radius);

        float density_rayleigh  = stepLength * exp(-h / rayleigh_distribution);
        float density_mie       = stepLength * exp(-h / mie_distribution);
        float density_ozone     = stepLength * max(0.0, 1.0 - abs(h - 25000.0) / 15000.0);

        opticalDepth += vec3(density_rayleigh, density_mie, density_ozone);
    }

    vec3 tau = (rayleigh_scattering + rayleigh_absorption) * opticalDepth.x + (mie_scattering + mie_absorption) * opticalDepth.y + (ozone_absorption + ozone_scattering) * opticalDepth.z;
    vec3 transmittance = exp(-tau);

    return transmittance;
}

// Values from: http://blenderartists.org/forum/showthread.php?270332-OSL-Goodness&p=2268693&viewfull=1#post2268693   
vec3 ColorTemperatureToRGB(const in float temperature){
    mat3 m = (temperature <= 6500.0) ? mat3(vec3(0.0, -2902.1955373783176, -8257.7997278925690),
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

    SunLightingColor    = SimpleLightExtinction(samplePosition, worldSunVector, 0.5, 0.15) * Sun_Light_Luminance;
    MoonLightingColor   = SimpleLightExtinction(samplePosition, worldMoonVector, 0.5, 0.15) * Moon_Light_Luminance;
    LightingColor       = SunLightingColor + MoonLightingColor;
    SkyLightingColor    = max(vec3(0.0), 1.0 - CalculateLocalInScattering(samplePosition, worldUpVector)) * (sum3(SunLightingColor) + sum3(MoonLightingColor) + Nature_Light_Min_Luminance);

    #if Blocks_Light_Color == Color_Temperature
    BlockLightingColor  = ColorTemperatureToRGB(Blocks_Light_Color_Temperture) * Blocks_Light_Intensity * Blocks_Light_Luminance;
    #else
    BlockLightingColor  = vec3(Blocks_Light_Color_R, Blocks_Light_Color_G, Blocks_Light_Color_B) * (Blocks_Light_Intensity * Blocks_Light_Luminance / max(Blocks_Light_Color_R, max(Blocks_Light_Color_G, Blocks_Light_Color_B)));
    #endif

    shadowFade = saturate(rescale(abs(worldSunVector.y), 0.05, 0.1));

    starsFade = saturate(rescale(worldMoonVector.y, Stars_Fade_Out, Stars_Fade_In));
}