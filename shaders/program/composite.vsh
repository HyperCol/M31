#define io out

#include "/libs/setting.glsl"
#include "/libs/vertex_data_inout.glsl"
#include "/libs/uniform.glsl"
#include "/libs/common.glsl"
#include "/libs/volumetric/atmospheric_common.glsl"

uniform vec3 upPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 shadowLightPosition;

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

void main() {
    gl_Position = ftransform();

    texcoord = gl_MultiTexCoord0.xy;

    lightVector = normalize(shadowLightPosition);
    worldLightVector = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);

    sunVector = normalize(sunPosition);
    worldSunVector = normalize(mat3(gbufferModelViewInverse) * sunPosition);

    moonVector = normalize(moonPosition);
    worldMoonVector = normalize(mat3(gbufferModelViewInverse) * moonPosition);

    upVector = normalize(upPosition);
    worldUpVector = vec3(0.0, 1.0, 0.0);

    //make sure samplePosition.y > planet_radius
    vec3 samplePosition = vec3(0.0, planet_radius + 1.0, 0.0);

    SunLightingColor    = SimpleLightExtinction(samplePosition, worldSunVector, 0.5, 0.15) * Sun_Light_Luminance;
    MoonLightingColor   = SimpleLightExtinction(samplePosition, worldMoonVector, 0.5, 0.15) * Moon_Light_Luminance;
    LightingColor       = SunLightingColor + MoonLightingColor;
    SkyLightingColor    = max(vec3(0.0), 1.0 - CalculateLocalInScattering(samplePosition, worldUpVector)) * mix(1.0, sum3(SunLightingColor) + sum3(MoonLightingColor), 0.9);
    BlockLightingColor  = vec3(1.0, 0.782, 0.344) * Blocks_Light_Luminance;

    shadowFade = saturate(rescale(abs(worldSunVector.y), 0.05, 0.1));
}