#version 130

uniform sampler2D colortex3;

#include "/libs/setting.glsl"
#include "/libs/common.glsl"
#include "/libs/uniform.glsl"

in vec2 texcoord;

void main() {
    vec3 color = LinearToGamma(texture(colortex3, texcoord).rgb) * MappingToHDR;

    vec3 noTonemapping = GammaToLinear(color * MappingToSDR);

    color = color / (color + 1.0);
    color = GammaToLinear(color);

    gl_FragData[0] = vec4(noTonemapping, 1.0);
    gl_FragData[1] = vec4(color, 1.0);
}
/* DRAWBUFFERS:23 */