#version 130

#include "/libs/primitives.glsl"
#include "/libs/shadowmap/shadowmap_common.glsl"

out vec2 texcoord;

out vec4 color;

void main() {
    gl_Position = ftransform();

    gl_Position.xy *= ShadowMapDistortion(gl_Position.xy);
    gl_Position.z *= 0.2;

    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    color = gl_Color;
}