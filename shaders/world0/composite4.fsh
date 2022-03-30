#version 130

uniform sampler2D colortex2;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;

uniform sampler2D depthtex0;

const bool colortex5Clear = false;
const bool colortex6Clear = false;

#include "/libs/setting.glsl"
#include "/libs/common.glsl"
#include "/libs/uniform.glsl"

in vec2 texcoord;

vec3 projectionToScreen(in vec3 P){
    return nvec3(gbufferProjection * nvec4(P)) * 0.5 + 0.5;
}

vec2 ScreenSpaceBounce(in vec3 rayOrigin, in vec3 rayDirection) {
    vec2 hitCoord = vec2(0.0);

    int steps = 8;
    float invsteps = 1.0 / float(steps);

    float thickness = 0.19;

    vec3 rayStep = rayDirection * invsteps;

    vec3 testPoint = rayOrigin + rayStep;

    for(int i = 0; i < steps; i++) {
        vec3 coord = projectionToScreen(testPoint);
        if(abs(coord.x - 0.5) > 0.5 || abs(coord.y - 0.5) > 0.5) break;

        float sampleDepth = ExpToLinerDepth(texture(depthtex0, coord.xy).x);
        float rayDepth = ExpToLinerDepth(coord.z);

        if(sampleDepth <= rayDepth) {
            vec3 normal = DecodeSpheremap(texture(colortex2, coord.xy).xy);
            vec3 halfVector = normalize(testPoint - rayOrigin);

            if(rayDepth - sampleDepth < thickness && dot(-halfVector, normal) > 0.0) {
                hitCoord = coord.xy;
                break;
            }
        }

        testPoint += rayStep;
    }

    return hitCoord;
}

void main() {
    float depth = texture(depthtex0, texcoord).x;
    float linearDepth = ExpToLinerDepth(depth);

    vec3 vP = nvec3(gbufferProjectionInverse * nvec4(vec3(texcoord, depth) * 2.0 - 1.0));
    vec3 wP = mat3(gbufferModelViewInverse) * vP + gbufferModelViewInverse[3].xyz;

    vec3 normal = DecodeSpheremap(texture(colortex2, texcoord).rg);

    vec2 coord = clamp(texcoord * 0.5, texelSize * 2.0, 0.5 - texelSize * 2.0);
    
    vec3 color = vec3(0.0);
    float totalWeight = 0.0;
    
    vec3 closest = vec3(0.0, 0.0, 1000.0);

    for(float i = -2.0; i <= 2.0; i += 1.0) {
        for(float j = -2.0; j <= 2.0; j += 1.0) {
            vec2 sampleCoord = coord + vec2(i, j) * texelSize;

            vec3 sampleColor = texture(colortex4, sampleCoord).rgb;
            float sampleLinear = ExpToLinerDepth(texture(colortex4, sampleCoord).a);

            float weight = 1.0 - min(1.0, abs(linearDepth - sampleLinear) * 16.0);

            color += sampleColor * weight;
            totalWeight += weight;

            float difference = abs(linearDepth - sampleLinear);

            if(difference < closest.z) {
                closest = vec3(i, j, difference);
            }
        }
    }

    if(totalWeight > 0.0) {
        color /= totalWeight;
    } else {
        color = texture(colortex4, coord + closest.xy * texelSize).rgb;
    }

    vec2 velocity = GetVelocity(vec3(texcoord, depth));
    if(depth < 0.7) velocity *= 0.001;
    vec2 previousCoord = (texcoord - velocity);

    float blend = 0.95;
          blend *= step(abs(previousCoord.x - 0.5), 0.5) * step(abs(previousCoord.y - 0.5), 0.5);

    vec3 previousViewPosition = nvec3(gbufferProjectionInverse * nvec4(vec3(previousCoord, texture(depthtex0, previousCoord).x) * 2.0 - 1.0));
    vec3 halfVector = normalize(normalize(vP) / 0.9999 - normalize(previousViewPosition));

    float accumulationDepth = texture(colortex5, previousCoord).a;
    vec3 previousSampleCoord = vec3(previousCoord, accumulationDepth);
    vec3 previousSamplePosition = nvec3(gbufferProjectionInverse * nvec4(previousSampleCoord * 2.0 - 1.0));

    blend *= 1.0 - min(1.0, length(vP - previousSamplePosition) / 2.0 / max(1.0, dot(halfVector, normal) * 2.16));

    vec3 previousColor = texture(colortex5, previousCoord).rgb;

    vec3 accumulation = saturate(mix(color, previousColor, vec3(blend)));

    gl_FragData[0] = vec4(accumulation, depth);
    gl_FragData[1] = vec4(accumulation, mix(depth, accumulationDepth, blend));
}
/* DRAWBUFFERS:45 */