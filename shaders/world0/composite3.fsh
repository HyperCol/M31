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

    return t(fract(coord.x * a1 + coord.y * a2));
}

vec3 saturation(in vec3 color, in float s) {
	float lum = dot(color, vec3(1.0 / 3.0));
	return max(vec3(0.0), lum + (color - lum) * s);
}

vec2 RSMGISample(in vec2 E, in float a2) {
    float Phi = E.x * 2.0 * Pi;
    float CosTheta = sqrt((1.0 - E.y) / ( 1.0 + (a2 - 1.0) * E.y));
    float SinTheta = sqrt(1.0 - CosTheta * CosTheta);

    return vec2(cos(Phi) * SinTheta, sin(Phi) * SinTheta);
}

vec3 CalculateRSMGI(in Gbuffers m, in Vector v) {
    if(v.linearDepth > 64.0) return vec3(0.0);

    vec3 viewNormal = m.texturedNormal;
    vec3 worldGeoNormal = (mat3(gbufferModelViewInverse) * viewNormal);

    vec3 shadowViewNormal = mat3(shadowModelView) * worldGeoNormal;
    vec3 shadowViewLight = mat3(shadowModelView) * worldLightVector;

    vec3 shadowCoord = ConvertToShadowCoord(v.wP);
    vec3 shadowViewPosition = mat3(shadowProjectionInverse) * shadowCoord.xyz;

    //vec3 shadowSampleCoord = shadowCoord;

    //float distortion = ShadowMapDistortion(shadowCoord.xy); 
    //shadowSampleCoord.xy *= distortion;
    //shadowSampleCoord = RemapShadowCoord(shadowSampleCoord);
    //shadowSampleCoord = shadowSampleCoord * 0.5 + 0.5;

    shadowCoord = shadowCoord * 0.5 + 0.5;
    //shadowCoord.z -= shadowTexelSize * 2.0;

    vec2 fragCoord = texcoord * resolution * 0.375;

    float dither = R2Dither((texcoord - jitter) * resolution);
    float dither2 = R2Dither(((1.0 - texcoord) - jitter) * resolution);

    int steps = 8;
    float invsteps = 1.0 / float(steps);

    vec3 diffuse = vec3(0.0);
    float weight = 0.0;

    float CosTheta = sqrt((1.0 - dither) / ( 1.0 + (0.999 - 1.0) * dither));
    float SinTheta = sqrt(1.0 - CosTheta * CosTheta);

    //vec2 offset = vec2(cos(dither2 * 2.0 * Pi), sin(dither2 * 2.0 * Pi)) * SinTheta * 4.0 * shadowTexelSize;

    for(int i = 0; i < 6; i++) {
        for(int j = 0; j < 4; j++) {
        float rayLength = float(i) + 1.0;
        float r = ((dither2 + float(j)) * 0.25) * Pi * 2.0;
        //float r = (hash(fragCoord + float(i) * resolution + vec2(frameTimeCounter, 0.0) * 64.0) * 0.5 + 0.5) * 2.0 * Pi;
        
        vec2 offset = vec2(cos(r) * SinTheta, sin(r) * SinTheta) * 16.0 * shadowTexelSize * rayLength;

        vec3 shadowSampleCoord = shadowCoord * 2.0 - 1.0 + vec3(offset, 0.0);
             shadowSampleCoord.xy *= ShadowMapDistortion(shadowSampleCoord.xy);
             shadowSampleCoord = RemapShadowCoord(shadowSampleCoord);
             shadowSampleCoord = shadowSampleCoord * 0.5 + 0.5;

        vec2 coord = shadowSampleCoord.xy;

        float depth = texture(shadowtex0, coord).x;
              depth = (depth * 2.0 - 1.0) / Shadow_Depth_Mul * 0.5 + 0.5;
              
        if(depth > 0.9999 || abs(coord.x / shadowMapScale.x - 0.5) > 0.5 || abs(coord.y / shadowMapScale.y - 0.5) > 0.5) continue;
        //depth -= 0.00;

        vec3 albedo = LinearToGamma(texture(shadowcolor0, coord).rgb);
             albedo /= mix(1.0, maxComponent(albedo) + 1e-5, RSMGI_Albedo_Luminance_Boost);
             albedo = saturation(albedo, RSMGI_Albedo_Saturation);

        vec3 normal = texture(shadowcolor1, coord).xyz * 2.0 - 1.0;
             normal = mat3(shadowModelView) * normal;

        vec3 halfPosition = vec3(shadowCoord.xy + offset, depth) * 2.0 - 1.0;
             halfPosition = mat3(shadowProjectionInverse) * halfPosition - shadowViewPosition;

        #ifdef RSMGI_Noodle_Error_Disabled
        if(sqrt(halfPosition.z * halfPosition.z) > length(halfPosition.xy) * RSMGI_Noodle_Error_Distance) continue;
        #endif

        vec3 direction = normalize(halfPosition);

        float ndotl = max(0.0, dot(-direction, normal)) * max(0.0, dot(direction, shadowViewNormal));

        #ifdef RSMGI_Disabled_Sun_Angle
        ndotl *= max(0.0, dot(shadowViewLight, normal));
        #endif

        float attenuation = 1.0 / max(1e-5, pow2(length(halfPosition)));

        diffuse += albedo * min(1.0, ndotl * attenuation * RSMGI_Luminance);
        weight += 1.0;
        }
    }

    //if(weight > 0.0)
    //diffuse /= weight;

    diffuse /= 4.0 * 6.0;

    return diffuse;
}

void main() {
    Gbuffers m = GetGbuffersData(texcoord);

    Vector v = GetVector(-ApplyTAAJitter(-texcoord), m.maskWeather > 0.5 ? texture(colortex4, texcoord).x : texture(depthtex0, texcoord).x);

    gl_FragData[0] = vec4(GammaToLinear(CalculateRSMGI(m, v)), v.depth);
}
/* DRAWBUFFERS:4 */