#version 130

#include "/libs/setting.glsl"
#include "/libs/uniform.glsl"

uniform vec3 upVector;
uniform vec3 sunVector;
uniform vec3 moonVector;
uniform vec3 lightVector;
uniform vec3 worldUpVector;
uniform vec3 worldSunVector;
uniform vec3 worldMoonVector;
uniform vec3 worldLightVector;

#include "/libs/common.glsl"
#include "/libs/gbuffers_data.glsl"
#include "/libs/volumetric/atmospheric_common.glsl"
#include "/libs/volumetric/atmospheric.glsl"

in vec2 texcoord;

void main() {
    Vector v = GetVector(texcoord, texture(depthtex0, texcoord).x);

    vec3 atmosphere_color = vec3(0.0);
    vec3 atmosphere_transmittance = vec3(1.0);

    CalculateAtmosphericScattering(atmosphere_transmittance, atmosphere_color, vec3(0.0, planet_radius + max(1.0, (cameraPosition.y - 63.0) * 1.0), 0.0), v.worldViewDirection, worldSunVector, worldMoonVector, vec2(0.0));

    gl_FragData[0] = vec4(atmosphere_color, 1.0);
    gl_FragData[1] = vec4(atmosphere_transmittance, 1.0);
}
/* DRAWBUFFERS:34 */