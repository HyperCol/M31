#version 130

uniform sampler2D composite;

uniform sampler2D depthtex0;
uniform float centerDepthSmooth;

in vec2 texcoord;

/*
const bool compositeMipmapEnabled = true;
*/

#include "/libs/setting.glsl"
#include "/libs/uniform.glsl"
#include "/libs/common.glsl"

void main() {
    vec3 color = LinearToGamma(textureLod(composite, texcoord, 0).rgb);

	#ifdef Camera_DOF
	#ifdef Camera_Focal_Distance_Auto
	float P = ExpToLinerDepth(centerDepthSmooth);
	#else
	float P = Camera_Focal_Distance;
	#endif

	float z = ExpToLinerDepth(texture(depthtex0, texcoord).x);

	float CoC = Camera_Aperture * ((Camera_Focal_Length * (z - P)) / (z * (P - Camera_Focal_Length)));
		  CoC = clamp(CoC, -32.0, 32.0);

	float minCoC = 0.0;
	float occlusion = 0.0;
	int occlusionCount = 0;

	float maxCoC = 0.0;
	#if 0
	for(int i = 0; i < 32; i++) {
		float stepCoC = 16.0;
		float stepLevel = log2(stepCoC) - 1.0;

		float a = (float(i) + 0.5) * (sqrt(5.0) - 1.0) * Pi;
		float r = pow(float(i + 1) / 32.0, 0.75);
		vec2 offset = vec2(cos(a) * r, sin(a) * r) * texelSize * stepCoC;

		float weight = 1.0;

		float sampleCoC = (textureLod(composite, texcoord + offset, stepLevel).a * 2.0 - 1.0) * 32.0;

		if(sampleCoC < CoC) {
			occlusion += 1.0;
			occlusionCount++;
		}

		minCoC = min(minCoC, sampleCoC);
	}

	occlusion /= 32.0;

	if(CoC > 0.0) {
		vec3 back = vec3(0.0);

		for(int i = 0; i < 32; i++) {
			float stepCoC = CoC;
			float stepLevel = log2(stepCoC) - 1.0;

			float a = (float(i) + 0.5) * (sqrt(5.0) - 1.0) * Pi;
			float r = pow(float(i + 1) / 32.0, 0.75);
			vec2 offset = vec2(cos(a) * r, sin(a) * r) * texelSize * stepCoC;

			float sampleCoC = (textureLod(composite, texcoord + offset, stepLevel).a * 2.0 - 1.0) * 32.0;
			if(sampleCoC < 0.0) offset = -offset;

			back += textureLod(composite, texcoord + offset, stepLevel).rgb;
		}

		back /= 32.0;
		back = LinearToGamma(back);

		color = back;
	}

	if(minCoC < 0.0 || CoC < 0.0) {
		vec3 fore = vec3(0.0);

		for(int i = 0; i < 32; i++) {
			float stepCoC = max(-CoC, max(-minCoC, CoC));//CoC < 0.0 ? -CoC : max(CoC, -minCoC);
			float stepLevel = log2(stepCoC) - 1.0;

			float a = (float(i) + 0.5) * (sqrt(5.0) - 1.0) * Pi;
			float r = pow(float(i + 1) / 32.0, 0.75);
			vec2 offset = vec2(cos(a) * r, sin(a) * r) * texelSize * stepCoC;

			float sampleCoC = (textureLod(composite, texcoord + offset, stepLevel).a * 2.0 - 1.0) * 32.0;
			if(sampleCoC > 0.0) offset = -offset;

			fore += textureLod(composite, texcoord + offset, stepLevel).rgb;
		}

		fore /= 32.0;
		fore = LinearToGamma(fore);

		color = mix(color, fore, vec3(CoC < 0.0 ? 1.0 : occlusion));
	}
	#else
	CoC = abs(CoC);

	if(CoC > 0.0) {
		CoC = min(32.0, CoC);

		float total = 0.0;

		color = vec3(0.0);

		for(int i = 0; i < 32; i++) {
			float a = (float(i) + 0.5) * (sqrt(5.0) - 1.0) * Pi;
			float r = pow(float(i + 1) / 32.0, 0.75);
			vec2 offset = vec2(cos(a) * r, sin(a) * r) * texelSize * CoC;

			color += textureLod(composite, texcoord + offset, log2(CoC) - 1.0).rgb;
		}

		color /= 32.0;
		color = LinearToGamma(color);
	}
	#endif
	#endif

    color = GammaToLinear(color);

    gl_FragData[0] = vec4(color, textureLod(composite, vec2(0.5), 0).a);
}
/* DRAWBUFFERS:3 */