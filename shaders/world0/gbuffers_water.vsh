#version 130

in vec3 mc_Entity;
in vec4 at_tangent;

#define GSH

#ifdef GSH
    #define TileMask vTileMask
    #define texcoord vtexcoord
    #define lmcoord vlmcoord
    #define normal vnormal
    #define color vcolor
#endif

out float TileMask;

out vec2 texcoord;
out vec2 lmcoord;

out vec3 normal;

out vec3 worldPosition;
out vec4 vertexPosition;

out vec4 color;

#include "/libs/setting.glsl"
#include "/libs/uniform.glsl"
#include "/libs/mask_check.glsl"

void main() {
    TileMask = 0.0;

    if(mc_Entity.x == Water) TileMask = Water;
    if(mc_Entity.x == Ice) TileMask = Ice;
    if(mc_Entity.x == SlimeBlock) TileMask = SlimeBlock;
    if(mc_Entity.x == Glass) TileMask = Glass;
    if(mc_Entity.x == GlassPane) TileMask = GlassPane;
    if(mc_Entity.x == StainedGlass) TileMask = StainedGlass;
    if(mc_Entity.x == StainedGlassPane) TileMask = StainedGlassPane;

    gl_Position = ftransform();
    ApplyTAAJitter(gl_Position);

    worldPosition = (gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex).xyz;
    vertexPosition = gl_Position;

    color = gl_Color;

    normal = normalize(gl_NormalMatrix * gl_Normal);

    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
}