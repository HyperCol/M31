#version 130

/*
const int colortex0Format = RGBA16;
const int colortex1Format = RGBA16;
const int colortex2Format = RGBA16;
const int colortex3Format = RGBA16;
const int colortex7Format = RGBA16;

const bool colortex7Clear = false;

const float sunPathRotation = -30.0;

const float ambientOcclusionLevel = 0.0;
*/

#include "/libs/setting.glsl"
#include "/libs/uniform.glsl"
#include "/libs/common.glsl"

uniform sampler2D composite;
uniform sampler2D gnormal;

uniform sampler2D depthtex0;

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

vec3 saturation(in vec3 color, in float s) {
	float lum = dot(color, vec3(0.4, 0.4, 0.2));
	return max(vec3(0.0), lum + (color - lum) * s);
}

vec4 cubic(float v){
    vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
    vec4 s = n * n * n;
    float x = s.x;
    float y = s.y - 4.0 * s.x;
    float z = s.z - 4.0 * s.y + 6.0 * s.x;
    float w = 6.0 - x - y - z;
    return vec4(x, y, z, w) * (1.0/6.0);
}

vec3 textureBicubic(sampler2D sampler, vec2 texCoords){
    texCoords = texCoords * resolution - 0.5;

    vec2 fxy = fract(texCoords);
    texCoords -= fxy;

    vec4 xcubic = cubic(fxy.x);
    vec4 ycubic = cubic(fxy.y);

    vec4 c = texCoords.xxyy + vec2 (-0.5, +1.5).xyxy;

    vec4 s = vec4(xcubic.xz + xcubic.yw, ycubic.xz + ycubic.yw);
    vec4 offset = c + vec4 (xcubic.yw, ycubic.yw) / s;

    offset *= texelSize.xxyy;

    vec3 sample0 = texture(sampler, offset.xz).rgb;
    vec3 sample1 = texture(sampler, offset.yz).rgb;
    vec3 sample2 = texture(sampler, offset.xw).rgb;
    vec3 sample3 = texture(sampler, offset.yw).rgb;

    float sx = s.x / (s.x + s.y);
    float sy = s.z / (s.z + s.w);

    return mix(mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
}

vec4 GetBloomSample(inout vec2 offset, in float level) {
	vec3 color = LinearToGamma(textureBicubic(gnormal, texcoord * 0.5 / level + offset * 0.5 + texelSize * 0.5).rgb);
	float weight = exp(-pow2(log2(level) - 1.0) / 10.24);

	offset.x += 1.0 / level + texelSize.x * level * 2.0;
	
	return vec4(color * weight, weight);
}

void main() {
    vec3 color = LinearToGamma(texture(composite, texcoord).rgb);
		 color *= MappingToHDR;
	
	#if TAA_Post_Processing_Sharpeness > 0 && defined(Enabled_TAA)
	vec3 sharpen = vec3(0.0);

	for(float i = -1.0; i <= 1.0; i += 1.0) {
        for(float j = -1.0; j <= 1.0; j += 1.0) {
			if(i == 0.0 && j == 0.0) continue;
			sharpen += LinearToGamma(texture(composite, texcoord + vec2(i, j) * texelSize).rgb) * MappingToHDR;
		}
	}

	sharpen = clamp(color - sharpen / 8.0, vec3(-TAA_Post_Processing_Sharpen_Limit), vec3(TAA_Post_Processing_Sharpen_Limit));
	//if(maxComponent(abs(sharpen)) > 0.05) color = vec3(1.0, 0.0, 0.0);

	color = max(vec3(0.0), color + sharpen * 0.0625 * (TAA_Post_Processing_Sharpeness / 50.0));
	#endif

	vec4 bloom = vec4(0.0);
	float total = 0.0;

	vec2 offset = texelSize * 4.0;
	bloom += GetBloomSample(offset, 4.0);
	bloom += GetBloomSample(offset, 8.0);
	bloom += GetBloomSample(offset, 12.0);
	bloom += GetBloomSample(offset, 16.0);

	float weight0 = exp(-1e-5 / 10.24);

	bloom.rgb += color * MappingToSDR * weight0;
	bloom.a += weight0;
	bloom.rgb *= MappingToHDR / bloom.a;

	#ifdef Bloom_Intensity_Test
		color = vec3(sum3(color));
	#endif

	#ifdef Enabled_Bloom
	//color = mix(color, bloom.rgb * max(1.0, Bloom_Intensity), min(1.0, Bloom_Intensity));
	color += bloom.rgb * exp2(Bloom_Exposure_Value);
	#endif

	const float K = 12.5;

	#ifdef Camera_Average_Exposure
	float ev100 = pow(texture(composite, vec2(0.5)).a, 2.2);
          ev100 = -ev100 / (ev100 - 1.0);
		  ev100 = ev100 * MappingToHDR;
		  ev100 = pow(ev100, 0.25) / K * 100.0;	
	#else
	float ev100 = 640.0;
	#endif 

	float ev = log2(ev100) - Camera_Exposure_Value;
		  ev = clamp(ev, Camera_Exposure_Min_EV, Camera_Exposure_Max_EV);

	color *= 1.0 / (1.2 * exp2(ev));
	color *= Camera_ISO;

    color = Uncharted2Tonemap(color);
    ////color /= Uncharted2Tonemap(vec3(9.0));
	color = saturation(color, 1.2);
    //color = ACESToneMapping(color);

    color = GammaToLinear(color);

    gl_FragColor = vec4(color, 1.0);
}