#version 130

uniform sampler2D tex;
uniform sampler2D normals;
uniform sampler2D specular;

in vec2 texcoord;
in vec2 lmcoord;

in vec3 normal;
in vec3 tangent;
in vec3 binormal;

in vec4 color;

#define Alpha_Test_Reference 0.2

#include "/libs/uniform.glsl"
#include "/libs/common.glsl"
#include "/libs/mask_check.glsl"

void main() {
    vec4 albedo = texture(tex, texcoord) * color;
    vec4 texture2 = texture(normals, texcoord);
    vec4 texture3 = texture(specular, texcoord);

    mat3 tbn = mat3(tangent, binormal, normal);

    vec2 normalTexture = texture2.xy * 2.0 - 1.0;

    vec3 texturedNormal = vec3(normalTexture * 1.0, sqrt(1.0 - dot(normalTexture.xy, normalTexture.xy)));
         texturedNormal = normalize(tbn * normalize(texturedNormal));

    vec2 EncodeNormal = EncodeSpheremap(texturedNormal);

    float emissive = textureLod(specular, texcoord, 0).a;

    //if(albedo.a < Alpha_Test_Reference) discard;

    //Misc: emissive heightmap self_shadow solid_block material_ao

    //R : albedo.rg
    //G : albedo.ba
    //B : smoothness, metallic
    gl_FragData[0] = vec4(pack2x8(albedo.rg), pack2x8(albedo.b, albedo.a), pack2x8(texture3.rg), albedo.a);

    //R : light map
    gl_FragData[1] = vec4(pack2x8(lmcoord), pack2x8(texture3.b, Mask_ID_Land / 255.0), pack2x8(emissive, texture2.b), 1.0);

    //R : textured normal
    //G : textured normal
    //B : geometry normal
    gl_FragData[2] = vec4(EncodeNormal, pack2x8(EncodeSpheremap(normal)), 1.0);
}
/* DRAWBUFFERS:012 */