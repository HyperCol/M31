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
		 color *= MappingToHDR;
	#ifdef Camera_DOF
	#ifdef Camera_Focal_Distance_Auto
	float P = ExpToLinerDepth(centerDepthSmooth);
	#else
	float P = Camera_Focal_Distance;
	#endif

	float z = ExpToLinerDepth(texture(depthtex0, texcoord).x);

	float A = 2.8;
	float F = 0.004;

	float CoC = Camera_Aperture * ((Camera_Focal_Length * (z - P)) / (z * (P - Camera_Focal_Length)));

	CoC = abs(CoC);

	if(CoC > 0.0) {
	color = vec3(0.0);

	CoC = min(32.0, abs(CoC));

	float total = 0.0;

	for(int i = 0; i < 32; i++) {
        float a = (float(i) + 0.5) * (sqrt(5.0) - 1.0) * Pi;
        float r = pow(float(i + 1) / 32.0, 0.75);
        vec2 offset = vec2(cos(a) * r, sin(a) * r) * texelSize * CoC;

		float weight = 1.0;

		color += textureLod(composite, texcoord + offset, log2(CoC) - 1.0).rgb * weight;
		total += 1.0;
	}

	color /= total;

	color = LinearToGamma(color);
	color *= MappingToHDR;
	}
	#endif
    color *= MappingToSDR;
    color = GammaToLinear(color);

    gl_FragData[0] = vec4(color, textureLod(composite, vec2(0.5), 0).a);
}
/* DRAWBUFFERS:3 */