#version 130

uniform vec3 upPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 shadowLightPosition;

out vec2 texcoord;

out vec3 lightVector;
out vec3 worldLightVector;

out vec3 sunVector;
out vec3 worldSunVector;

out vec3 moonVector;
out vec3 worldMoonVector;

out vec3 upVector;
out vec3 worldUpVector;

#include "/libs/uniform.glsl"

void main() {
    gl_Position = ftransform();

    texcoord = gl_MultiTexCoord0.xy;

    lightVector = normalize(shadowLightPosition);
    worldLightVector = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);

    sunVector = normalize(sunPosition);
    worldSunVector = normalize(mat3(gbufferModelViewInverse) * sunPosition);

    moonVector = normalize(moonPosition);
    worldMoonVector = normalize(mat3(gbufferModelViewInverse) * moonPosition);

    upVector = normalize(upPosition);
    worldUpVector = vec3(0.0, 1.0, 0.0);
}