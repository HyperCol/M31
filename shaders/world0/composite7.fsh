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

vec3 RGBToYCoCg(vec3 c) {
	// Y = R/4 + G/2 + B/4
	// Co = R/2 - B/2
	// Cg = -R/4 + G/2 - B/4

    return vec3(c.x/4.0 + c.y/2.0 + c.z/4.0,
                c.x/2.0 - c.z/2.0,
                -c.x/4.0 + c.y/2.0 - c.z/4.0);
}

vec3 YCoCgToRGB(vec3 c) {
	// R = Y + Co - Cg
	// G = Y + Cg
	// B = Y - Co - Cg

    return vec3(c.x + c.y - c.z,
             c.x + c.z,
	         c.x - c.y - c.z);
}

vec3 clipToAABB(vec3 color, vec3 minimum, vec3 maximum) {
    #ifndef TAA_No_Clip
    vec3 p_clip = 0.5 * (maximum + minimum);
    vec3 e_clip = 0.5 * (maximum - minimum);

    vec3 v_clip = color - p_clip;
    vec3 v_unit = v_clip.xyz / e_clip;
    vec3 a_unit = abs(v_unit);
    float ma_unit = max(a_unit.x, max(a_unit.y, a_unit.z));

    if (ma_unit > 1.0) return p_clip + v_clip / ma_unit;
    #endif
    
    return color;// point inside aabb
}

vec4 ReprojectSampler(in sampler2D tex, in vec2 pixelPos){
    vec4 result = vec4(0.0);

    vec2 position = resolution * pixelPos;
    vec2 centerPosition = floor(position - 0.5) + 0.5;

    vec2 f = position - centerPosition;
    vec2 f2 = f * f;
    vec2 f3 = f * f2;

    float c = 0.6 + (TAA_Accumulation_Shapress / 50.0 - 1.0) * 0.2;
    vec2 w0 =         -c  *  f3 + 2.0 * c          *  f2 - c  *  f;
    vec2 w1 =  (2.0 - c)  *  f3 - (3.0 - c)        *  f2            + 1.0;
    vec2 w2 = -(2.0 - c)  *  f3 + (3.0 - 2.0 * c)  *  f2 + c  *  f;
    vec2 w3 =          c  *  f3 - c                *  f2;
    vec2 w12 = w1 + w2;

    vec2 tc12 = texelSize * (centerPosition + w2 / w12);
    vec2 tc0 = texelSize * (centerPosition - 1.0);
    vec2 tc3 = texelSize * (centerPosition + 2.0);

    result =  vec4(texture(tex, vec2(tc12.x, tc0.y)).rgb, 1.0) * (w12.x * w0.y) +
              vec4(texture(tex, vec2(tc0.x, tc12.y)).rgb, 1.0) * (w0.x * w12.y) +
              vec4(texture(tex, vec2(tc12.x, tc12.y)).rgb, 1.0) * (w12.x * w12.y) +
              vec4(texture(tex, vec2(tc3.x, tc12.y)).rgb, 1.0) * (w3.x * w12.y) +
              vec4(texture(tex, vec2(tc12.x, tc3.y)).rgb, 1.0) * (w12.x * w3.y);

    result /= result.a;
    result.rgb = saturate(result.rgb);

    return result;
}

vec3 GetVariance(in vec2 coord, out vec3 minColor, out vec3 maxColor) {
    vec3 m1 = vec3(0.0);
    vec3 m2 = vec3(0.0);

    for(float i = -1.0; i <= 1.0; i += 1.0) {
        for(float j = -1.0; j <= 1.0; j += 1.0) {
            vec3 sampleColor = RGBToYCoCg(textureLod(composite, coord + vec2(i, j) * texelSize, 0).rgb);

            m1 += sampleColor;
            m2 += sampleColor * sampleColor;
        }
    }

    m1 /= 9.0;
    m2 /= 9.0;

    vec3 variance = sqrt(abs(m1 * m1 - m2));

    const float sigma = 2.0;

    minColor = m1 - variance * sigma;
    maxColor = m1 + variance * sigma;

    return variance;
}

vec3 GetClosest(in vec2 coord) {
    vec3 closest = vec3(0.0, 0.0, 1.0);

    for(float i = -1.0; i <= 1.0; i += 1.0) {
        for(float j = -1.0; j <= 1.0; j += 1.0) {
            float depth = texture(depthtex0, coord + vec2(i, j) * texelSize).x;

            if(depth < closest.z) {
                closest = vec3(i, j, depth);
            }
        }
    }

    closest.xy = closest.xy * texelSize + coord;

    return closest;
}

void main() {
    //exposure
    vec3 centerSample = textureLod(composite, vec2(0.5), log2(viewHeight)).rgb;

    float exposureCurrent = luminance3(centerSample);

    float exposurePrevious = texture(colortex7, vec2(0.5)).a;
    bool blank = exposurePrevious == 0;
    if(blank) exposurePrevious = exposureCurrent;

    float updateRate = 1.0;
    float counter = mod(frameTimeCounter * updateRate, Camera_Exposure_Delay);
    float update = round(counter);

    //float weight = (frameTimeCounter + 1.0) / float(frameCounter + 45);
    float weight = saturate((counter - mod(frameTimeCounter * 0.5, Camera_Exposure_Delay)) / Camera_Exposure_Delay);

    float exposureResult = mix(exposurePrevious, exposureCurrent, weight);

    //taa
    vec3 color = RGBToYCoCg(textureLod(composite, texcoord, 0).rgb);

    vec3 maxColor = vec3( 1.0);
    vec3 minColor = vec3(-1.0);
    vec3 variance = GetVariance(texcoord, minColor, maxColor);

    vec3 closest = GetClosest(texcoord);
    //vec3 closest = vec3(texcoord, texture(depthtex0, texcoord).x);
    vec2 velocity = GetVelocity(closest);
    if(closest.z < 0.7) velocity *= 0.001;
    float velocityLength = length(velocity * resolution);

    vec2 previousCoord = texcoord - velocity;
    float InScreen = step(max(abs(previousCoord.x - 0.5), abs(previousCoord.y - 0.5)), 0.5);

    vec3 previousColor = RGBToYCoCg(ReprojectSampler(colortex7, previousCoord).rgb);

    float blend = 0.95 * InScreen;
          blend -= step(0.05, velocityLength) * clamp(rescale(sum3(YCoCgToRGB(variance)), 0.05, 0.5), 0.5, 1.0) * 0.05;

    vec3 accumulation = clipToAABB(previousColor, minColor, maxColor);
         accumulation = mix(color, accumulation, vec3(blend));

    #if Camera_Shutter_Speed > 0
    float shutter = (1.0 - 4.0 / (Camera_FPS)) * (Camera_Shutter_Speed / 100.0);

    accumulation = mix(accumulation, previousColor, min(0.95, shutter) * InScreen);
    #endif

    accumulation = YCoCgToRGB(accumulation);

    //result
    vec3 outputColor = LinearToGamma(accumulation);
    outputColor = -outputColor / (min(vec3(1e-8), outputColor) - 1.0);
    outputColor *= MappingToSDR;
    outputColor = GammaToLinear(outputColor);

    gl_FragData[0] = vec4(outputColor, exposureResult);
    gl_FragData[1] = vec4(accumulation, exposureResult);
}
/* DRAWBUFFERS:37 */