#version 130

uniform sampler2D tex;

uniform mat4 gbufferProjection;
uniform vec4 gbufferProjection2;
uniform vec4 gbufferProjection3;

uniform vec3 worldLightVector;

uniform float far;
uniform float near;
uniform vec2 texelSize;

in float TileMask;
in float isShadowMap;

in vec2 texcoord;
in vec2 lmcoord;

in vec3 normal;
in vec3 wP;

in vec4 color;

#include "/libs/mask_check.glsl"

float pack2x4(in vec2 x) {
    float pack = dot(round(x * 15.0), vec2(1.0, 16.0));
    return pack / 255.0;
}

float LinearToExpDepth(float linearDepth) {
    vec2 expDepth = mat2(gbufferProjection2.zw, gbufferProjection3.zw) * vec2(-linearDepth, 1.0);

    return (expDepth.x / expDepth.y) * 0.5 + 0.5;
}

void main() {
    vec4 albedo = vec4(texture(tex, texcoord).rgb, textureLod(tex, texcoord, 0).a) * color;

    float absorption = 0.0;
    float scattering = 0.0;

    float tileMask = round(TileMask);

    if(tileMask == Water) {
        scattering = 0.8;
        absorption = 8.0;

        albedo = vec4(color.rgb, 0.05);
    } else if(tileMask == Glass || tileMask == GlassPane) {

    } else if(tileMask == StainedGlass || tileMask == StainedGlassPane) {
        scattering = 0.999;
        absorption = 7.0;
    } else if(tileMask == TintedGlass) {
        scattering = 0.125;
    } else if(tileMask == SlimeBlock) {
        scattering = 0.4;
    } else if(tileMask == HoneyBlock) {
        scattering = 0.6;
    } else {
        scattering = 1.0 - albedo.a;
    }

    if(albedo.a > 0.0) albedo.a = albedo.a + 0.2;

    //scattering = (scattering * 190.0 + 65.0) / 255.0;
    absorption = absorption / 15.0;

    float packTransmittance = dot(round(vec2(absorption, scattering) * 15.0), vec2(1.0, 16.0)) / 255.0;

    float viewLength = length(wP);

    gl_FragData[0] = albedo;

    if(isShadowMap > 0.9) {
        gl_FragData[1] = vec4(normal * 0.5 + 0.5, packTransmittance);
    } else {
        gl_FragData[1] = vec4(mod(viewLength, 1.0), floor(viewLength) / 255.0, pack2x4(lmcoord), dot(worldLightVector, normal));
    }

    //gl_FragDepth = isShadowMap > 0.9 ? gl_FragCoord.z : length(wP.xyz) / 64.0;//(1.0 / -abs(wP.z)) * far * near / (far - near) + 0.5 * (far + near) / (far - near) + 0.5;
}