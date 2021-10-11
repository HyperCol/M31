#version 130

/*
const int colortex0Format = RGBA16;
const int colortex1Format = RGBA16;
const int colortex2Format = RGBA16;
const int colortex3Format = RGBA16;

const float sunPathRotation = -30.0;

const float ambientOcclusionLevel = 0.0;
*/

#include "/libs/uniform.glsl"
#include "/libs/common.glsl"

uniform sampler2D composite;

in vec2 texcoord;

vec3 Uncharted2Tonemap(vec3 x) {
	const float A = 0.22f;
	const float B = 0.30f;
	const float C = 0.10f;
	const float D = 0.20f;
	const float E = 0.01f;
	const float F = 0.30f;

	return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}

vec3 ACESToneMapping(in vec3 color) {
	const float A = 2.51f;
	const float B = 0.03f;
	const float C = 2.43f;
	const float D = 0.59f;
	const float E = 0.14f;

	return (color * (A * color + B)) / (color * (C * color + D) + E);
}

void main() {
    vec3 color = LinearToGamma(texture(composite, texcoord).rgb);

    color = Uncharted2Tonemap(color);
    color = ACESToneMapping(color);

    color = GammaToLinear(color);

    gl_FragColor = vec4(color, 1.0);
}