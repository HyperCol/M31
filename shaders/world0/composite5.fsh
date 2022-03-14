#version 130

uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex6;

const bool colortex6Clear = false;

#include "/libs/setting.glsl"
#include "/libs/common.glsl"
#include "/libs/uniform.glsl"
#include "/libs/vertex_data_inout.glsl"
#include "/libs/gbuffers_data.glsl"
#include "/libs/lighting/brdf.glsl"
#include "/libs/volumetric/atmospheric_common.glsl"
#include "/libs/volumetric/atmospheric.glsl"
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

vec3 projectionToScreen(in vec3 P){
    return nvec3(gbufferProjection * nvec4(P)) * 0.5 + 0.5;
}

vec2 ScreenSpaceRayMarching(in vec3 rayOrigin, in vec3 rayDirection, in vec3 normal){
    vec2 hitUV = vec2(-1.0);

    int count;

    #if Screen_Space_Reflection < High
    int steps = 20;
    #elif Screen_Space_Reflection > High
    int steps = 60;
    #else
    int steps = 40;
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

        if(difference > 0.0 && dot(normalize(testPosition - rayOrigin), normal) > 0.0) {
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
            //if(miss % 2 == 1) direction *= 2.0;
            //miss++;
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
/*
vec3 CalculateAtmosphericScattering2(in vec3 rayOrigin, in vec3 rayEnd, in vec3 L) {
    const int steps = 12;
    const float invsteps = 1.0 / float(steps);

    vec3 rayDirection = normalize(rayEnd - rayOrigin);

    vec3 rayStep = (rayEnd - rayOrigin) * invsteps;
    vec3 rayStart = rayOrigin + rayStep * 0.5;

    float stepLength = length(rayEnd - rayOrigin) * invsteps;

    float theta = dot(rayDirection, L);
    float miePhase = HG(theta, 0.76);
    float miePhase2 = HG(-theta, 0.76);
    float rayleighPhase = (3.0 / 16.0 / Pi) * (1.0 + theta * theta);

    vec3 r = vec3(0.0);
    vec3 m = vec3(0.0);
    vec3 m2 = vec3(0.0);

    vec3 transmittance = vec3(1.0);

    for(int i = 0; i < steps; i++) {
        vec3 p = rayStart + rayStep * float(i);
        float h = max(1e-5, length(p) - planet_radius);

        float density_rayleigh  = exp(-h / rayleigh_distribution);
        float density_mie       = exp(-h / mie_distribution);
        float density_ozone     = max(0.0, 1.0 - abs(h - 25000.0) / 15000.0);

        vec3 tau = (rayleigh_scattering + rayleigh_absorption) * (density_rayleigh) + (mie_scattering + mie_absorption) * (density_mie) + (ozone_absorption + ozone_scattering) * density_ozone;
        vec3 attenuation = exp(-tau * stepLength);

        vec3 L1 = CalculateLocalInScattering(p, L) * Sun_Light_Luminance;
        vec3 S1 = (L1 - L1 * attenuation) * transmittance / tau;

        vec3 L2 = CalculateLocalInScattering(p, -L) * Moon_Light_Luminance;
        vec3 S2 = (L2 - L2 * attenuation) * transmittance / tau;

        r += (S1 + S2) * density_rayleigh;
        m += S1 * density_mie;
        m2 += S2 * density_mie; 

        transmittance *= attenuation;
    }

    return r * rayleigh_scattering * rayleighPhase + m * mie_scattering * miePhase + m2 * mie_scattering * miePhase2;
}
*/

vec2 DualParaboloidMapping(in vec3 position) {
    float L = length(position.xyz);
    float Z = abs(position.z);

    vec2 coord = position.xy / L;
         coord /= 1.0 + Z / L;
         coord *= 0.75;
         coord = coord * 0.5 + 0.5;
         coord.x *= 0.5;
         coord = coord * shadowMapScale + (1.0 - shadowMapScale);
         if(position.z < 0.0) coord.x += 0.5;

    return coord;
}

vec3 EnvironmentReflection(in vec3 L, in Gbuffers m) {
    vec2 coord = DualParaboloidMapping(L);

    float depth = texture(shadowtex0, coord).x;

    vec3 color = vec3(0.0);

    if(depth > 1.0 - 1e-5) {
        vec3 rayOrigin = vec3(0.0, planet_radius + max(1.0, (cameraPosition.y - 63.0) * Altitude_Scale), 0.0);

        vec2 tracingAtmosphere = RaySphereIntersection(rayOrigin, L, vec3(0.0), atmosphere_radius);
        vec2 tracingPlanet = RaySphereIntersection(rayOrigin, L, vec3(0.0), planet_radius);

        vec3 atmosphere_color = vec3(0.0);

        CalculatePlanetSurface(color, SunLightingColor, MoonLightingColor, worldSunVector, L, 1000.0, tracingPlanet.x - max(0.0, tracingAtmosphere.x));
        CalculateAtmosphericScattering(color, atmosphere_color, rayOrigin, L, worldSunVector, vec2(0.0));
        color += atmosphere_color;
    } else {
        vec3 albedo = LinearToGamma(texture(shadowcolor0, coord).rgb);

        vec2 lightmap = unpack2x4(texture(shadowcolor1, coord).z);

        vec3 shadowCoord = normalize(L.xyz) * depth * 120.0;
             shadowCoord = ConvertToShadowCoord(shadowCoord);
             shadowCoord.xy *= ShadowMapDistortion(shadowCoord.xy);
             shadowCoord.xyz = RemapShadowCoord(shadowCoord.xyz);
             shadowCoord = shadowCoord * 0.5 + 0.5;

        float shading = step(shadowCoord.z, texture(shadowtex0, shadowCoord.xy).x + 0.5 / 2048.0) * texture(shadowcolor1, coord).a;
        
        vec3 SunLight = albedo * shading * SunLightingColor * invPi;

        float SkyLighting0 = saturate(rescale(pow2(lightmap.y * lightmap.y), 0.7, 1.0));
        float SkyLighting1 = pow2(lightmap.y) * lightmap.y;
        float skylightMap = mix(SkyLighting0, SkyLighting1, 0.7);

        vec3 AmbientLight = albedo * invPi * SkyLightingColor * skylightMap;

        float blockLight0 = (lightmap.x * lightmap.x * lightmap.x);
        float blockLight1 = 1.0 / pow2(max(1.0, (1.0 - lightmap.x) * 15.0));

        vec3 torchLight = albedo * BlockLightingColor * invPi * (blockLight0 + blockLight1);

        color = SunLight + AmbientLight + torchLight;
    }

    return color;
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

    if(dot(normal, v.eyeDirection) < 0.0) normal = -normal;
    if(m.smoothness > 0.95) normal = m.texturedNormal;

    vec3 L = normalize(reflect(v.viewDirection, normal));
    vec3 eyeDirection = v.eyeDirection;
    vec3 M = normalize(L + eyeDirection);

    vec3 rayOrigin = v.vP;
         rayOrigin += m.geometryNormal * (1.0 - saturate(rescale(dot(v.eyeDirection, m.geometryNormal), 0.2, 1.0))) * 0.2;

    //color = vec3(0.0);

    vec3 fr = SpecularLightingClamped(m, m.texturedNormal, normalize(reflect(v.viewDirection, m.texturedNormal)), eyeDirection);

    vec3 reflection = vec3(0.0);

if(m.maskSky < 0.5) {
    vec2 coord = ScreenSpaceRayMarching(rayOrigin, L, n);
    bool hit = coord.x > 0.0 && coord.y > 0.0;

    if(hit) {
        reflection = LinearToGamma(texture(colortex3, coord).rgb) * MappingToHDR;
    } else {
        vec3 worldLightDirection = mat3(gbufferModelViewInverse) * L;

        reflection = EnvironmentReflection(worldLightDirection, m);
    }

    //reflection = mix(reflection, texture(colortex6, texcoord).rgb, 0.95);

    //color = vec3(0.0);
    //fr = vec3(1.0);

    color += reflection * fr;
}

    color = color / (color + 1.0);
    color = GammaToLinear(color);

    gl_FragData[0] = vec4(color, 1.0);
    gl_FragData[1] = vec4(reflection, 1.0);
}
/* DRAWBUFFERS:36 */