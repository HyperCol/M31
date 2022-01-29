#version 130

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

void main() {
    vec3 scattering = vec3(0.0);
    vec3 transmittance = vec3(0.0);
    float alpha = 1.0;

    //scattering = texture(colortex9, texcoord * 0.5).rgb;
    //alpha = texture(colortex9, texcoord * 0.5).a;
    //transmittance = texture(colortex10, texcoord * 0.5).rgb;

    float depth = texture(depthtex0, texcoord).x;
    float linearDepth = ExpToLinerDepth(depth);
    
    vec2 halfCoord = texcoord * 0.5;
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

    for(float i = -2.0; i <= 2.0; i += 1.0) {
        for(float j = -2.0; j <= 2.0; j += 1.0) {
            vec2 offset = vec2(i, j) * texelSize;
            vec2 coord = min(vec2(0.5) - texelSize, halfCoord + offset);

            float sampleDepth = ExpToLinerDepth(texture(colortex8, coord).y);
                  sampleDepth = (sampleDepth + ExpToLinerDepth(texture(colortex8, coord + vec2(texelSize.x, 0.0)).y) + ExpToLinerDepth(texture(colortex8, coord + vec2(0.0, texelSize.y)).y)) / 3.0;

            float diffcent = abs(sampleDepth - linearDepth);

            if(diffcent < closest.z) {
                closest = vec3(offset, diffcent);
            }
        }
    }

    closest.xy = min(vec2(0.5) - texelSize, halfCoord + closest.xy);

    float cloudsDepth = texture(colortex8, halfCoord).x;
    float linearCloudsDepth = ExpToLinerDepth(cloudsDepth);
    /*
    scattering = vec3(0.0);
    alpha = 0.0;

    float totalWeight = 0.0;

    for(float i = -1.0; i <= 1.0; i += 1.0) {
        for(float j = -1.0; j <= 1.0; j += 1.0) {
            vec2 offset = vec2(i, j) * texelSize;
            vec2 coord = min(vec2(0.5) - texelSize, closest.xy + offset);

            float sampleDepth = texture(colortex8, coord).y;
            float diffcent = abs(ExpToLinerDepth(sampleDepth) - linearDepth);

            float weight = 1.0 - min(1.0, diffcent);
            if(i == 0.0 && j == 0.0) weight = 8.0;

            scattering += texture(colortex9, coord).rgb * weight;
            alpha += texture(colortex9, coord).a * weight;
            totalWeight += weight;
        }
    }

    scattering /= totalWeight;
    alpha /= totalWeight;
    */

    transmittance = texture(colortex10, closest.xy).rgb;
    scattering = texture(colortex9, closest.xy).rgb;
    alpha = texture(colortex9, closest.xy).a;

    //if(closest.z > 10.0) scattering = vec3(1.0, 0.0, 0.0)

    vec2 velocity = GetVelocity(vec3(texcoord, cloudsDepth));
    //if(m.maskHand > 0.5) velocity *= 0.001;
    vec2 previousCoord = texcoord - velocity;
    float InScreen = step(max(abs(previousCoord.x - 0.5) + texelSize.x, abs(previousCoord.y - 0.5) + texelSize.y), 0.5);

    vec4 previousSample = texture(colortex11, previousCoord);
    float previousCloudsDepth = texture(colortex12, previousCoord).x;

    //float weight = 1.0 - min(1.0, 20000.0 * abs(ExpToLinerDepth(texture(colortex8, min(vec2(0.5) - texelSize, texcoord * 0.5 - velocity)).x) - linearCloudsDepth));
    //float weight = 1.0 - min(1.0, 0.01 * abs(ExpToLinerDepth(texture(colortex8, texcoord * 0.5 - velocity).y) - linearCloudsDepth));
    //float weight = 1.0 - abs(alpha - previousSample.a);//1.0 - min(1.0, 10000.0 * abs(ExpToLinerDepth(texture(depthtex0, previousCoord - velocity * 3.0).x) - linearDepth));

    float weight = 1.0 - min(1.0, abs(ExpToLinerDepth(previousCloudsDepth) - linearCloudsDepth) / linearCloudsDepth * 2.0);

    float blend = 0.85 * InScreen * weight;

    vec4 result = mix(vec4(scattering, alpha), previousSample, vec4(blend));
    //vec4 result = vec4(scattering, alpha);

    gl_FragData[0] = texture(colortex8, closest.xy);
    gl_FragData[1] = result;
    //gl_FragData[1] = vec4(vec3(saturate((closest.xy - halfCoord) * resolution), 0.0), 0.0);
    gl_FragData[2] = vec4(transmittance, 1.0);
    gl_FragData[3] = result;
    gl_FragData[4] = vec4(mix(cloudsDepth, previousCloudsDepth, blend), 1.0, 1.0, 1.0);
}
/* RENDERTARGETS: 8,9,10,11,12 */