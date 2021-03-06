#version 130

uniform sampler2D gnormal;
uniform sampler2D colortex7;

uniform sampler2D depthtex0;

in vec2 texcoord;

#include "/libs/setting.glsl"
#include "/libs/uniform.glsl"
#include "/libs/common.glsl"

void main() {
    if(texcoord.y > 0.5) {
        gl_FragData[0] = vec4(0.0);
    }else{

    vec3 color = vec3(0.0);
    float total = 0.0;

    vec2 coord = texcoord;

    for(float i = -2.0; i <= 2.0; i += 1.0) {
        for(float j = -2.0; j <= 2.0; j += 1.0) {
            vec2 position = vec2(i, j);

            float weight = exp(-pow2(length(position)) / 2.56);

            color += LinearToGamma(texture(gnormal, coord * 0.5 + position * texelSize).rgb) * weight * MappingToHDR;
            total += weight;
        }
    }

    color /= total;
    color = GammaToLinear(color * MappingToSDR);

    gl_FragData[0] = vec4(color, 1.0);
    }
}
/* DRAWBUFFERS:2 */