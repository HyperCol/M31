#version 130

uniform sampler2D tex;
uniform sampler2D normals;
uniform sampler2D specular;

uniform vec3 shadowLightPosition;

uniform ivec2 atlasSize;

in float tileMask;
in float FullSolidBlock;
in float TileResolution;

in vec2 texcoord;
in vec2 lmcoord;

in vec3 normal;
in vec3 tangent;
in vec3 binormal;

in vec3 viewDirection;
in vec3 lightDirection;

in vec4 color;

#define Alpha_Test_Reference 0.2

#include "/libs/setting.glsl"
#include "/libs/uniform.glsl"
#include "/libs/common.glsl"
#include "/libs/mask_check.glsl"

vec2 dx = dFdx(texcoord * vec2(atlasSize));
vec2 dy = dFdy(texcoord * vec2(atlasSize));
float mipmap_level = log2(max(dot(dx, dx), dot(dy, dy))) * 0.25 * Mipmaps_Levels;

vec4 GetTextureLod(in sampler2D sampler, in vec2 coord) {
    #ifdef Parallax_Mapping
    return textureLod(sampler, coord, mipmap_level);
    #else
    return texture(sampler, coord);
    #endif
}

float GetHeightMap(in vec2 coord) {
    return GetTextureLod(normals, coord).a - 1.0;
}

vec2 OffsetCoord(in vec2 coord, in vec2 offset, in vec2 size){
	vec2 offsetCoord = coord + mod(offset.xy, size);

	vec2 minCoord = vec2(coord.x - mod(coord.x, size.x), coord.y - mod(coord.y, size.y));
	vec2 maxCoord = minCoord + size;

    if(offsetCoord.x < minCoord.x){
        offsetCoord.x += size.x;
    }else if(maxCoord.x < offsetCoord.x){
        offsetCoord.x -= size.x;
    }

    if(offsetCoord.y < minCoord.y){
        offsetCoord.y += size.y;
    }else if(maxCoord.y < offsetCoord.y){
        offsetCoord.y -= size.y;
    }

	return offsetCoord;
}

vec2 ParallaxMapping(in vec2 coord, in vec3 direction, inout float depth){
    #if Parallax_Mapping_Quality < High
    int steps = 16;
    #elif Parallax_Mapping_Quality > High
    int steps = 64;
    #else
    int steps = 32;
    #endif

    float invsteps = 1.0 / float(steps);

    vec2 fAtlasSize = vec2(atlasSize);

    if(GetHeightMap(coord) >= 0.0 || min(fAtlasSize.x, fAtlasSize.y) < 1.0) return coord;

    vec2 tileSize = 1.0 / fAtlasSize;
    #ifdef Auto_Detect_Tile_Resolution
         tileSize *= round(TileResolution);
    #else
         tileSize *= Texture_Tile_Resolution;
    #endif

    vec2 parallaxDelta = direction.xy * tileSize / direction.z;
         parallaxDelta = parallaxDelta * invsteps * 0.25;
         parallaxDelta = -parallaxDelta;

    vec2 parallaxCoord = coord;

    float parallaxDepth = 0.0;

    for(int i = 0; i < steps; i++) {
        parallaxDepth -= invsteps;

        float height = GetHeightMap(parallaxCoord);
        if(parallaxDepth < height) break;

        parallaxCoord = OffsetCoord(parallaxCoord, parallaxDelta, tileSize);
    }

    depth = parallaxDepth * 0.25;

    return parallaxCoord;
}

float ParallaxSelfShadow(in vec2 coord, in vec3 direction, in float depth) {
    #if Parallax_Self_Shadow_Quality < High
    int steps = 8;
    #elif Parallax_Self_Shadow_Quality > High
    int steps = 32;
    #else
    int steps = 16;
    #endif

    float invsteps = 1.0 / float(steps);

    vec2 fAtlasSize = vec2(atlasSize);

    #ifdef Auto_Detect_Tile_Resolution
    float textureTileSize = round(TileResolution);
    #else
    float textureTileSize = Texture_Tile_Resolution;
    #endif    
    vec2 tileSize = textureTileSize / fAtlasSize;

    vec2 parallaxCoord = coord;

    #ifdef Parallax_Self_Shadow_Pixel
    parallaxCoord = floor(parallaxCoord * fAtlasSize) / fAtlasSize;
    #endif

    float height = GetHeightMap(parallaxCoord) + Parallax_Self_Shadow_Diffcent;
    if(height >= 0.0 || min(fAtlasSize.x, fAtlasSize.y) < 1.0) return 1.0;

    vec2 parallaxDelta = direction.xy * tileSize;
         parallaxDelta = parallaxDelta * invsteps * Parallax_Self_Shadow_Length;

    float shading = 1.0;

    for(int i = 0; i < steps; i++) {
        parallaxCoord = OffsetCoord(parallaxCoord, parallaxDelta, tileSize);

        #ifdef Parallax_Self_Shadow_Pixel
        float heightSample = GetHeightMap(floor(parallaxCoord * fAtlasSize) / fAtlasSize);
        #else
        float heightSample = GetHeightMap(parallaxCoord);
        #endif

        if(heightSample > height) {
            shading = 0.0;
            break;
        }
    }

    shading = mix(shading, 1.0, saturate(mipmap_level - 3.0 + 1.0));

    return shading;
}

void main() {
    vec2 coord = texcoord;

    mat3 tbn = mat3(tangent, binormal, normal);
    vec3 parallaxDirection = normalize(viewDirection * tbn);
    vec3 selfShadowDirection = normalize(lightDirection * tbn);

    float parallaxDepth = 0.0;

    #ifdef Parallax_Mapping
    if(mipmap_level < 2.0)
    coord = ParallaxMapping(coord, parallaxDirection, parallaxDepth);
    #endif

    float selfShadow = 1.0;

    #ifdef Parallax_Self_Shadow
    if(mipmap_level < 3.0)
    selfShadow = ParallaxSelfShadow(coord, selfShadowDirection, parallaxDepth);
    #endif

    vec4 baseColor = GetTextureLod(tex, coord);
    vec4 albedo = baseColor * color;
    vec4 texture2 = GetTextureLod(normals, coord);
    vec4 texture3 = GetTextureLod(specular, coord);

    float emissive = textureLod(specular, coord, 0).a;

    vec2 normalTexture = texture2.xy * 2.0 - 1.0;

    vec3 texturedNormal = vec3(normalTexture * 1.0, sqrt(1.0 - dot(normalTexture.xy, normalTexture.xy)));
         texturedNormal = normalize(tbn * normalize(texturedNormal));
    if(maxComponent(texture2.rgb) == 0.0) texturedNormal = normal;

    vec3 n = normal;

    if(!gl_FrontFacing) {
        n = -n;
        texturedNormal = -texturedNormal;
    }

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

    vec2 lightmap = lmcoord;
         lightmap = clamp(lightmap - (-parallaxDepth), vec2(0.0), vec2(1.0));

    //if(albedo.a < Alpha_Test_Reference) discard;

    //Misc: heightmap self_shadow
    gl_FragData[0] = vec4(pack2x8(albedo.rg), pack2x8(albedo.b, albedo.a), pack2x8(texture3.rg), albedo.a);
    gl_FragData[1] = vec4(pack2x8(lightmap), pack2x8(material / 255.0, max(Land, round(tileMask)) / 255.0), pack2x8(emissive, selfShadow), 1.0 - FullSolidBlock);
    gl_FragData[2] = vec4(EncodeSpheremap(texturedNormal), EncodeSpheremap(n));
}
/* DRAWBUFFERS:012 */