#version 130

uniform sampler2D tex;
uniform sampler2D normals;
uniform sampler2D specular;

uniform vec4 entityColor;

uniform int entityId;

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
    vec4 albedo = texture(tex, texcoord) * color;
         albedo.rgb = mix(albedo.rgb, entityColor.rgb, vec3(entityColor.a));

    if(entityId == 37) {
        float face_tile = 8.0;

        vec2 right_eye_center = vec2(0.125 + 0.125 / face_tile * 2.0, 0.25 + 0.125 / face_tile * 6.0);

        if(max(abs(texcoord.x - right_eye_center.x), abs(texcoord.y - right_eye_center.y) * 0.5) < 0.125 / face_tile) {
            albedo.rgb = mix(vec3(10.0 / 255.0), albedo.rgb, vec3(albedo.a * 0.5));
        }

        vec2 left_eye_center = vec2(0.125 + 0.125 / face_tile * 6.0, 0.25 + 0.125 / face_tile * 6.0);

        if(max(abs(texcoord.x - left_eye_center.x), abs(texcoord.y - left_eye_center.y) * 0.5) < 0.125 / face_tile) {
            albedo.rgb = mix(vec3(10.0 / 255.0), albedo.rgb, vec3(albedo.a * 0.5));
        }

        vec2 mouth_center = vec2(0.125 + 0.125 / face_tile * 4.5, 0.25 + 0.125 / face_tile * 11.0);

        if(max(abs(texcoord.x - mouth_center.x), abs(texcoord.y - mouth_center.y) * 0.5) < 0.125 * 0.5 / face_tile) {
            albedo.rgb = mix(vec3(10.0 / 255.0), albedo.rgb, vec3(albedo.a * 0.5));
        }
    }

    vec4 texture2 = texture(normals, texcoord);
    vec4 texture3 = texture(specular, texcoord);

    mat3 tbn = mat3(tangent, binormal, normal);
    
    vec3 n = normal;
    vec3 texturedNormal = vec3(texture2.xy * 2.0 - 1.0, 1.0);
         texturedNormal = normalize(tbn * vec3(texturedNormal.xy, sqrt(1.0 - dot(texturedNormal.xy, texturedNormal.xy))));

    if(!gl_FrontFacing) {
        n = -n;
        texturedNormal = -texturedNormal;
    }

    float emissive = textureLod(specular, texcoord, 0).a;
    float selfShadow = 1.0;

    //Misc: emissive heightmap self_shadow solid_block tileMaskID material material_ao

    if(albedo.a < Alpha_Test_Reference) discard;

    //R : albedo.rg
    //G : albedo.ba
    //B : smoothness, metallic
    gl_FragData[0] = vec4(pack2x8(albedo.rg), pack2x8(albedo.b, albedo.a), pack2x8(texture3.rg), 1.0);

    //R : light map
    gl_FragData[1] = vec4(pack2x8(lmcoord), pack2x8(texture3.b, Mask_ID_Entities / 255.0), pack2x8(emissive, selfShadow), 1.0);

    //R : textured normal
    //G : textured normal
    //B : geometry normal
    gl_FragData[2] = vec4(EncodeSpheremap(texturedNormal), EncodeSpheremap(n));
}
/* DRAWBUFFERS:012 */