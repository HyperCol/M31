#version 130

uniform sampler2D colortex3;
uniform sampler2D colortex4;

#include "/libs/setting.glsl"
#include "/libs/common.glsl"
#include "/libs/uniform.glsl"
#include "/libs/vertex_data_inout.glsl"
#include "/libs/gbuffers_data.glsl"
#include "/libs/lighting/brdf.glsl"
#include "/libs/volumetric/atmospheric_common.glsl"
#include "/libs/volumetric/atmospheric.glsl"

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

vec3 projectionToScreen(in vec3 P){
    return nvec3(gbufferProjection * nvec4(P)) * 0.5 + 0.5;
}

vec2 ScreenSpaceRayMarching(in vec3 rayOrigin, in vec3 rayDirection){
    vec2 hitUV = vec2(-1.0);

    int count;

    #if Screen_Space_Reflection < High
    int steps = 20;
    #elif Screen_Space_Reflection > High
    int steps = 40;
    #else
    int steps = 30;
    #endif

    float invsteps = 1.0 / float(steps);

    float qulity = 20.0 * invsteps;

    float stepLength = pow(2.0, 0.5);

    vec3 testPosition = rayOrigin;
    vec3 direction = rayDirection * 0.25 * qulity;

    float thickness = 0.25 * qulity;

    int pierce = 0;
    int hit = 0;
    int miss = 0;

    float returnSky = 256.0 * 0.05 * float(steps);  //stepLength ^ steps

    for(int i = 0; i < steps; i++){
        testPosition += direction;

        vec3 screenCoord = projectionToScreen(testPosition);

        vec2 coord = screenCoord.xy;
        if(abs(coord.x - 0.5) > 0.5 || abs(coord.y - 0.5) > 0.5) break;

        float sampleDepth = texture(depthtex0, coord).x;
        vec3 samplePosition = nvec3(gbufferProjectionInverse * vec4(vec3(coord, sampleDepth) * 2.0 - 1.0, 1.0));

        float rayLinear = ExpToLinerDepth(screenCoord.z);
        float sampleLinear = ExpToLinerDepth(sampleDepth);
        float difference = rayLinear - sampleLinear; 

        if(difference > 0.0) {
            if(difference < thickness * max(1.0, rayLinear * 0.2)) {
                hitUV = coord;
                break;
            } else {
                testPosition -= direction;
                direction *= 0.25;
            }
        } else {
            if(rayLinear > returnSky && sampleLinear > returnSky) {
                hitUV = coord;
                break;
            }

            direction *= stepLength;
        }
    }

    return hitUV;
}

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

    color += LightColor0 * transmittance * (phaseMie.x * Hm * mie_scattering + phaseRayleigh * Hr * rayleigh_scattering) * invPi;
    color += LightColor1 * transmittance * (phaseMie.y * Hm * mie_scattering + phaseRayleigh * Hr * rayleigh_scattering) * invPi;
}

void main() {
    Gbuffers m = GetGbuffersData(texcoord);

    Vector v = GetVector(-ApplyTAAJitter(-texcoord), m.maskWeather > 0.5 ? texture(colortex4, texcoord).x : texture(depthtex0, texcoord).x);

    vec3 color = LinearToGamma(texture(colortex3, texcoord).rgb) * MappingToHDR;

    float dither = R2Dither(ApplyTAAJitter(texcoord) * resolution);
    float dither2 = R2Dither(ApplyTAAJitter(1.0 - texcoord) * resolution);

    vec3 visibleNormal = dot(v.eyeDirection, m.texturedNormal) > 0.2 ? m.texturedNormal : m.geometryNormal;

    vec3 n = visibleNormal;
    vec3 t = normalize(vec3(n.y - n.z, -n.x, n.x));
    vec3 b = cross(t, n);
    mat3 tbn = mat3(t, b, n);

    vec4 rayPDF = ImportanceSampleGGX(vec2(dither, dither2), m.roughness);

    vec3 normal = normalize(tbn * rayPDF.xyz);

    vec3 L = normalize(reflect(v.viewDirection, normal));
    vec3 eyeDirection = v.eyeDirection;
    vec3 M = normalize(L + eyeDirection);

    vec3 rayOrigin = v.vP;
         rayOrigin += m.geometryNormal * (1.0 - saturate(rescale(dot(v.eyeDirection, m.geometryNormal), 0.2, 1.0))) * 0.2;

    //color = vec3(0.0);

    vec3 fr = SpecularLightingClamped(m, m.texturedNormal, normalize(reflect(v.viewDirection, m.texturedNormal)), eyeDirection);

    vec3 reflection = vec3(0.0);

    vec2 coord = ScreenSpaceRayMarching(rayOrigin, L);
    bool hit = coord.x > 0.0 && coord.y > 0.0;

if(m.maskSky < 0.5) {
    if(hit) {
        reflection = LinearToGamma(texture(colortex3, coord).rgb) * MappingToHDR;
    } else {
        vec3 worldLightDirection = mat3(gbufferModelViewInverse) * L;

        vec3 rayOrigin = vec3(0.0, planet_radius + max(1.0, (cameraPosition.y - 63.0) * Altitude_Scale), 0.0);

        vec2 tracingAtmosphere = RaySphereIntersection(rayOrigin, worldLightDirection, vec3(0.0), atmosphere_radius);
        vec2 tracingPlanet = RaySphereIntersection(rayOrigin, worldLightDirection, vec3(0.0), planet_radius);

        reflection = vec3(0.0);
        vec3 temp = vec3(0.0);

        CalculateAtmosphericScattering(temp, reflection, rayOrigin, worldLightDirection, worldSunVector, vec2(0.0));
        CalculatePlanetSurface(reflection, SunLightingColor, MoonLightingColor, worldSunVector, worldLightDirection, 1000.0, tracingPlanet.x - max(0.0, tracingAtmosphere.x));
    }
}

    color += reflection * fr;

    color = color / (color + 1.0);
    color = GammaToLinear(color);

    gl_FragData[0] = vec4(color, 1.0);
}
/* DRAWBUFFERS:3 */