#version 330 compatibility

layout(triangles) in;
layout(triangle_strip, max_vertices = 9) out;

uniform int entityId;

uniform vec2 resolution;
uniform float aspectRatio;
uniform float far;
uniform float near;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform vec4 gbufferProjection0;
uniform vec4 gbufferProjection1;
uniform vec4 gbufferProjection2;
uniform vec4 gbufferProjection3;

in vec4[3] shadowCoord;
in vec4[3] worldPosition;

in float[3] vTileMask;
in vec2[3]  vtexcoord;
in vec2[3]  vlmcoord;
in vec3[3]  vnormal;
in vec4[3]  vcolor;

out float isShadowMap;

out float TileMask;

out vec2 texcoord;
out vec2 lmcoord;

out vec3 normal;
out vec3 wP;

out vec4  color;

#include "/libs/lighting/shadowmap_common.glsl"

vec3 nvec3(in vec4 x) {
    return x.xyz / x.w;
}

vec4 nvec4(in vec3 x) {
    return vec4(x, 1.0);
}

vec4 DualParaboloidMapping(in vec4 position, in bool neg) {
    //position.xyz = position.xzy;
    //position.y /= aspectRatio;
    //position.z *= 1080.0 / resolution.y;

    float L = length(position.xyz);
    float Z = !neg ? -position.z : position.z;

    vec4 coord = vec4((position.xy / L) / (1.0 + Z / L), 0.0, 1.0);
         coord.y = -coord.y;
         coord.xy *= 0.75;

    return coord;
}

void main() {
    isShadowMap = 0.0;

    #if MC_VERSION >= 11605
    mat4 gbufferProjectionFix = mat4(gbufferProjection0, gbufferProjection1, gbufferProjection2, gbufferProjection3);
    #else
    mat4 gbufferProjectionFix = gbufferProjection;
    #endif

    vec3 triangleCenter = (worldPosition[0].xyz + worldPosition[1].xyz + worldPosition[2].xyz) / 3.0;

    bool isplayer = entityId == 1 && length(triangleCenter) < 1.0;

    if(max(worldPosition[0].z, max(worldPosition[1].z, worldPosition[2].z)) > 0.0 && !isplayer) {
    for(int i = 0; i < 3; i++) {
        gl_Position = worldPosition[i];
        wP = gl_Position.xyz;

        gl_Position = gbufferProjectionFix * gl_Position;
        gl_Position = DualParaboloidMapping(gl_Position, false);

        gl_Position.xy = gl_Position.xy * 0.5 + 0.5;
        gl_Position.x *= 0.5;
        gl_Position.xy = gl_Position.xy * shadowMapScale + (1.0 - shadowMapScale);
        gl_Position.xy = clamp(gl_Position.xy, vec2(0.0, shadowMapScale.y), vec2(0.5, 1.0));
        gl_Position.xy = gl_Position.xy * 2.0 - 1.0;

        gl_Position.z = length(wP) / 120.0 * 2.0 - 1.0;

        TileMask    = vTileMask[i];
        texcoord    = vtexcoord[i];
        lmcoord     = vlmcoord[i];
        normal      = vnormal[i];
        color       = vcolor[i];

        isShadowMap = 0.0;

        EmitVertex();   
    }   EndPrimitive();
    } else {
        gl_Position = vec4(0.0);
        EmitVertex();
        gl_Position = vec4(0.0);
        EmitVertex();
        gl_Position = vec4(0.0);
        EmitVertex();
        EndPrimitive();
    }

    if(min(worldPosition[0].z, min(worldPosition[1].z, worldPosition[2].z)) < 0.0 && !isplayer) {
    for(int i = 0; i < 3; i++) {
        gl_Position = worldPosition[i];
        wP = gl_Position.xyz;

        gl_Position = gbufferProjectionFix * gl_Position;
        gl_Position = DualParaboloidMapping(gl_Position, true);

        gl_Position.xy = gl_Position.xy * 0.5 + 0.5;
        gl_Position.x = gl_Position.x * 0.5 + (1.0 - 0.5);
        gl_Position.xy = gl_Position.xy * shadowMapScale + (1.0 - shadowMapScale);
        gl_Position.xy = clamp(gl_Position.xy, vec2(0.5, shadowMapScale.y), vec2(1.0, 1.0));
        gl_Position.xy = gl_Position.xy * 2.0 - 1.0;

        gl_Position.z = length(wP) / 120.0 * 2.0 - 1.0;

        TileMask    = vTileMask[i];
        texcoord    = vtexcoord[i];
        lmcoord     = vlmcoord[i];
        normal      = vnormal[i];
        color       = vcolor[i];

        isShadowMap = 0.0;

        EmitVertex();   
    }   EndPrimitive();
    } else {
        gl_Position = vec4(0.0);
        EmitVertex();
        gl_Position = vec4(0.0);
        EmitVertex();
        gl_Position = vec4(0.0);
        EmitVertex();
        EndPrimitive();
    }

    for(int i = 0; i < 3; i++) {
        gl_Position = shadowCoord[i];
        gl_Position.xy *= ShadowMapDistortion(gl_Position.xy);
        gl_Position.xyz = RemapShadowCoord(gl_Position.xyz);

        TileMask    = vTileMask[i];
        texcoord    = vtexcoord[i];
        normal      = vnormal[i];
        color       = vcolor[i];

        isShadowMap = 1.0;

        EmitVertex();   
    }   EndPrimitive();
}