#version 130

in vec2 mc_midTexCoord;
in vec3 mc_Entity;
in vec4 at_tangent;

#define GSH

#ifdef GSH
    #define handness vhandness
    #define tileMask vTileMask
    #define texcoord vtexcoord
    #define lmcoord vlmcoord
    #define midcoord vmidcoord
    #define normal vnormal
    #define binormal vbinormal
    #define tangent vtangent
    #define color vcolor
#endif

out float tileMask;

out float handness;

out vec2 texcoord;
out vec2 lmcoord;
out vec2 midcoord;

out vec3 normal;
out vec3 tangent;
out vec3 binormal;

out vec4 color;

out vec3 worldPosition;
out vec4 vertexPosition;

#include "/libs/setting.glsl"
#include "/libs/uniform.glsl"
#include "/libs/mask_check.glsl"

void main() {
    gl_Position = ftransform();
    ApplyTAAJitter(gl_Position);

    vertexPosition = gl_Position;
    worldPosition = (gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex).xyz;

    color = gl_Color;

    vhandness = at_tangent.w;
    normal = normalize(gl_NormalMatrix * gl_Normal);
    tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
    binormal = normalize(cross(tangent, normal) * at_tangent.w);


    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    midcoord = mc_midTexCoord.xy;

    tileMask = mc_Entity.x;

    //if(mc_Entity.x == MaskIDLeaves) {
    //    tileMask = 18.0;
    //}

    if(mc_Entity.x == MaskIDGrass || mc_Entity.x == MaskIDDoublePlanetUpper || mc_Entity.x == MaskIDDoublePlanetLower) {
        tileMask = 31.0;
    }

    //if(mc_Entity.x == MaskIDDoublePlanetUpper || mc_Entity.x == MaskIDDoublePlanetLower) {
    //    tileMask = 31.0;
    //}
}