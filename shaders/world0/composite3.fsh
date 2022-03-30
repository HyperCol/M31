#version 130

uniform sampler2D colortex3;
uniform sampler2D colortex4;

#include "/libs/setting.glsl"
#include "/libs/common.glsl"
#include "/libs/uniform.glsl"
#include "/libs/gbuffers_data.glsl"
#include "/libs/lighting/brdf.glsl"
#include "/libs/lighting/shadowmap_common.glsl"

uniform vec3 worldLightVector;
uniform vec3 worldSunVector;

in vec2 texcoord;

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

vec2 RSMGISample(in vec2 E, in float a2) {
    float Phi = E.x * 2.0 * Pi;
    float CosTheta = sqrt((1.0 - E.y) / ( 1.0 + (a2 - 1.0) * E.y));
    float SinTheta = sqrt(1.0 - CosTheta * CosTheta);

    return vec2(cos(Phi) * SinTheta, sin(Phi) * SinTheta);
}

vec3 CalculateRSMGI(in Gbuffers m, in Vector v) {
    if(v.viewLength > 64.0) return vec3(0.0);

    vec3 viewNormal = m.texturedNormal;
    vec3 worldGeoNormal = (mat3(gbufferModelViewInverse) * viewNormal);

    vec3 shadowViewNormal = mat3(shadowModelView) * worldGeoNormal;
    vec3 shadowViewLight = mat3(shadowModelView) * worldLightVector;

    vec3 shadowCoord = ConvertToShadowCoord(v.wP);
    vec3 shadowViewPosition = mat3(shadowProjectionInverse) * shadowCoord.xyz;

    vec3 shadowSampleCoord = shadowCoord;

    float distortion = ShadowMapDistortion(shadowCoord.xy); 

    shadowSampleCoord.xy *= distortion;
    shadowSampleCoord = RemapShadowCoord(shadowSampleCoord);
    shadowSampleCoord = shadowSampleCoord * 0.5 + 0.5;

    shadowCoord = shadowCoord * 0.5 + 0.5;
    shadowCoord.z -= shadowTexelSize * 2.0;

    float dither = R2Dither((texcoord * 0.5 - jitter) * resolution);
    float dither2 = R2Dither((1.0 - texcoord) * 0.5 * resolution);

    int steps = 8;
    float invsteps = 1.0 / float(steps);

    vec3 diffuse = vec3(0.0);
    float weight = 0.0;

    float CosTheta = sqrt((1.0 - dither) / ( 1.0 + (0.999 - 1.0) * dither));
    float SinTheta = sqrt(1.0 - CosTheta * CosTheta);

    //vec2 offset = vec2(cos(dither2 * 2.0 * Pi), sin(dither2 * 2.0 * Pi)) * SinTheta * 4.0 * shadowTexelSize * (distortion);

    for(int i = 0; i < 8; i++) {
        float r = hash((float(i) * 0.1 + texcoord * 0.5 - jitter) * resolution) * 2.0 * Pi;
        vec2 offset = vec2(cos(r) * SinTheta, sin(r) * SinTheta) * 4.0 * shadowTexelSize;
        vec2 coord = shadowSampleCoord.xy + offset * float(i + 1) * distortion;

        float depth = texture(shadowtex0, coord).x;
              depth = (depth * 2.0 - 1.0) / Shadow_Depth_Mul * 0.5 + 0.5;
        if(depth > 0.9999 || abs(coord.x / shadowMapScale.x - 0.5) > 0.5 || abs(coord.y / shadowMapScale.y - 0.5) > 0.5) continue;

        vec3 albedo = LinearToGamma(texture(shadowcolor0, coord).rgb);
             albedo /= mix(1.0, maxComponent(albedo), 0.7);

        vec3 normal = texture(shadowcolor1, coord).xyz * 2.0 - 1.0;
             normal = mat3(shadowModelView) * normal;

        vec3 halfPosition = vec3(shadowCoord.xy + offset * float(i + 1), depth) * 2.0 - 1.0;
             halfPosition = mat3(shadowProjectionInverse) * halfPosition - shadowViewPosition;
        vec3 direction = normalize(halfPosition);

        float ndotl = max(0.0, dot(-direction, normal)) * max(0.0, dot(direction, shadowViewNormal));

        float attenuation = min(1.0, 4.0 / pow2(length(halfPosition)));

        diffuse += albedo * ndotl * attenuation;
        weight += 1.0 / (float(i + 1));
    }

    if(weight > 0.0)
    diffuse /= weight;

    return diffuse;
}

void main() {
    Gbuffers m = GetGbuffersData(texcoord);

    Vector v = GetVector(-ApplyTAAJitter(-texcoord), m.maskWeather > 0.5 ? texture(colortex4, texcoord).x : texture(depthtex0, texcoord).x);

    gl_FragData[0] = vec4(GammaToLinear(CalculateRSMGI(m, v)), v.depth);
}
/* DRAWBUFFERS:4 */