#version 130

#define GSH

#ifndef GSH
    #define vtexcoord texcoord
    #define vlmcoord lmcoord
    #define vnormal normal
    #define vcolor color
#endif

out int vertexID;

out vec2 vtexcoord;
out vec2 vlmcoord;

out vec3 vnormal;

out vec4 vcolor;

out vec4 vertexPosition;
out vec3 worldPosition;

#include "/libs/setting.glsl"
#include "/libs/uniform.glsl"
#include "/libs/common.glsl"

void main() {
    gl_Position = ftransform();
    ApplyTAAJitter(gl_Position);

    vertexPosition = gl_Position;

    worldPosition = mat3(gbufferModelViewInverse) * nvec3(gbufferProjectionInverse * gl_Position) + gbufferModelViewInverse[3].xyz;

    vertexID = gl_VertexID % 4;

    vcolor = gl_Color;

    vnormal = vec3(1.0);

    vtexcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vlmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
}