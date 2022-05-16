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

float R2Dither(in vec2 seed) {
	float g = 1.32471795724474602596;
	vec2  a = 1.0 / vec2(g, g * g);

	return fract(0.5 + seed.x * a.x + seed.y * a.y);	
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

vec2 float2R2(in float n) {
	float g = 1.32471795724474602596;
	vec2  a = 1.0 / vec2(g, g * g);

	return fract(0.5 + n * a);
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

    vec2 fragCoord = texcoord * resolution * RSMGI_Render_Scale;

    vec2 seed = float2R2(float(frameCounter)) * resolution;

    float dither = R2Dither(texcoord * resolution * RSMGI_Render_Scale + seed);
    float dither2 = R2Dither((1.0 - texcoord) * RSMGI_Render_Scale * resolution + seed);

    int steps = 8;
    float invsteps = 1.0 / float(steps);

    int rounds = 4;

    vec3 diffuse = vec3(0.0);
    float weight = 0.0;

    float CosTheta = sqrt((1.0 - dither2) / ( 1.0 + (0.999 - 1.0) * dither2));
    float SinTheta = sqrt(1.0 - CosTheta * CosTheta);

    //vec2 offset = vec2(cos(dither2 * 2.0 * Pi), sin(dither2 * 2.0 * Pi)) * SinTheta * 4.0 * shadowTexelSize;

    for(int j = 1; j <= rounds; j++) {
        for(int i = 0; i < steps; i++) {
        //float rayLength = float(i) + 1.0;
        //float r = ((dither2 + float(j)) * 0.25) * Pi * 2.0;
        ////float r = (hash(fragCoord + float(i) * resolution + vec2(frameTimeCounter, 0.0) * 64.0) * 0.5 + 0.5) * 2.0 * Pi;
        
        //vec2 offset = vec2(cos(r) * SinTheta, sin(r) * SinTheta) * 16.0 * shadowTexelSize * rayLength;

        //vec2 offset = (float2R2(float(i)) * 2.0 - 1.0) * shadowTexelSize * 32.0;

        float r = pow(float(i + 1) * invsteps, 0.75);
        float a = (float(i) + dither) * (sqrt(5.0) - 1.0) * Pi;
        vec2 offset = vec2(cos(a) * SinTheta, sin(a) * SinTheta) * shadowTexelSize * 8.0 * float(j);

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

        float attenuation = RSMGI_Luminance;//1.0 / max(1e-5, pow2(length(halfPosition)));

        diffuse += albedo * min(1.0, ndotl * attenuation);
        weight += 1.0;
        }
    }

    //if(weight > 0.0)
    //diffuse /= weight;

    diffuse /= float(steps) * float(rounds);

    return diffuse;
}

void main() {
    Gbuffers m = GetGbuffersData(texcoord);

    Vector v = GetVector(texcoord, m.maskWeather > 0.5 ? texture(colortex4, texcoord).x : texture(depthtex0, texcoord).x);

    gl_FragData[0] = vec4(GammaToLinear(CalculateRSMGI(m, v)), v.depth);
}
/* DRAWBUFFERS:4 */