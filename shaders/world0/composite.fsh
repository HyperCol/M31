#version 130

#include "/libs/setting.glsl"
#include "/libs/vertex_data_inout.glsl"
#include "/libs/uniform.glsl"
#include "/libs/common.glsl"
#include "/libs/gbuffers_data.glsl"
#include "/libs/lighting/brdf.glsl"
#include "/libs/volumetric/atmospheric_common.glsl"
#include "/libs/shadowmap/shadowmap_common.glsl"
#include "/libs/misc/night_sky.glsl"

float R2Dither(in vec2 coord){
  float a1 = 1.0 / 0.75487766624669276;
  float a2 = 1.0 / 0.569840290998;

  return mod(coord.x * a1 + coord.y * a2, 1);
}

#include "/libs/shadowmap/shadow.glsl"

vec3 CalculateLocalInScattering(in vec3 rayOrigin, in vec3 rayDirection) {
    int steps = 6;
    float invsteps = 1.0 / float(steps);

    //planet shadow
    vec2 tracingPlanet = RaySphereIntersection(rayOrigin, rayDirection, vec3(0.0, -1.0, 0.0), planet_radius);
    float planetShadow = 1.0;
    if(tracingPlanet.x > 0.0 && tracingPlanet.y > 0.0) {
        planetShadow = exp(-0.00001 * (tracingPlanet.y - tracingPlanet.x));
    }

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

    return transmittance * planetShadow;
}

void CalculateAtmosphericScattering(inout vec3 color, inout vec3 atmosphere_color, in vec3 rayOrigin, in vec3 rayDirection, in vec3 mainLightDirection, in vec3 secLightDirection, in vec2 tracing) {
    int steps = 16;
    float invsteps = 1.0 / float(steps);

    rayOrigin = vec3(0.0, planet_radius + max(1.0, (cameraPosition.y - 63.0) * 1.0), 0.0);

    vec2 tracingAtmosphere = RaySphereIntersection(rayOrigin, rayDirection, vec3(0.0), atmosphere_radius);
    vec2 tracingPlanet = RaySphereIntersection(rayOrigin, rayDirection, vec3(0.0), planet_radius);

    float end = tracingPlanet.x > 0.0 ? tracingPlanet.x : tracingAtmosphere.y;
    float start = tracingAtmosphere.x > 0.0 ? tracingAtmosphere.x : 0.0;

    float theta = dot(rayDirection, mainLightDirection);
    float mainPhaseR = (3.0 / 16.0 / Pi) * (1.0 + theta * theta);
    float mainPhaseM = HG(theta, 0.76);

    float secTheta = dot(rayDirection, secLightDirection);
    float secPhaseR = (3.0 / 16.0 / Pi) * (1.0 + secTheta * secTheta);
    float secPhaseM = HG(secTheta, 0.76);

    float stepLength = (end - start) * invsteps;

    vec3 opticalDepth = vec3(0.0);

    vec3 r = vec3(0.0);
    vec3 m = vec3(0.0);

    vec3 transmittance = vec3(1.0);

    for(int i = 0; i < steps; i++) {
        vec3 p = rayOrigin + rayDirection * (stepLength + stepLength * float(i) + start);
        float h = max(1e-5, length(p) - planet_radius);

        float density_rayleigh  = stepLength * exp(-h / rayleigh_distribution);
        float density_mie       = stepLength * exp(-h / mie_distribution);
        float density_ozone     = stepLength * max(0.0, 1.0 - abs(h - 25000.0) / 15000.0);

        vec3 tau = (rayleigh_scattering + rayleigh_absorption) * (density_rayleigh) + (mie_scattering + mie_absorption) * (density_mie) + (ozone_absorption + ozone_scattering) * density_ozone;
        vec3 attenuation = exp(-tau);

        vec3 L1 = CalculateLocalInScattering(p, mainLightDirection) * Sun_Light_Luminance;
        vec3 alphaMain = (L1 - L1 * attenuation) * transmittance / tau;

        vec3 L2 = CalculateLocalInScattering(p, secLightDirection) * Moon_Light_Luminance;
        vec3 alphaSec = (L2 - L2 * attenuation) * transmittance / tau;

        r += (alphaMain * mainPhaseR + alphaSec * secPhaseR) * density_rayleigh;
        m += (alphaMain * mainPhaseM + alphaSec * secPhaseM) * density_mie;
        transmittance *= attenuation;
    }

    color *= transmittance;

    atmosphere_color = (r * rayleigh_scattering + m * mie_scattering);
}

vec3 CalculatePlanetSurface(in vec3 LightColor0, in vec3 LightColor1, in vec3 L, in vec3 direction, in float h, in float t) {
    if(t <= 0.0) return vec3(0.0);

    float cosTheta = dot(L, direction);

    float phaseM0 = HG(cosTheta, 0.76);
    float phaseM1 = HG(-cosTheta, 0.76);

    float phaseR = (3.0 / 16.0 / Pi) * (1.0 + cosTheta * cosTheta);

    vec3 Tr = exp(-h / rayleigh_distribution) * (rayleigh_absorption + rayleigh_scattering);
    vec3 Tm = exp(-h / mie_distribution) * (mie_absorption + mie_scattering);

    vec3 transmittance = 1.0 - exp(-sqrt(pow2(t) + pow2(h)) * 3.0 * (Tr + Tm));

    return LightColor0 * (phaseM0 + phaseR) * (transmittance) + LightColor1 * (phaseM1 + phaseR) * (transmittance);
}

void main() {
    //material
    Gbuffers    m = GetGbuffersData(texcoord);

    //opaque
    Vector      o = GetVector(texcoord, depthtex0);

    vec3 color = vec3(0.0);

    vec3 shading = CalculateShading(vec3(texcoord, o.depth), lightVector, m.geometryNormal);

    vec3 sunLight = DiffuseLighting(m, lightVector, o.eyeDirection);
         sunLight += SpecularLighting(m, lightVector, o.eyeDirection);

    color += sunLight * LightingColor * shading * shadowFade;

    vec3 AmbientLight = vec3(0.0);
         AmbientLight += m.albedo * SunLightingColor * (saturate(dot(m.texturedNormal, sunVector)) * HG(dot(m.texturedNormal, sunVector), 0.1) * HG(0.5, 0.76) * invPi);
         AmbientLight += m.albedo * SkyLightingColor * (rescale(dot(m.texturedNormal, upVector) * 0.5 + 0.5, -0.5, 1.0) * invPi);
         AmbientLight *= pow2(m.lightmap.y) * m.lightmap.y * (1.0 - m.metal) * (1.0 - m.metallic);

    color += AmbientLight;

    #if Held_Light_Quality == High

    vec3 handOffset = nvec3(gbufferProjectionInverse * nvec4(vec3(1.0, 0.5, 0.0) * 2.0 - 1.0)) * vec3(1.0, 1.0, 0.0);
    if(m.tile_mask == Mask_ID_Hand) handOffset = vec3(0.0);

    vec3 lP1 = o.vP - handOffset * 4.0;
    vec3 lP2 = o.vP + handOffset * 4.0;

    float heldLightDistance1 = 1.0 / pow2(length(lP1));
    float heldLightDistance2 = 1.0 / pow2(length(lP2)); 

    lP1 = normalize(lP1);
    lP2 = normalize(lP2);

    vec3 heldLight1  = BlockLightingColor * SpecularLighting(m, -lP1, o.eyeDirection) * heldLightDistance1;
         heldLight1 += BlockLightingColor * DiffuseLighting(m, -lP1, o.eyeDirection) * max(0.0, rescale(heldLightDistance1, 1e-2, 1.0));
         heldLight1 *= float(heldBlockLightValue) / 15.0 * 3.0;
    
    vec3 heldLight2  = BlockLightingColor * SpecularLighting(m, -lP2, o.eyeDirection) * heldLightDistance2;
         heldLight2 += BlockLightingColor * DiffuseLighting(m, -lP2, o.eyeDirection) * max(0.0, rescale(heldLightDistance2, 1e-2, 1.0));
         heldLight2 *= float(heldBlockLightValue2) / 15.0 * 3.0;

    color += heldLight1 + heldLight2;
    #else
    float heldLightDistance = 1.0 / pow2(o.viewLength);

    vec3 heldLight  = BlockLightingColor * SpecularLighting(m, o.eyeDirection, o.eyeDirection) * heldLightDistance;
         heldLight += BlockLightingColor * DiffuseLighting(m, o.eyeDirection, o.eyeDirection) * max(0.0, rescale(heldLightDistance, 1e-2, 1.0));
         heldLight *= max(float(heldBlockLightValue), float(heldBlockLightValue2)) / 15.0 * 3.0;

    color += heldLight;
    #endif

    vec3 blockLight = (BlockLightingColor * m.albedo);
         blockLight *= (1.0 / 4.0 * Pi) * m.lightmap.x * (pow2(m.lightmap.x) + 1.0 / pow2(max(1.0, (1.0 - m.lightmap.x) * 15.0)));

    color += blockLight;

    color += m.emissive * m.albedo;

    if(m.tile_mask == Mask_ID_Sky) {
        vec3 rayOrigin = vec3(0.0, planet_radius + max(1.0, (cameraPosition.y - 63.0) * 1.0), 0.0);
        vec3 rayDirection = o.worldViewDirection;

        vec2 tracingAtmosphere = RaySphereIntersection(rayOrigin, rayDirection, vec3(0.0), atmosphere_radius);
        vec2 tracingPlanet = RaySphereIntersection(rayOrigin, rayDirection, vec3(0.0), planet_radius);

        color = vec3(0.0);

        vec3 stars = DrawStars(o.worldViewDirection, tracingPlanet.x);
        //color += max(stars / Moon_Light_Luminance - sum3(LightingColor) * 24.0, vec3(0.0)) * Moon_Light_Luminance;
        color += starsFade * stars;

        color += DrawMoon(worldMoonVector, o.worldViewDirection, tracingPlanet.x);

        color += CalculatePlanetSurface(SunLightingColor, MoonLightingColor, worldSunVector, o.worldViewDirection, 1000.0, tracingPlanet.x);

        vec3 atmosphere_color = vec3(0.0);
        CalculateAtmosphericScattering(color, atmosphere_color, vec3(0.0, planet_radius, 0.0), o.worldViewDirection, worldSunVector, worldMoonVector, vec2(0.0));
        color += atmosphere_color;
    }

    //color *= MappingToSDR;
    //color = GammaToLinear(color);

    color = color / (color + 1.0);
    color = GammaToLinear(color);

    gl_FragData[0] = vec4(color, 1.0);
}
/* DRAWBUFFERS:3 */