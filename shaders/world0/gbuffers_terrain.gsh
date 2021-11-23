#version 330 compatibility

layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;

in float[3] vTileMask;

in vec2[3] vtexcoord;
in vec2[3] vmidcoord;
in vec2[3] vlmcoord;

in vec3[3] vnormal;
in vec3[3] vtangent;
in vec3[3] vbinormal;

in vec4[3] vcolor;

in vec3[3] worldPosition;
in vec4[3] vertexPosition;

out float tileMask;
out float FullSolidBlock;
out float TileResolution;

out vec2 texcoord;
out vec2 lmcoord;

out vec3 normal;
out vec3 tangent;
out vec3 binormal;

out vec4 color;

uniform mat4 gbufferModelViewInverse;

uniform vec3 cameraPosition;

uniform ivec2 atlasSize;

#include "/libs/common.glsl"

void main() {
    vec3 worldNormal = mat3(gbufferModelViewInverse) * vnormal[0];
    vec3 trainglePosition = (worldPosition[0] + worldPosition[1] + worldPosition[2]) / 3.0 + cameraPosition;
    vec3 blockCenter = floor(trainglePosition - worldNormal * 0.1) + 0.5;

    vec3 dist3 = vec3(length((worldPosition[0] - worldPosition[1])), length((worldPosition[0] - worldPosition[2])), length((worldPosition[1] - worldPosition[2])));

    FullSolidBlock = 1.0;
    if(minComponent(dist3) < 1.0 - 1e-3 || sdBox(trainglePosition - blockCenter, vec3(0.0)) < 0.5) FullSolidBlock = 0.0;

    vec2 f_atlasSize = vec2(atlasSize);
    vec2 midcoord = vmidcoord[0] * f_atlasSize;

    vec2 coord0 = vtexcoord[0] * f_atlasSize;
    vec2 coord1 = vtexcoord[1] * f_atlasSize;
    vec2 coord2 = vtexcoord[2] * f_atlasSize;

    TileResolution = min(length(coord0 - coord1), min(length(coord0 - coord1), length(coord1 - coord2)));

    for(int i = 0; i < 3; i++) {
        gl_Position = vertexPosition[i];

        tileMask    = vTileMask[i];
        texcoord    = vtexcoord[i];
        lmcoord     = vlmcoord[i];
        normal      = vnormal[i];
        tangent     = vtangent[i];
        binormal    = vbinormal[i];
        color       = vcolor[i];

        EmitVertex();   
    }   EndPrimitive();
}