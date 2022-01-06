#ifndef INCLUDED_NOISE
#define INCLUDED_NOISE
uniform sampler2D noisetex;

const int noiseTextureResolution = 64;

float noise(in vec2 x){
    return texture(noisetex, x / noiseTextureResolution).x;
}

float noise(in vec3 x) {
    vec3 i = floor(x);
    vec3 f = fract(x);

	f = f*f*(3.0-2.0*f);

	vec2 uv = (i.xy + i.z * vec2(17.0)) + f.xy;
    uv += 0.5;

	vec2 rg = vec2(noise(uv), noise(uv+17.0));

	return mix(rg.x, rg.y, f.z);
}
#endif