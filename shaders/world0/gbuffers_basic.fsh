#version 130

uniform sampler2D tex;

in vec2 texcoord;
in vec2 lmcoord;

in vec3 normal;

in vec4 color;

#define Alpha_Test_Reference 0.2

#include "/libs/uniform.glsl"
#include "/libs/common.glsl"
#include "/libs/mask_check.glsl"

void main() {
    vec4 albedo = texture(tex, texcoord) * color;

    vec2 EncodeNormal = EncodeSpheremap(normal);

    //Misc: emissive heightmap self_shadow solid_block tileMaskID material material_ao

    if(albedo.a < Alpha_Test_Reference) discard;

    //R : albedo.rg
    //G : albedo.ba
    //B : smoothness, metallic
    gl_FragData[0] = vec4(pack2x8(albedo.rg), pack2x8(albedo.ba), 0.0, 1.0);

    //R : light map
    gl_FragData[1] = vec4(pack2x8(lmcoord), pack2x8(0.0, Mask_ID_Basic / 255.0), 0.0, 1.0);

    //R : textured normal
    //G : textured normal
    //B : geometry normal
    gl_FragData[2] = vec4(EncodeNormal, pack2x8(EncodeNormal), 1.0);
}
/* DRAWBUFFERS:012 */