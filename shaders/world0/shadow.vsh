#version 130

#include "/libs/lighting/shadowmap_common.glsl"

//#define vTileMask TileMask
//#define vnormal normal
//#define vtexcoord texcoord
//#define vcolor color

in vec3 mc_Entity;

out vec4 worldPosition;
out vec4 shadowCoord;

out float vTileMask;

out vec2 vtexcoord;
out vec2 vlmcoord;

out vec3 vnormal;

out vec4 vcolor;

void main() {
    gl_Position     = gl_ModelViewMatrix * gl_Vertex;
    shadowCoord     = shadowProjection * gl_Position;
    worldPosition   = shadowModelViewInverse * gl_Position;

    //gl_Position.xy *= ShadowMapDistortion(gl_Position.xy);
    //gl_Position.xyz = RemapShadowCoord(gl_Position.xyz);

    vTileMask = mc_Entity.x;

    vtexcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vlmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

    vnormal = normalize(gl_Normal.xyz);

    vcolor = gl_Color;
}