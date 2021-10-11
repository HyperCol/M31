#version 130

uniform sampler2D tex;
uniform sampler2D normals;
uniform sampler2D specular;

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
    vec4 texture2 = texture(normals, texcoord);
    vec4 texture3 = texture(specular, texcoord);

    vec2 EncodeNormal = EncodeSpheremap(normal);

    //Misc: emissive heightmap self_shadow solid_block tileMaskID material material_ao

    //R : albedo.rg
    //G : albedo.ba
    //B : smoothness, metallic
    gl_FragData[0] = vec4(pack2x8(albedo.rg), pack2x8(albedo.b, albedo.a), pack2x8(texture3.rg), 1.0);

    //R : light map
    gl_FragData[1] = vec4(pack2x8(lmcoord), pack2x8(texture3.b, Mask_ID_Water / 255.0), 0.0, 1.0);

    //R : textured normal
    //G : textured normal
    //B : geometry normal
    gl_FragData[2] = vec4(EncodeNormal, pack2x8(EncodeSpheremap(normal)), 1.0);
}
/* DRAWBUFFERS:012 */