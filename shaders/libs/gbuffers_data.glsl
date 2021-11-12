#ifndef Include_Gbuffers_Data
#define Include_Gbuffers_Data
#endif

#define Metal_Check 0.9

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

#include "/libs/mask_check.glsl"

float MaskCheck(in float x, in float ID) {
    return step(ID - 0.5, x) * step(x, ID + 0.5);
}

struct Gbuffers {
    vec3    albedo;
    float   alpha;

    float   tile_mask;
    float   opaque;

    float   smoothness;
    float   roughness;
    float   metallic;
    float   material;
    float   metal;
    float   impermeable;
    float   porosity;
    vec3    scattering;
    vec3    absorption;
    vec3    transmittance;
    vec3    F0;

    vec2    lightmap;
    float   emissive;
    float   material_ao;

    vec3    texturedNormal;
    vec3    geometryNormal;

    float maskSky;

    float maskHand;
    float maskEntities;

    float maskLeaves;
    float maskGrass;
    float maskStemPlants;
    float maskStem;
};

Gbuffers GetGbuffersData(in vec2 coord) {
    vec4 tex0 = texture2D(colortex0, coord);
    vec4 tex1 = texture2D(colortex1, coord);
    vec4 tex2 = texture2D(colortex2, coord);

    vec4 tex0_rg    = vec4(unpack2x8(tex0.r), unpack2x8(tex0.g));
    vec2 tex0_b     = unpack2x8(tex0.b);

    Gbuffers m;

    m.albedo        = LinearToGamma(tex0_rg.rgb);
    m.alpha         = tex0_rg.a;

    m.tile_mask     = round(unpack2x8Y(tex1.y) * 255.0);
    m.opaque        = 1.0;

    m.smoothness    = tex0_b.r;
    m.metallic      = tex0_b.g;
    m.F0            = mix(vec3(m.metallic), m.albedo, step(0.9, m.metallic));
    m.roughness     = pow2(1.0 - m.smoothness);

    m.material      = unpack2x8Y(tex1.y) * 255.0;
    m.metal         = step(Metal_Check, m.metallic);
    m.impermeable   = step(m.material, 0.001);
    m.porosity      = m.material / 64.0 * step(m.material, 64.5);
    m.scattering    = vec3(0.0);
    m.absorption    = vec3(0.0);
    m.transmittance = m.scattering + m.absorption;

    m.lightmap      = saturate((unpack2x8(tex1.r) * 17.0 - 1.0) / 15.0);
    m.emissive      = floor(unpack2x8X(tex1.b) * 255.0); m.emissive = m.emissive / 254.0 * step(m.emissive, 254.5);
    m.material_ao   = 0.0;//unpack2x8Y(tex1.b);

    m.texturedNormal    = DecodeSpheremap(tex2.rg);
    m.geometryNormal    = DecodeSpheremap(unpack2x8(tex2.b));

    //m.maskSky = 
    
    //m.maskHand;
    //m.maskEntities;

    m.maskLeaves = MaskCheck(m.tile_mask, MaskIDLeaves);
    //m.maskGrass;
    //m.maskStemPlants;
    //m.maskStem;

    #ifdef Disabled_Sky_Occlusion
        m.lightmap.y = 1.0;
    #endif

    #if Sky_Light_Level_Min > 0
        m.lightmap.y = max(float(Sky_Light_Level_Min) / 15.0, m.lightmap.y);
    #endif

    return m;
} 

struct Vector {
    float depth;

    float viewLength;

    vec3 vP;
    vec3 wP;
    
    vec3 viewDirection;
    vec3 eyeDirection;

    vec3 worldViewDirection;
    vec3 worldEyeDirection;
};

Vector GetVector(in vec2 coord, sampler2D depthtex) {
    Vector v;

    v.depth = texture(depthtex, coord).x;

    v.vP = nvec3(gbufferProjectionInverse * nvec4(vec3(ApplyTAAJitter(coord), v.depth) * 2.0 - 1.0));

    v.viewLength = length(v.vP);

    v.wP = mat3(gbufferModelViewInverse) * v.vP + gbufferModelViewInverse[3].xyz;

    v.viewDirection = v.vP / v.viewLength;
    v.eyeDirection  = -v.viewDirection;

    v.worldViewDirection = v.wP / v.viewLength;
    v.worldEyeDirection  = -v.worldViewDirection;

    return v;
}