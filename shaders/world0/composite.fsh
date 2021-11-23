#version 130

uniform sampler2D colortex3;
uniform sampler2D colortex4;

float t(in float z){
  if(0.0 <= z && z < 0.5) return 2.0*z;
  if(0.5 <= z && z < 1.0) return 2.0 - 2.0*z;
  return 0.0;
}

float R2Dither(in vec2 coord){
  float a1 = 1.0 / 0.75487766624669276;
  float a2 = 1.0 / 0.569840290998;

  return mod(coord.x * a1 + coord.y * a2, 1.0);
}

#include "/libs/setting.glsl"
#include "/libs/common.glsl"
#include "/libs/uniform.glsl"
#include "/libs/vertex_data_inout.glsl"
#include "/libs/gbuffers_data.glsl"
#include "/libs/lighting/brdf.glsl"
#include "/libs/lighting/shadowmap_common.glsl"
#include "/libs/lighting/shadowmap.glsl"

struct WaterData {
    float istranslucent;
    //float isblocks;

    float TileMask;

    float water;
    //float ice;
    float slime_block;
    float honey_block;
    //float glass;
    ////float glass_pane;
    ////float stained_glass;
    ////float stained_glass_pane;
};

WaterData GetWaterData(in vec2 coord) {
    WaterData w;

    w.istranslucent = texture(colortex0, coord).a;
    //w.isblocks = 

    w.TileMask  =  round(texture(colortex2, coord).b * 65535.0);
    w.water     = MaskCheck(w.TileMask, Water);
    w.slime_block = MaskCheck(w.TileMask, SlimeBlock);
    w.honey_block = MaskCheck(w.TileMask, HoneyBlock);

    return w;
}

struct WaterBackface {
    vec3 normal;
    float depth;
    float linearDepth;
};

WaterBackface GetWaterBackfaceData(in vec2 coord) {
    WaterBackface w;

    w.normal = DecodeSpheremap(texture(colortex4, coord).rg);

    w.depth = texture(colortex4, coord).z;
    w.linearDepth = ExpToLinerDepth(w.depth);

    return w;
}

vec3 Diffusion(in float depth, in vec3 t) {
    return exp(-depth * t) / (4.0 * Pi * t * max(1.0, depth));
}

void CalculateTranslucent(inout vec3 color, in Gbuffers m, in WaterData t, in Vector v, in Vector v1, in vec2 coord) {
    vec3 worldNormal = mat3(gbufferModelViewInverse) * m.texturedNormal;
    vec3 worldPosition = v.wP + cameraPosition;
    vec3 blockCenter = floor(worldPosition - worldNormal * 0.1) + 0.5;

    vec2 tracing = IntersectCube(worldPosition, v.worldViewDirection, blockCenter, vec3(0.5));

    if(t.istranslucent > 0.9) {
    vec3 SunDiffuse = DiffuseLighting(m, lightVector, v.eyeDirection) * SunLightingColor * shadowFade;
    vec3 SunSpecular = SpecularLighting(m, lightVector, v.eyeDirection) * SunLightingColor * shadowFade;
    vec3 BlocksLight = (BlockLightingColor * m.albedo) * (1.0 / 4.0 * Pi) * m.lightmap.x * (m.lightmap.x * m.lightmap.x * m.lightmap.x) * (1.0 - m.metallic) * (1.0 - m.metal) * (1.0 - m.emissive);

    WaterBackface back = GetWaterBackfaceData(coord);

    float dither = R2Dither(ApplyTAAJitter(texcoord) * resolution);
    //if(t.water > 0.1) dither = mix(dither, 1.0, 0.5);

    if(t.water > 0.1) {
        vec3 shadowViewStepPosition = mat3(shadowModelView) * (v1.wP) + shadowModelView[3].xyz;
        vec3 shadowCoord = vec3(shadowProjection[0].x, shadowProjection[1].y, shadowProjection[2].z) * shadowViewStepPosition + shadowProjection[3].xyz;
        vec2 shadowCoordOrigin = shadowCoord.xy;
        shadowCoord.xy *= ShadowMapDistortion(shadowCoord.xy);
        shadowCoord = RemapShadowCoord(shadowCoord);
        shadowCoord = shadowCoord * 0.5 + 0.5;

        vec3 shadowViewPosition = vec3(shadowProjectionInverse[0].x, shadowProjectionInverse[1].y, shadowProjectionInverse[2].z) * vec3(shadowCoordOrigin, (texture(shadowtex0, shadowCoord.xy).x * 2.0 - 1.0) / Shadow_Depth_Mul) + shadowProjectionInverse[3].xyz;

        vec3 albedo = LinearToGamma(texture(shadowcolor0, shadowCoord.xy).rgb);
        float alpha = max(0.0, texture(shadowcolor0, shadowCoord.xy).a - 0.2) / 0.8;
        vec2 coe = unpack2x4(texture(shadowcolor1, shadowCoord.xy).a);
    
        vec3 absorption = (coe.x * 15.0 * alpha) * (1.0 - clamp(pow(albedo + 1e-5, vec3(1.0 / 2.718)), vec3(1e-3), vec3(0.9)));
        float scattering = (1.0 - coe.y) * 16.0 * alpha;

        float opticalDepth = max(0.0, length(shadowViewStepPosition - shadowViewPosition) - 0.01);

        vec3 depthExtinction = exp(-m.transmittance * max(0.0, v1.viewLength - v.viewLength));
        vec3 lightExtinction = exp(-(absorption * opticalDepth + scattering * opticalDepth));

        color *= mix(depthExtinction, lightExtinction, vec3(step(0.6, texture(colortex3, coord).a)));
    }
    if(m.maskWater > 0.9) {
        float rayLength = max(0.0, back.linearDepth - v.linearDepth);

        //vec3 colorTransmittance = exp(-rayLength * (m.transmittance));
        //color *= colorTransmittance;

        int steps = 12;
        float invsteps = 1.0 / float(steps);

        vec3 scattering = vec3(0.0);
        vec3 transmittance = vec3(1.0);

        vec3 viewBorder = vec3( abs(IntersectPlane(vec3(0.0), v.worldViewDirection, vec3(far + 16.0, 0.0, 0.0), vec3(1.0, 0.0, 0.0))),
                                0.0,
                                abs(IntersectPlane(vec3(0.0), v.worldViewDirection, vec3(0.0, 0.0, far + 16.0), vec3(0.0, 0.0, 1.0))));

        float end = length(nvec3(gbufferProjectionInverse * nvec4(vec3(texcoord, back.depth) * 2.0 - 1.0)));
        float start = v.viewLength; 

        end = min(min(viewBorder.x, viewBorder.z), end);

        float stepLength = end - start;

        if(stepLength > 1e-5) {
            stepLength = stepLength + m.alpha * 0.5;
            stepLength *= invsteps;

        vec3 rayOrigin = v.wP;
        vec3 rayDirection = v.worldViewDirection * stepLength;

        vec3 rayPosition = rayOrigin + rayDirection * dither;

        float phase = mix(HG(dot(lightVector, v.viewDirection), -0.1), HG(dot(lightVector, v.viewDirection), 0.5), 0.3);

        vec3 SunLight = SunLightingColor * phase;

        for(int i = 0; i < steps; i++) {
            vec2 tracingLight = IntersectCube(rayPosition + cameraPosition, worldLightVector, blockCenter, vec3(0.5));

            vec3 shadowViewStepPosition = mat3(shadowModelView) * (rayPosition) + shadowModelView[3].xyz;
            vec3 shadowCoord = vec3(shadowProjection[0].x, shadowProjection[1].y, shadowProjection[2].z) * shadowViewStepPosition + shadowProjection[3].xyz;
            vec2 shadowCoordOrigin = shadowCoord.xy;
            float distortion = ShadowMapDistortion(shadowCoord.xy);
                 shadowCoord.xy *= distortion;
                 shadowCoord = RemapShadowCoord(shadowCoord);
                 shadowCoord = shadowCoord * 0.5 + 0.5;
            float visibility = step(shadowCoord.z - shadowTexelSize, texture(shadowtex1, shadowCoord.xy).x);

            vec3 shadowViewPosition = vec3(shadowProjectionInverse[0].x, shadowProjectionInverse[1].y, shadowProjectionInverse[2].z) * vec3(shadowCoordOrigin, (texture(shadowtex0, shadowCoord.xy).x * 2.0 - 1.0) / Shadow_Depth_Mul) + shadowProjectionInverse[3].xyz;

            vec3 albedo = LinearToGamma(texture(shadowcolor0, shadowCoord.xy).rgb);
            float alpha = max(0.0, texture(shadowcolor0, shadowCoord.xy).a - 0.2) / 0.8;

            vec2 coe = unpack2x4(texture(shadowcolor1, shadowCoord.xy).a);
            float absorption0 = coe.x * 15.0 * alpha;
            float scattering0 = (1.0 - coe.y) * 16.0 * alpha;
            vec3 lightViewA = absorption0 * (1.0 - clamp(pow(albedo + 1e-5, vec3(1.0 / 2.718)), vec3(1e-3), vec3(0.9)));

            float opticalDepth = max(length(shadowViewStepPosition - shadowViewPosition) - 0.01, 0.0);
            vec3 lightExtinction = exp(-(lightViewA * opticalDepth + scattering0 * opticalDepth));

            vec3 L = SunLight * lightExtinction * visibility;

            float density = 1.0;

            float maxDistance = maxComponent(abs(rayPosition + cameraPosition - blockCenter));

            if(t.slime_block > 0.9) {
                density += (maxDistance < 0.3125 ? 8.0 : 0.0);
            }else if(t.honey_block > 0.9) {
                density += (maxDistance < 0.4375 ? 8.0 : 0.0);
            }

            vec3 stepTransmittance = exp(-stepLength * density * m.transmittance);

            scattering += (L - L * stepTransmittance) * transmittance / (density * 2.0) * density;
            transmittance *= stepTransmittance;

            rayPosition += rayDirection;
        }

        float alpha = invPi;

        color *= transmittance;
        color += (scattering / m.transmittance * m.scattering * m.albedo) * alpha;
        }

        vec3 s = m.scattering  * 0.01;

        SunDiffuse *= s;
        BlocksLight *= s;
    } else {
        color = (m.albedo * SkyLightingColor) * (rescale(dot(m.texturedNormal, upVector) * 0.5 + 0.5, -0.5, 1.0) * pow2(m.lightmap.y) * m.lightmap.y * invPi);
        color += m.emissive * m.albedo * invPi;
        color *= (1.0 - m.metallic) * (1.0 - m.metal);
    }

    vec3 shading = CalculateShading(vec3(texcoord, v.depth), lightVector, m.geometryNormal, 0.0);

    color += SunSpecular * shading;
    color += SunDiffuse * shading;
    color += BlocksLight;
    }
}

/*
vec3 CalculateRefraction(in Gbuffers m, in WaterData w, in Vector v, in Vector v1, in vec2 coord) {
    WaterBackface back = GetWaterBackfaceData(coord);

    vec3 color = texture(colortex3, coord).rgb;

    if(m.maskWater > 0.9) {
        vec3 direction = normalize(refract(v.viewDirection, m.texturedNormal, 1.000293 / F0ToIOR(max(0.02, m.metallic))));
        float rayLength = w.water > 0.9 ? clamp(v1.linearDepth - v.linearDepth, 0.0, 1.0) : max(0.0, back.linearDepth - v.linearDepth);

        vec3 rayDirection = v.vP + direction * rayLength;
        vec2 refractionCoord = nvec3(gbufferProjection * nvec4(v.vP + direction * rayLength)).xy * 0.5 + 0.5;

        color = texture(colortex3, refractionCoord).rgb;

        vec3 transmittance = exp(-rayLength * 8.0 * (m.scattering + m.absorption));
        color *= transmittance;
    }

    return color;
}
*/
void main() {
    //materials
    Gbuffers m = GetGbuffersData(texcoord);

    WaterData t = GetWaterData(texcoord);

    //opaque
    Vector v0 = GetVector(texcoord, depthtex0);
    Vector v1 = GetVector(texcoord, depthtex1);

    vec3 color = texture(colortex3, texcoord).rgb;//CalculateRefraction(m, t, v0, v1, texcoord);
         color = LinearToGamma(color) * MappingToHDR;

    CalculateTranslucent(color, m, t, v0, v1, texcoord);

    color = color / (color + 1.0);
    color = GammaToLinear(color);

    gl_FragData[0] = vec4(color, 1.0);
}
/* DRAWBUFFERS:3 */