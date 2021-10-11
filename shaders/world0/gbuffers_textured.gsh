#version 330 compatibility

layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;

in int[3] vertexID;

in vec2[3] vtexcoord;
in vec2[3] vlmcoord;

in vec3[3] vnormal;

in vec4[3] vcolor;
in vec4[3] vertexPosition;
in vec3[3] worldPosition;

out vec2 texcoord;
out vec2 lmcoord;

out vec3 normal;

out vec4 color;

#include "/libs/uniform.glsl"
#include "/libs/common.glsl"

void main() {
    vec3 n = mat3(gbufferModelView) * normalize(cross(worldPosition[0] - worldPosition[1], worldPosition[0] - worldPosition[2]));

    for(int i = 0; i < 3; i++) {
        texcoord    = vtexcoord[i];
        lmcoord     = vlmcoord[i];

        normal      = n;

        color       = vcolor[i];

        gl_Position = vertexPosition[i];

        EmitVertex();
    } EndPrimitive();
}