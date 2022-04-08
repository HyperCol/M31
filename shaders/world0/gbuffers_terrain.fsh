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
in float handness;

in vec3 viewDirection;
in vec3 lightDirection;

in vec4 color;

#define Alpha_Test_Reference 0.2

#include "/libs/setting.glsl"
#include "/libs/uniform.glsl"
#include "/libs/common.glsl"
#include "/libs/mask_check.glsl"

const float parallaxMappingDepth = 0.25;

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
    return (GetTextureLod(normals, coord).a - 1.0);
}

float GetHeightMapTexture(in vec2 coord) {
    return (GetTextureLod(tex, coord).a - 1.0);
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

    float stepLength = invsteps;

    vec2 parallaxDelta = direction.xy * tileSize / direction.z;
         parallaxDelta = parallaxDelta * stepLength;
         parallaxDelta = -parallaxDelta * parallaxMappingDepth;

    vec2 parallaxCoord = coord;

    float parallaxDepth = 0.0;

    for(int i = 0; i < steps; i++) {
        parallaxDepth -= stepLength;

        float height = GetHeightMap(parallaxCoord);
        if(parallaxDepth < height) break;

        parallaxCoord = OffsetCoord(parallaxCoord, parallaxDelta, tileSize);
    }

    depth = (parallaxDepth + stepLength) * parallaxMappingDepth;

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
    vec2 shadowAtlasSize = Pixel_Shadow_Resolution * fAtlasSize;

    #ifdef Auto_Detect_Tile_Resolution
    float textureTileSize = round(TileResolution);
    #else
    float textureTileSize = Texture_Tile_Resolution;
    #endif    
    vec2 tileSize = textureTileSize / fAtlasSize;

    vec2 parallaxCoord = coord;

    #ifdef Parallax_Self_Shadow_Pixel
    parallaxCoord = floor(parallaxCoord * shadowAtlasSize) / shadowAtlasSize;
    #endif

    float height = GetHeightMap(parallaxCoord) + 1.0 / 16.0;
    if(height >= 0.0 || min(fAtlasSize.x, fAtlasSize.y) < 1.0) return 1.0;

    float stepLength = invsteps;

    vec2 parallaxDelta = direction.xy * tileSize;
         parallaxDelta = parallaxDelta * stepLength * Parallax_Self_Shadow_Length;

    float shading = 1.0;

    for(int i = 0; i < steps; i++) {
        parallaxCoord = OffsetCoord(parallaxCoord, parallaxDelta, tileSize);

        #ifdef Parallax_Self_Shadow_Pixel
        float heightSample = GetHeightMap(floor(parallaxCoord * shadowAtlasSize) / shadowAtlasSize);
        #else
        float heightSample = GetHeightMap(parallaxCoord);
        #endif

        if(floor((heightSample - height) * 16.0) > 0.0) {
            shading = 0.0;
            break;
        }
    }

    shading = mix(shading, 1.0, saturate(mipmap_level - 3.0 + 1.0));

    return shading;
}

vec3 normalFromHeight(in vec2 coord, float stepSize, in vec2 tileSize) {
    vec2 e = vec2(stepSize, 0);

    float px1 = GetHeightMap(OffsetCoord(coord, -e.xy * tileSize, tileSize)) * parallaxMappingDepth;
    float px2 = GetHeightMap(OffsetCoord(coord,  e.xy * tileSize, tileSize)) * parallaxMappingDepth;
    float py1 = GetHeightMap(OffsetCoord(coord, -e.yx * tileSize, tileSize)) * parallaxMappingDepth;
    float py2 = GetHeightMap(OffsetCoord(coord,  e.yx * tileSize, tileSize)) * parallaxMappingDepth;
    
    return vec3(px1 - px2, py1 - py2, 1e-5);
}

vec3 normalFromtexture(in vec2 coord, float stepSize, in vec2 tileSize) {
    vec2 e = vec2(stepSize, 0);

    float px1 = GetHeightMapTexture(OffsetCoord(coord, -e.xy * tileSize, tileSize)) * parallaxMappingDepth;
    float px2 = GetHeightMapTexture(OffsetCoord(coord,  e.xy * tileSize, tileSize)) * parallaxMappingDepth;
    float py1 = GetHeightMapTexture(OffsetCoord(coord, -e.yx * tileSize, tileSize)) * parallaxMappingDepth;
    float py2 = GetHeightMapTexture(OffsetCoord(coord,  e.yx * tileSize, tileSize)) * parallaxMappingDepth;
    
    return vec3(px1 - px2, py1 - py2, 1e-5);
}

void main() {
    vec2 coord = texcoord;

    vec2 fAtlasSize = vec2(atlasSize);
    vec2 invAtlaSize = 1.0 / fAtlasSize;

    #ifdef Auto_Detect_Tile_Resolution
    float tileResolution = round(TileResolution);
    #else
    float tileResolution = Texture_Tile_Resolution;
    #endif

    vec2 tileSize = tileResolution / fAtlasSize;

    mat3 tbn = mat3(tangent, binormal, normal);
    vec3 parallaxDirection = normalize(viewDirection * tbn);
    vec3 selfShadowDirection = normalize(lightDirection * tbn);

    float parallaxDepth = 0.0;

    if(mipmap_level < 1.0) {
        #ifdef Parallax_Mapping
        coord = ParallaxMapping(coord, parallaxDirection, parallaxDepth);
        #endif
    }

    float selfShadow = 1.0;

    #ifdef Parallax_Self_Shadow
    if(mipmap_level < 3.0)
    selfShadow = ParallaxSelfShadow(coord, selfShadowDirection, parallaxDepth);
    #endif

    vec4 baseColor = GetTextureLod(tex, coord);
    vec4 albedo = baseColor * color;
    vec4 texture2 = GetTextureLod(normals, coord);
    vec4 texture3 = GetTextureLod(specular, coord);

    vec2 lightmap = lmcoord;
    float emissive = textureLod(specular, coord, 0).a;
    float occlusion = 0.0;

    vec3 n = normal;

    #if Parallax_Mapping_Quality < High
    int parallaxSteps = 16;
    #elif Parallax_Mapping_Quality > High
    int parallaxSteps = 64;
    #else
    int parallaxSteps = 32;
    #endif

    float depthDifference = max(0.0, GetHeightMap(coord) - parallaxDepth / parallaxMappingDepth);

    if(parallaxDepth / parallaxMappingDepth < GetHeightMap(coord) - (16.0 / 255.0) && max(fAtlasSize.x, fAtlasSize.y) > 1.0) {
        vec3 fromTexture = normalFromHeight(coord, parallaxMappingDepth / float(parallaxSteps), tileSize);

        n = normalize(tbn * fromTexture);

        tbn = mat3(tangent, normalize(cross(tangent, n) * handness), n);
    }

    vec3 fromHeightmap = normalize(normalFromHeight(coord, 1.0 / tileResolution / Pixel_Shadow_Resolution, tileSize));

    vec2 normalTexture = texture2.xy * 2.0 - 1.0;
         //normalTexture += fromHeightmap.xy * 0.25;

    vec3 texturedNormal = vec3(normalTexture, clamp(sqrt(1.0 - dot(normalTexture.xy, normalTexture.xy)), -1.0, 1.0));
         texturedNormal = normalize(tbn * texturedNormal);
    if(maxComponent(texture2.rgb) == 0.0) texturedNormal = n;

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

    if(max(fAtlasSize.x, fAtlasSize.y) > 1.0) {
        #ifdef Auto_Detect_Tile_Resolution
        vec3 offset = vec3(invAtlaSize, 0.0);
        #else
        vec3 offset = vec3(invAtlaSize, 0.0);
        #endif

        occlusion = (textureLod(tex, OffsetCoord(coord, offset.xz, tileSize), 0).a + textureLod(tex, OffsetCoord(coord, -offset.xz, tileSize), 0).a + textureLod(tex, OffsetCoord(coord, offset.zy, tileSize), 0).a + textureLod(tex, OffsetCoord(coord, -offset.zy, tileSize), 0).a) / 4.0;
        occlusion = saturate(rescale(occlusion, 0.5, 1.0));

        float depth = parallaxDepth;

        if(mipmap_level > 1.0) {
            depth = GetHeightMap(coord) * parallaxMappingDepth;
        }

        lightmap = clamp(lightmap - (-depth) * occlusion, vec2(0.0), vec2(1.0));
    }
    
    //albedo.rgb = vec3(saturate(handness * 0.5 + 0.5));
    //if(albedo.a < Alpha_Test_Reference) discard;

    //Misc: heightmap self_shadow
    gl_FragData[0] = vec4(pack2x8(albedo.rg), pack2x8(albedo.b, albedo.a), pack2x8(texture3.rg), albedo.a);
    gl_FragData[1] = vec4(pack2x8(lightmap), pack2x8(material / 255.0, max(Land, round(tileMask)) / 255.0), pack2x8(emissive, selfShadow), 1.0 - FullSolidBlock);
    gl_FragData[2] = vec4(EncodeSpheremap(texturedNormal), EncodeSpheremap(n));
}
/* DRAWBUFFERS:012 */