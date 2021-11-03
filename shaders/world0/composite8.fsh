#version 130

uniform sampler2D composite;
uniform sampler2D colortex7;

uniform sampler2D depthtex0;

in vec2 texcoord;

/*
const bool compositeMipmapEnabled = true;
*/

#include "/libs/setting.glsl"
#include "/libs/uniform.glsl"
#include "/libs/common.glsl"

//  a b
//  r g

vec4 GatherR(in sampler2D tex, in vec2 coord, vec2 offset) {
    return vec4(texture(tex, coord).r,
                texture(tex, coord + vec2(offset.x, 0.0)).r,
                texture(tex, coord + vec2(offset.x, offset.y)).r,
                texture(tex, coord + vec2(0.0, offset.y)).r
                );
}

vec4 GatherG(in sampler2D tex, in vec2 coord, vec2 offset) {
    return vec4(texture(tex, coord).g,
                texture(tex, coord + vec2(offset.x, 0.0)).g,
                texture(tex, coord + vec2(offset.x, offset.y)).g,
                texture(tex, coord + vec2(0.0, offset.y)).g
                );
}

vec4 GatherB(in sampler2D tex, in vec2 coord, vec2 offset) {
    return vec4(texture(tex, coord).b,
                texture(tex, coord + vec2(offset.x, 0.0)).b,
                texture(tex, coord + vec2(offset.x, offset.y)).b,
                texture(tex, coord + vec2(0.0, offset.y)).b
                );
}

vec3 CalculateBloomSample(in float level, in vec2 offset) {
    vec3 color = vec3(0.0);

    vec2 coord = (texcoord - offset) * level;

    if(abs(coord.x - 0.5) >= 0.5 || abs(coord.y - 0.5) >= 0.5) return vec3(0.0);

    coord += texelSize * 0.5 * log2(level);

    float total = 0.0;

    for(float i = -1.0; i <= 1.0; i += 1.0) {
        for(float j = -1.0; j <= 1.0; j += 1.0) {
            vec2 position = vec2(i, j);

            float weight = exp(-pow2(length(position)) / 2.56);

            vec3 colorSample = texture(composite, coord + position * texelSize * level).rgb;
                 colorSample = max(floor(colorSample * 65535.0) - 255.0, vec3(0.0)) / (65535.0 - 255.0);

            color += colorSample * weight;
            total += weight;
        }   
    }

    color /= total;

    return color;
}

void main() {
    vec3 bloom = vec3(0.0);

    vec2 offset = texelSize * 4.0;

    bloom += CalculateBloomSample(8.0, offset);
    offset.x += 1.0 / 8.0 + texelSize.x * 8.0 * 2.0;
    bloom += CalculateBloomSample(12.0, offset);
    offset.x += 1.0 / 12.0 + texelSize.x * 12.0 * 2.0;
    bloom += CalculateBloomSample(16.0, offset);
    offset.x += 1.0 / 16.0 + texelSize.x * 16.0 * 2.0;
    bloom += CalculateBloomSample(24.0, offset);
    offset.x += 1.0 / 24.0 + texelSize.x * 24.0 * 2.0;
    bloom += CalculateBloomSample(32.0, offset);

    gl_FragData[0] = vec4(bloom, 1.0);
}
/* DRAWBUFFERS:2 */