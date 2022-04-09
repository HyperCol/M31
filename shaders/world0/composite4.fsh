#version 130

uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;

const bool colortex5Clear = false;

#include "/libs/setting.glsl"
#include "/libs/common.glsl"
#include "/libs/uniform.glsl"
#include "/libs/vertex_data_inout.glsl"
#include "/libs/gbuffers_data.glsl"

float t(in float z){
    if(0.0 <= z && z < 0.5) return 2.0*z;
    if(0.5 <= z && z < 1.0) return 2.0 - 2.0*z;
    return 0.0;
}

float R2Dither(in vec2 coord){
    float a1 = 1.0 / 0.75487766624669276;
    float a2 = 1.0 / 0.569840290998;

    return t(mod(coord.x * a1 + coord.y * a2, 1.0));
}

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
    float viewLength = length(vP);

    vec3 normal = DecodeSpheremap(texture(colortex2, texcoord).rg);
    vec3 worldNormal = mat3(gbufferModelViewInverse) * normal;

    vec3 t = normalize(mat3(gbufferModelView) * cross(worldNormal, vec3(0.0, 1.0, 1.0)));
    vec3 b = cross(t, normal);
    mat3 tbn = mat3(t, b, normal);

    vec2 coord = clamp(texcoord * 0.375, texelSize * 3.0, 0.375 - texelSize * 3.0);
    
    vec3 centerColor = texture(colortex4, coord).rgb;
    vec3 currentColor = vec3(0.0);
    float totalWeight = 0.0;
    
    vec3 m2 = vec3(0.0);

    vec3 closest = vec3(0.0, 0.0, 1000.0);

    for(float i = -2.0; i <= 2.0; i += 1.0) {
        for(float j = -2.0; j <= 2.0; j += 1.0) {
            vec2 sampleCoord = coord + vec2(i, j) * texelSize;

            float sampleLinear = ExpToLinerDepth(texture(colortex4, sampleCoord).a);
            float difference = abs(sampleLinear - linearDepth);
            float weight = 1.0 - min(1.0, difference * 16.0);

            //vec3 sampleNormal = DecodeSpheremap(texture(colortex2, sampleCoord).rg);
            //float normalWeight = max(0.0, rescale(dot(sampleNormal, normal), 0.9999, 1.0));
            //weight *= normalWeight;

            vec3 sampleColor = texture(colortex4, sampleCoord).rgb;
            //float colorWeight = dot(vec3(1.0 / 3.0), abs(centerColor - sampleColor));
            //weight *= 1.0 - min(1.0, colorWeight * 4.0);

            //if(i == 0.0 && j == 0.0) weight = 1.0;

            currentColor += sampleColor * weight;

            totalWeight += weight;

            if(difference < closest.z) {
                closest = vec3(i, j, difference);
            }
        }
    }

    vec3 closestColor = texture(colortex4, coord + closest.xy * texelSize).rgb;

    currentColor += closestColor * 1.0;
    currentColor /= totalWeight + 1.0;

    //currentColor /= totalWeight;

    //currentColor = texture(colortex4, coord).rgb;

    //if(totalWeight > 0.0) {
    //    currentColor /= totalWeight;
    //} else {
    //    currentColor = texture(colortex4, coord + closest.xy * texelSize).rgb;
    //}

    #if 0
    float dither = R2Dither((texcoord - jitter) * resolution);
    float dither2 = R2Dither((1.0 - texcoord) * resolution);

    float CosTheta = sqrt((1.0 - dither) / ( 1.0 + (0.999 - 1.0) * dither));
    float SinTheta = sqrt(1.0 - CosTheta * CosTheta);

    vec3 direction = vec3(cos(dither2 * 2.0 * Pi) * SinTheta, sin(dither2 * 2.0 * Pi) * SinTheta, CosTheta);
    vec2 bounceCoord = ScreenSpaceBounce(vP, normalize(tbn * direction));

    if(bounceCoord.x > 0.0 && bounceCoord.y > 0.0) {
        currentColor += GammaToLinear(LinearToGamma(currentColor) + LinearToGamma(texture(colortex4, bounceCoord * 0.375).rgb));
    }
    #endif

    //currentColor = GammaToLinear(currentColor);

    vec2 velocity = GetVelocity(vec3(texcoord, depth));
    if(depth < 0.7) velocity *= 0.001;
    vec2 previousCoord = (texcoord - velocity);

    float blend = 0.98;
          blend *= step(abs(previousCoord.x - 0.5), 0.5) * step(abs(previousCoord.y - 0.5), 0.5);

    float accumulationDepth = texture(colortex5, previousCoord).a;
    float accumulationLinear = ExpToLinerDepth(accumulationDepth);
    vec3 previousSampleCoord = vec3(previousCoord, texture(depthtex0, previousCoord).x);
    vec3 previousSamplePosition = nvec3(gbufferProjectionInverse * nvec4(previousSampleCoord * 2.0 - 1.0));
    vec3 accumulationSamplePosition = nvec3(gbufferProjectionInverse * nvec4(vec3(previousCoord, accumulationDepth) * 2.0 - 1.0));

    float ndoth = abs(dot(normalize(vP / 0.999 - accumulationSamplePosition), normal));
    float ndotv = abs(dot(normalize(vP), normal));

    float blocker = length(accumulationSamplePosition);
    float penumbra = abs(length(vP) - blocker) / blocker;

    blend *= 1.0 - min(1.0, penumbra * RSMGI_Temporal_Blend * max(1.0, ndoth / max(1e-5, ndotv)));

    vec3 previousColor = texture(colortex5, previousCoord).rgb;

    vec3 accumulation = saturate(mix(currentColor, previousColor, vec3(blend)));

    Gbuffers m = GetGbuffersData(texcoord);

    vec3 color = LinearToGamma(texture(colortex3, texcoord).rgb) * MappingToHDR;

    vec3 diffuse = LinearToGamma(accumulation) * LightingColor * m.albedo * invPi;
    color += diffuse * (1.0 - m.maskSky) * (1.0 - m.maskWater) * (1.0 - m.metallic) * (1.0 - m.metal);
    //color = LinearToGamma(accumulation);
    //color = LinearToGamma(texture(colortex4, coord).rgb);
    //color = texcoord.x > 0.5 ? LinearToGamma(accumulation) : LinearToGamma(currentColor);

    //color = saturate(worldNormal);

    vec3 noTonemapping = GammaToLinear(color * MappingToSDR);

    color /= color + 1.0;
    color = GammaToLinear(color);

    gl_FragData[0] = vec4(noTonemapping, 1.0);
    gl_FragData[1] = vec4(color, 1.0);
    gl_FragData[2] = vec4(accumulation, mix(depth, accumulationDepth, blend));
}
/* DRAWBUFFERS:235 */