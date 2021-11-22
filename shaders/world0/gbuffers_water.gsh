#version 330 compatibility

layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;

in float[3] vTileMask;
in vec2[3] vtexcoord;
in vec2[3] vlmcoord;
in vec3[3] vnormal;
in vec4[3] vcolor;

in vec3[3] worldPosition;
in vec4[3] vertexPosition;

out float TileMask;
out vec2 texcoord;
out vec2 lmcoord;
out vec3 normal;
out vec4 color;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;

uniform vec3 cameraPosition;

#include "/libs/mask_check.glsl"

float sdBox( vec3 p, vec3 b ) {
    vec3 q = abs(p) - b;
    return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

void main() {
    bool selectBlock = vTileMask[0] == SlimeBlock || vTileMask[0] == HoneyBlock;

    vec3 worldNormal = mat3(gbufferModelViewInverse) * vnormal[0];
    vec3 trainglePosition = (worldPosition[0] + worldPosition[1] + worldPosition[2]) / 3.0 + cameraPosition;
    vec3 blockCenter = floor(trainglePosition - worldNormal * 0.1) + 0.5;

    if(selectBlock && sdBox(trainglePosition - blockCenter, vec3(0.0)) < 0.5) {
        gl_Position = vec4(0.0);
        EmitVertex();
        gl_Position = vec4(0.0);
        EmitVertex();
        gl_Position = vec4(0.0);
        EmitVertex();
        EndPrimitive();
    } else {   
    for(int i = 0; i < 3; i++) {
        gl_Position = vertexPosition[i];

        TileMask    = vTileMask[i];
        texcoord    = vtexcoord[i];
        lmcoord     = vlmcoord[i];
        normal      = vnormal[i];
        color       = vcolor[i];

        EmitVertex();
    }   EndPrimitive();
    }
}