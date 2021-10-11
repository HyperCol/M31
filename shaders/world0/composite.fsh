#version 130

#include "/libs/uniform.glsl"
#include "/libs/common.glsl"
#include "/libs/gbuffers_data.glsl"
#include "/libs/vertex_data_in.glsl"
#include "/libs/lighting/brdf.glsl"

void main() {
    //material
    Gbuffers    m = GetGbuffersData(texcoord);

    //opaque
    Vector      o = GetVector(texcoord, vec2(0.0), depthtex0);

    vec3 color = vec3(0.0);

    vec3 sunLight = DiffuseLighting(m, lightVector, o.eyeDirection);
         sunLight += SpecularLighting(m, lightVector, o.eyeDirection);

    color = sunLight;

    if(m.tile_mask == 0.0) color = vec3(1.0, 0.0, 0.0);

    color = GammaToLinear(color);

    gl_FragData[0] = vec4(color, 1.0);
}
/* DRAWBUFFERS:3 */