#version 130

uniform sampler2D tex;
uniform sampler2D normals;
uniform sampler2D specular;

uniform ivec2 atlasSize;

in float tileMask;
in float FullSolidBlock;
in float TileResolution;

in vec2 texcoord;
in vec2 lmcoord;

in vec3 normal;
in vec3 tangent;
in vec3 binormal;

in vec4 color;

#define Alpha_Test_Reference 0.2

#include "/libs/uniform.glsl"
#include "/libs/common.glsl"
#include "/libs/mask_check.glsl"

void main() {
    vec4 baseColor = texture(tex, texcoord);
    vec4 albedo = baseColor * color;
    vec4 texture2 = texture(normals, texcoord);
    vec4 texture3 = texture(specular, texcoord);

    float emissive = textureLod(specular, texcoord, 0).a;

    mat3 tbn = mat3(tangent, binormal, normal);

    vec2 normalTexture = texture2.xy * 2.0 - 1.0;

    vec3 texturedNormal = vec3(normalTexture * 1.0, sqrt(1.0 - dot(normalTexture.xy, normalTexture.xy)));
         texturedNormal = normalize(tbn * normalize(texturedNormal));
    if(maxComponent(texture2.rgb) == 0.0) texturedNormal = normal;

    float TileMask = round(tileMask);

    vec3 ncolor = normalize(albedo.rgb);

    float material = texture3.b * 255.0;

    float porosity = 0.0;
    float scattering = 65.0;

    if(material < 65.0) {
        if(TileMask == Grass || TileMask == Dripleaf) {
            material = scattering + 180.0;
        } else if(TileMask == StemPlants) {
            float flower = step(0.3, maxComponent(albedo.rgb));

            material = ncolor.g - max(ncolor.r, ncolor.b) + flower > 0.05 ? scattering + 180.0 : 0.0;
        } else if(TileMask == Leaves) {
            material = scattering + 200.0;
        } else if(TileMask == Vine) {
            material = scattering + 180.0;
        }
    }

    material = min(material, 255.0);

    //if(albedo.a < Alpha_Test_Reference) discard;

    //Misc: heightmap self_shadow
    gl_FragData[0] = vec4(pack2x8(albedo.rg), pack2x8(albedo.b, albedo.a), pack2x8(texture3.rg), albedo.a);
    gl_FragData[1] = vec4(pack2x8(lmcoord), pack2x8(material / 255.0, max(Land, round(tileMask)) / 255.0), pack2x8(emissive, texture2.b), 1.0 - FullSolidBlock);
    gl_FragData[2] = vec4(EncodeSpheremap(texturedNormal), EncodeSpheremap(normal));
}
/* DRAWBUFFERS:012 */