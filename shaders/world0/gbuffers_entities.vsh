#version 130

in vec4 at_tangent;
in vec2 mc_midTexCoord;

out vec2 midcoord;
out vec2 texcoord;
out vec2 lmcoord;

out vec3 normal;
out vec3 binormal;
out vec3 tangent;

out vec4 color;

#include "/libs/setting.glsl"
#include "/libs/uniform.glsl"

void main() {
    gl_Position = ftransform();
    ApplyTAAJitter(gl_Position);

    color = gl_Color;

    normal = normalize(gl_NormalMatrix * gl_Normal);
    tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
    binormal = cross(tangent, normal);

    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

    midcoord = mc_midTexCoord;
}