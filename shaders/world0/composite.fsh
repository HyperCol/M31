#version 130

uniform sampler2D colortex3;
uniform sampler2D colortex4;

#include "/libs/setting.glsl"
#include "/libs/common.glsl"
#include "/libs/uniform.glsl"
#include "/libs/vertex_data_inout.glsl"
#include "/libs/gbuffers_data.glsl"
#include "/libs/lighting/brdf.glsl"

struct WaterData {
    float istranslucent;
    //float isblocks;

    float TileMask;

    float water;
    //float ice;
    //float slime;
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

void CalculateTranslucent(inout vec3 color, in Gbuffers m, in WaterData t, in Vector v, in Vector v1, in vec2 coord) {
    if(t.istranslucent > 0.9) {
    vec3 SunDiffuse = DiffuseLighting(m, lightVector, v.eyeDirection) * SunLightingColor * shadowFade;
    vec3 SunSpecular = SpecularLighting(m, lightVector, v.eyeDirection) * SunLightingColor * shadowFade;
    vec3 BlocksLight = (BlockLightingColor * m.albedo) * (1.0 / 4.0 * Pi) * m.lightmap.x * (m.lightmap.x * m.lightmap.x * m.lightmap.x) * (1.0 - m.metallic) * (1.0 - m.metal) * (1.0 - m.emissive);

    WaterBackface back = GetWaterBackfaceData(coord);

    if(m.maskWater > 0.9) {
        float rayLength = max(0.0, back.linearDepth - v.linearDepth);

        vec3 colorTransmittance = exp(-rayLength * (m.transmittance));
        color *= colorTransmittance;

        int steps = 12;
        float invsteps = 1.0 / float(steps);

        vec3 scattering = vec3(0.0);
        vec3 transmittance = vec3(1.0);

        float stepLength = length(nvec3(gbufferProjectionInverse * nvec4(vec3(texcoord, back.depth) * 2.0 - 1.0))) - v.viewLength;
              stepLength *= invsteps;
        //if(stepLength <= 1e-5) return;

        vec3 rayOrigin = v.wP;
        vec3 rayDirection = v.worldViewDirection * stepLength;

        float phase = HG(dot(lightVector, v.viewDirection), 0.5);

        vec3 SunLight = SunLightingColor * phase;

        for(int i = 0; i < steps; i++) {
            vec3 L = SunLight;

            vec3 stepTransmittance = exp(-stepLength * m.transmittance);

            scattering += (L - L * stepTransmittance) * transmittance;
            transmittance *= stepTransmittance;

            rayOrigin += rayDirection;
        }

        float alpha = invPi;

        color += (scattering / m.transmittance * m.scattering * m.albedo) * alpha;

        vec3 s = m.scattering  * 0.01;

        SunDiffuse *= s;
        BlocksLight *= s;
    } else {
        color = (m.albedo * SkyLightingColor) * (rescale(dot(m.texturedNormal, upVector) * 0.5 + 0.5, -0.5, 1.0) * pow2(m.lightmap.y) * m.lightmap.y * invPi);
        color += m.emissive * m.albedo * invPi;
        color *= (1.0 - m.metallic) * (1.0 - m.metal);
    }

    color += SunSpecular + SunDiffuse;

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