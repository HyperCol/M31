#version 130

#define Atmospheric_Rendering_Scale 0.375               //[0.375 0.5 0.7]

uniform sampler2D colortex8;
uniform sampler2D colortex9;
uniform sampler2D colortex10;
uniform sampler2D colortex11;
uniform sampler2D colortex12;

uniform sampler2D depthtex0;

in vec2 texcoord;

const bool colortex11Clear = false;
const bool colortex12Clear = false;

#include "/libs/setting.glsl"
#include "/libs/common.glsl"
#include "/libs/uniform.glsl"

const vec2[4] jitter2x2 = vec2[4](vec2(0.0, 0.0), vec2(0.0, 1.0), vec2(1.0, 1.0), vec2(1.0, 0.0));

void main() {
    float depth = texture(depthtex0, texcoord).x;
    float linearDepth = ExpToLinerDepth(depth);
    
    vec2 halfCoord = texcoord * Atmospheric_Rendering_Scale;
/*
    scattering = vec3(0.0);
    alpha = 0.0;

    float totalWeight = 0.0;

    for(float i = -1.0; i <= 1.0; i += 1.0) {
        for(float j = -1.0; j <= 1.0; j += 1.0) {
            vec2 offset = vec2(i, j) * texelSize;
            vec2 coord = min(vec2(0.5) - texelSize, halfCoord + offset);

            float sampleDepth = texture(colortex8, coord).y;
            float diffcent = abs(ExpToLinerDepth(sampleDepth) - linearDepth);

            float weight = exp(-diffcent);

            scattering += texture(colortex9, coord).rgb * weight;
            alpha += texture(colortex9, coord).a * weight;
            totalWeight += weight;
        }
    }

    if(totalWeight > 0.0) {
        scattering /= totalWeight;
        alpha /= totalWeight;
    }
*/

    vec3 closest = vec3(0.0, 0.0, 10000.0);

    for(float i = -1.0; i <= 1.0; i += 1.0) {
        for(float j = -1.0; j <= 1.0; j += 1.0) {
            vec2 offset = vec2(i, j) * texelSize;
            vec2 coord = min(vec2(Atmospheric_Rendering_Scale) - texelSize, halfCoord + offset);

            float sampleDepth = ExpToLinerDepth(texture(colortex8, coord).y);
                  //sampleDepth = (sampleDepth + ExpToLinerDepth(texture(colortex8, coord + vec2(texelSize.x, 0.0)).y) + ExpToLinerDepth(texture(colortex8, coord + vec2(0.0, texelSize.y)).y)) / 3.0;
/*
            float weight = 1.0;
            sampleDepth += ExpToLinerDepth(texture(colortex8, coord + vec2(texelSize.x, 0.0)).y) * weight;
            sampleDepth += ExpToLinerDepth(texture(colortex8, coord - vec2(texelSize.x, 0.0)).y) * weight;
            sampleDepth += ExpToLinerDepth(texture(colortex8, coord + vec2(0.0, texelSize.y)).y) * weight;
            sampleDepth += ExpToLinerDepth(texture(colortex8, coord - vec2(0.0, texelSize.y)).y) * weight;
            sampleDepth /= 1.0 + weight * 4.0;
*/
            float diffcent = abs(sampleDepth - linearDepth);

            if(diffcent < closest.z) {
                closest = vec3(offset, diffcent);
            }
        }
    }

    closest.xy = min(vec2(Atmospheric_Rendering_Scale) - texelSize, halfCoord + closest.xy);

    vec3 closest2 = vec3(0.0, 0.0, 10000.0);

    for(float i = -1.0; i <= 1.0; i += 1.0) {
        for(float j = -1.0; j <= 1.0; j += 1.0) {
            vec2 offset = vec2(i, j) * texelSize;
            vec2 coord = min(vec2(Atmospheric_Rendering_Scale) - texelSize, closest.xy + offset);

            float sampleDepth = ExpToLinerDepth(texture(colortex8, coord).y);
                  //sampleDepth = (sampleDepth + ExpToLinerDepth(texture(colortex8, coord + vec2(texelSize.x, 0.0)).y) + ExpToLinerDepth(texture(colortex8, coord + vec2(0.0, texelSize.y)).y)) / 3.0;

            float weight = 1.0;
            sampleDepth += ExpToLinerDepth(texture(colortex8, coord + vec2(texelSize.x, 0.0)).y) * weight;
            sampleDepth += ExpToLinerDepth(texture(colortex8, coord - vec2(texelSize.x, 0.0)).y) * weight;
            sampleDepth += ExpToLinerDepth(texture(colortex8, coord + vec2(0.0, texelSize.y)).y) * weight;
            sampleDepth += ExpToLinerDepth(texture(colortex8, coord - vec2(0.0, texelSize.y)).y) * weight;
            sampleDepth /= 1.0 + weight * 4.0;

            float diffcent = abs(sampleDepth - linearDepth);

            if(diffcent < closest2.z) {
                closest2 = vec3(offset, diffcent);
            }
        }
    }

    closest.xy = min(vec2(Atmospheric_Rendering_Scale) - texelSize, closest.xy + closest2.xy);

    float rayDepth = texture(colortex8, closest.xy).x;

    float cloudsDepth = rayDepth;
    float linearCloudsDepth = ExpToLinerDepth(cloudsDepth);
    
    #if Near_Atmosphere_Upscale_Quality < High
    vec3 transmittance = texture(colortex10, closest.xy).rgb;
    vec3 scattering = texture(colortex9, closest.xy).rgb;
    float alpha = texture(colortex9, closest.xy).a;
    #else
    vec3 scattering = vec3(0.0);
    float alpha = 0.0;

    vec3 transmittance = texture(colortex10, closest.xy).rgb;

    float totalWeight = 0.0;

    for(float i = -1.0; i <= 1.0; i += 1.0) {
        for(float j = -1.0; j <= 1.0; j += 1.0) {
            vec2 offset = vec2(i, j) * texelSize;
            vec2 coord = min(vec2(Atmospheric_Rendering_Scale) - texelSize, closest.xy + offset);

            float sampleDepth = texture(colortex8, coord).y;
            float diffcent = abs(ExpToLinerDepth(sampleDepth) - linearDepth);

            float weight = 1.0 - min(1.0, diffcent);
            if(i == 0.0 && j == 0.0) weight = 6.0;

            scattering += texture(colortex9, coord).rgb * weight;
            alpha += texture(colortex9, coord).a * weight;
            totalWeight += weight;
        }
    }

    scattering /= totalWeight;
    alpha /= totalWeight;
    #endif

    vec2 velocity = GetVelocity(vec3(texcoord, rayDepth));
    //if(m.maskHand > 0.5) velocity *= 0.001;
    vec2 previousCoord = texcoord - velocity;
    float InScreen = step(max(abs(previousCoord.x - 0.5) + texelSize.x, abs(previousCoord.y - 0.5) + texelSize.y), 0.5);

    vec4 previousSample = texture(colortex11, previousCoord);
    float previousCloudsDepth = texture(colortex12, previousCoord).x;
    float previousLinearDepth = ExpToLinerDepth(previousCloudsDepth);

    //float weight = 1.0 - min(1.0, 20000.0 * abs(ExpToLinerDepth(texture(colortex8, min(vec2(0.5) - texelSize, texcoord * 0.5 - velocity)).x) - linearCloudsDepth));
    //float weight = 1.0 - min(1.0, 0.01 * abs(ExpToLinerDepth(texture(colortex8, texcoord * 0.5 - velocity).y) - linearCloudsDepth));
    //float weight = 1.0 - abs(alpha - previousSample.a);//1.0 - min(1.0, 10000.0 * abs(ExpToLinerDepth(texture(depthtex0, previousCoord - velocity * 3.0).x) - linearDepth));

    float sigma = rayDepth < 0.99999 ? 8.0 : 1.0;
    float weight = 1.0 - min(1.0, abs(previousLinearDepth - linearCloudsDepth) / linearCloudsDepth * sigma);

    vec2 jitterfragCoord = floor(texcoord * resolution) + round(jitter * resolution);
    float update = min(mod(jitterfragCoord.x, 2.0), mod(jitterfragCoord.y, 2.0));
          update = mix(update, 1.0, 0.7);

    float blend = 0.98 * InScreen * weight;

    vec4 result = mix(vec4(scattering, alpha), previousSample, vec4(blend));
    //vec4 result = vec4(scattering, alpha);
    //result.rgb = texture(colortex9, texcoord * 0.5).rgb;

    gl_FragData[0] = texture(colortex8, closest.xy);
    gl_FragData[1] = result;
    //gl_FragData[1] = vec4(vec3(saturate((closest.xy - halfCoord) * resolution), 0.0), 0.0);
    gl_FragData[2] = vec4(transmittance, 1.0);
    gl_FragData[3] = result;
    gl_FragData[4] = vec4(mix(cloudsDepth, previousCloudsDepth, blend), 1.0, 1.0, 1.0);
}
/* RENDERTARGETS: 8,9,10,11,12 */