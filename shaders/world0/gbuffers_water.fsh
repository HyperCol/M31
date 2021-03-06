#version 130

uniform sampler2D tex;
uniform sampler2D normals;
uniform sampler2D specular;

uniform sampler2D colortex4;

in float TileMask;

in vec2 texcoord;
in vec2 lmcoord;

in vec3 normal;
in vec3 binormal;
in vec3 tangent;

in vec4 color;

#define Alpha_Test_Reference 0.2

#include "/libs/uniform.glsl"
#include "/libs/common.glsl"
#include "/libs/mask_check.glsl"

void main() {
    #if MC_VERSION < 11500
        //fix particles
        if(texture(colortex4, gl_FragCoord.xy * texelSize).z < gl_FragCoord.z) discard;
    #endif

    vec4 albedo = texture(tex, texcoord) * color;
    vec4 texture2 = texture(normals, texcoord);
    vec4 texture3 = texture(specular, texcoord);

    mat3 tbn = mat3(tangent, binormal, normal);

    vec2 normalMap = texture2.xy * 2.0 - 1.0;
    vec3 texturedNormal = normalize(tbn * vec3(normalMap, clamp(sqrt(1.0 - dot(normalMap, normalMap)), -1.0, 1.0)));

    vec2 EncodeNormal = EncodeSpheremap(texturedNormal);

    float tileMask = round(TileMask);

    if(tileMask == Water && !gl_FrontFacing) {
        discard;
    }

    if(!gl_FrontFacing) {
        gl_FragData[3] = vec4(EncodeNormal, gl_FragCoord.z, 1.0);
        gl_FragDepth = LinerToExpDepth(ExpToLinerDepth(gl_FragCoord.z) * 1.001);
        return;
    }else{
        gl_FragData[3] = vec4(0.0);
        gl_FragDepth = gl_FragCoord.z;
    }

    float smoothness    = texture3.r;
    float metallic      = max(0.02, texture3.g);
    float scattering    = 0.9;
    float absorption    = 0.0;

    if(tileMask == Water) {
        smoothness = 0.995;
        metallic = 0.02;
        scattering = 0.8;
        absorption = 8.0;

        albedo = vec4(color.rgb, 0.05);
    } else if(tileMask == Glass || tileMask == GlassPane) {
        albedo.a = max(albedo.a, 0.005);
        smoothness = 0.9;
        metallic = 0.04;
        scattering = 0.999;
        absorption = 1.0;
    } else if(tileMask == StainedGlass || tileMask == StainedGlassPane) {
        metallic = 0.04;
        scattering = 0.999;

        absorption = tileMask == GlassPane || tileMask == StainedGlassPane ? 15.0 : 7.0;
    } else if(tileMask == TintedGlass) {
        scattering = 0.125;
    } else if(tileMask == SlimeBlock) {
        scattering = 0.4;
    } else if(tileMask == HoneyBlock) {
        scattering = 0.6;
    } else {
        scattering = 1.0 - albedo.a;
    }

    scattering = (scattering * 190.0 + 65.0) / 255.0;

    gl_FragData[0] = vec4(pack2x8(albedo.rg), pack2x8(albedo.b, albedo.a), pack2x8(smoothness, metallic), 1.0);
    gl_FragData[1] = vec4(pack2x8(lmcoord), pack2x8(scattering, Water / 255.0), absorption / 255.0, 1.0);
    gl_FragData[2] = vec4(EncodeNormal, tileMask / 65535.0, 1.0);
}
/* DRAWBUFFERS:0124 */