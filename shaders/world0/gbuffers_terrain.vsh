#version 130

in vec3 mc_Entity;
in vec4 at_tangent;

out float tileMask;

out vec2 texcoord;
out vec2 lmcoord;

out vec3 normal;
out vec3 tangent;
out vec3 binormal;

out vec4 color;

#include "/libs/setting.glsl"
#include "/libs/uniform.glsl"
#include "/libs/mask_check.glsl"

void main() {
    gl_Position = ftransform();
    ApplyTAAJitter(gl_Position);

    color = gl_Color;

    normal = normalize(gl_NormalMatrix * gl_Normal);
    tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
    binormal = cross(tangent, normal);

    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

    tileMask = Mask_ID_Land;

    if(mc_Entity.x == MaskIDLeaves) {
        tileMask = 18.0;
    }
}