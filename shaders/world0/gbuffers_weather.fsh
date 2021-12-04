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
    //albedo.a = 1.0;
    //albedo = vec4(1.0);
    //albedo.rgb = vec3(maxComponent(albedo.rgb));

    vec2 EncodeNormal = EncodeSpheremap(normal);

    if(albedo.a < Alpha_Test_Reference) discard;

    gl_FragData[0] = vec4(pack2x8(albedo.rg), pack2x8(albedo.b, albedo.a), 0.0, 1.0);
    gl_FragData[1] = vec4(pack2x8(lmcoord), pack2x8(0.0, Weather / 255.0), 0.0, 1.0);
    gl_FragData[2] = vec4(EncodeNormal, EncodeNormal);
    gl_FragData[3] = vec4(gl_FragCoord.zzz, 1.0);

    //gl_FragDepth = gl_FragCoord.z;
}
/* DRAWBUFFERS:0124 */