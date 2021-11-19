#version 130

uniform sampler2D colortex3;
uniform sampler2D colortex4;

in vec2 texcoord;

#include "/libs/setting.glsl"
#include "/libs/common.glsl"
#include "/libs/uniform.glsl"
#include "/libs/gbuffers_data.glsl"

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

    w.istranslucent = step(texture(colortex0, coord).a, 0.9);
    //w.isblocks = 

    w.TileMask  =  round(texture(colortex2, coord).b * 65535.0);
    w.water     = MaskCheck(w.TileMask, Water);

    return w;
}

struct WaterBackface {
    vec3 normal;
    float depth;
};

WaterBackface GetWaterBackfaceData(in vec2 coord) {
    WaterBackface w;

    w.normal = DecodeSpheremap(texture(colortex4, coord).rg);
    w.depth = texture(colortex4, coord).z;

    return w;
}

vec3 CalculateRefraction(in Gbuffers m, in WaterData w, in Vector v, in vec2 coord) {
    WaterBackface back = GetWaterBackfaceData(coord);

    if(m.maskWater > 0.9) {
        vec3 direction = normalize(refract(v.viewDirection, m.texturedNormal, 1.000293 / F0ToIOR(max(0.02, m.metallic))));
        float rayLength = w.water > 0.9 ? clamp(ExpToLinerDepth(texture(depthtex1, coord).x) - ExpToLinerDepth(v.depth), 0.0, 1.0) : max(0.0, ExpToLinerDepth(back.depth) - ExpToLinerDepth(v.depth));

        coord = nvec3(gbufferProjection * nvec4(v.vP + direction * rayLength)).xy * 0.5 + 0.5;
    }

    return texture(colortex3, coord).rgb;
}

void main() {
    //materials
    Gbuffers m = GetGbuffersData(texcoord);

    WaterData w = GetWaterData(texcoord);

    //opaque
    Vector v0 = GetVector(texcoord, depthtex0);
    Vector v1 = GetVector(texcoord, depthtex1);

    float solid = step(texture(colortex0, texcoord).a, 0.9);

    vec3 color = CalculateRefraction(m, w, v0, texcoord);//texture(colortex3, texcoord).rgb;
         color = LinearToGamma(color) * MappingToHDR;

    //color = mix(color, vec3(1.0, 0.0, 0.0), vec3((1.0 - solid) * m.maskWater));

    //if()

    //color = texture(colortex4, texcoord).rgb;

    color = color / (color + 1.0);
    color = GammaToLinear(color);

    gl_FragData[0] = vec4(color, 1.0);
}
/* DRAWBUFFERS:3 */