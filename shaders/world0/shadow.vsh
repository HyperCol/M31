#version 130

#include "/libs/lighting/shadowmap_common.glsl"

#define vTileMask TileMask
#define vnormal normal

in vec3 mc_Entity;

out float vTileMask;

out vec2 texcoord;
out vec3 vnormal;
out vec4 color;

void main() {
    gl_Position = ftransform();

    gl_Position.xy *= ShadowMapDistortion(gl_Position.xy);
    gl_Position.z *= 0.2;

    TileMask = mc_Entity.x;

    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vnormal = normalize(gl_NormalMatrix * gl_Normal);
    color = gl_Color;
}