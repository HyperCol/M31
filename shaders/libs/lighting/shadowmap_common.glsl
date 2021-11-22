#define Shadow_Map_Distortion 0.9

#define Shadow_Depth_Mul 0.2

const int   shadowMapResolution = 2048;
const float shadowDistance      = 128.0;

const bool shadowHardwareFiltering0 = false;
const bool shadowHardwareFiltering1 = false;

const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;
const bool shadowcolor0Nearest = true;
const bool shadowcolor1Nearest = true;

const bool shadowtex0Mipmap = false;
const bool shadowtex1Mipmap = false;
const bool shadowcolor0Mipmap = false;
const bool shadowcolor1Mipmap = false;

uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;

const float shadowTexelSize = 1.0 / float(shadowMapResolution);

float ShadowMapDistortion(in vec2 coord) {
    return 1.0 / mix(1.0, length(coord), Shadow_Map_Distortion);
}

vec3 ConvertToShadowCoord(in vec3 p) {
    vec3 shadowCoord = mat3(shadowModelView) * p + shadowModelView[3].xyz;
         shadowCoord = vec3(shadowProjection[0].x, shadowProjection[1].y, shadowProjection[2].z) * shadowCoord + shadowProjection[3].xyz;
    
    return shadowCoord;
}

vec3 RemapShadowCoord(in vec3 coord) {
    return vec3(coord.xy, coord.z * Shadow_Depth_Mul);
}

vec3 WorldPositionToShadowCoord(in vec3 p) {
    vec3 shadowCoord = ConvertToShadowCoord(p);
    shadowCoord.xy *= ShadowMapDistortion(shadowCoord.xy);
    shadowCoord = RemapShadowCoord(shadowCoord);
    shadowCoord = shadowCoord * 0.5 + 0.5;

    return shadowCoord;
}