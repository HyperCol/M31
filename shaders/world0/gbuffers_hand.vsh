#version 130

out vec2 texcoord;
out vec2 lmcoord;

out vec3 normal;

out vec4 color;

#include "/libs/setting.glsl"
#include "/libs/uniform.glsl"

void main() {
    gl_Position = ftransform();
    ApplyTAAJitter(gl_Position);

    color = gl_Color;

    normal = normalize(gl_NormalMatrix * gl_Normal);

    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
}