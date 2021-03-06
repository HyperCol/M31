float ShadowTextureGather(in sampler2D tex, in vec2 coord) {
    float depth0 = texture(tex, coord.xy).x;
    float depth1 = max(texture(tex, coord.xy + vec2(shadowTexelSize, 0.0)).x, texture(tex, coord.xy - vec2(shadowTexelSize, 0.0)).x);
    float depth2 = max(texture(tex, coord.xy + vec2(0.0, shadowTexelSize)).x, texture(tex, coord.xy - vec2(0.0, shadowTexelSize)).x);

    return max(depth2, max(depth1, depth0));
}

vec3 CalculateShadowVisbility(in vec3 coord) {
    if(abs(coord.x / shadowMapScale.x - 0.5) >= 0.5 || abs(coord.y / shadowMapScale.y - 0.5) >= 0.5 || coord.z >= 1.0 - 1e-5) return vec3(1.0);

    float d0 = ShadowTextureGather(shadowtex0, coord.xy);
    float d1 = ShadowTextureGather(shadowtex1, coord.xy);

    float v0 = step(coord.z, d0);
    float v1 = step(coord.z, d1);

    vec3 albedo = LinearToGamma(texture(shadowcolor0, coord.xy).rgb);
    float alpha = max(0.0, texture(shadowcolor0, coord.xy).a - 0.2) / 0.8;
    vec2 coe = unpack2x4(texture(shadowcolor1, coord.xy).a);
    
    float absorption = saturate(coe.x * 15.0 * alpha * 0.25);
    float scattering = saturate((1.0 - coe.y) * 16.0 * alpha * 0.25);

    return mix(vec3(1.0), mix(vec3(1.0), albedo, vec3(absorption)) * (1.0 - scattering), vec3(max(0.0, v1 - v0))) * v1;
}

vec3 CalculateShading(in vec3 coord, in vec3 lightDirection, in vec3 normal, in float material_bias) {
    float ndotl = dot(lightDirection, normal);
    if(ndotl < 0.0 && material_bias < 1e-5) return vec3(0.0);

    vec3 worldNormal = mat3(gbufferModelViewInverse) * normal;

    coord.xy = ApplyTAAJitter(coord.xy);

    vec3 viewPosition = nvec3(gbufferProjectionInverse * nvec4(vec3(coord.xy, coord.z) * 2.0 - 1.0));
    vec3 worldPosition = mat3(gbufferModelViewInverse) * viewPosition + gbufferModelViewInverse[3].xyz;

    vec3 shadowCoord = ConvertToShadowCoord(worldPosition + worldNormal * pow5(1.0 - abs(ndotl)) * 0.25);
    float distortion = ShadowMapDistortion(shadowCoord.xy);
    shadowCoord.xy *= distortion;
    shadowCoord = RemapShadowCoord(shadowCoord);
    shadowCoord = shadowCoord * 0.5 + 0.5;

    float bias = max(1.0 + material_bias, 8.0 / distortion);
          bias = bias * Shadow_Depth_Mul * shadowTexelSize;

    shadowCoord.z -= bias;

    float TexelBlurRadius = shadowTexelSize * distortion * 0.125;

    vec3 shading = vec3(0.0);

    float dither = R2Dither(ApplyTAAJitter(texcoord) * vec2(viewWidth, viewHeight));

    const float radius = 4.0;

    #if Soft_Shadow_Quality == OFF
    //shading = step(shadowCoord.z, texture(shadowtex1, shadowCoord.xy).x);
    return CalculateShadowVisbility(shadowCoord);
    #else

    #if Soft_Shadow_Quality == Ultra
    int steps = 32;
    float invsteps = 1.0 / float(steps);
    #else
    int steps = 16;
    float invsteps = 1.0 / float(steps);
    #endif

    #if Soft_Shadow_Penumbra != PCSS
    float penumbra = TexelBlurRadius * 0.125 * Soft_Shadow_Penumbra / Shadow_Depth_Mul;
    #else
    float blocker = 0.0;
    int blockerCount = 0;

    float blocker2 = 0.0;
    int blockerCount2 = 0;

    for(int i = 0; i < steps; i++) {
        float a = (float(i) + dither) * (sqrt(5.0) - 1.0) * Pi;
        float r = pow(float(i + 1) * invsteps, 0.99);
        vec2 offset = vec2(cos(a) * r, sin(a) * r) * TexelBlurRadius * 4.0;

        float depth1 = texture(shadowtex1, shadowCoord.xy + offset).x;
        float depth0 = texture(shadowtex0, shadowCoord.xy + offset).x;

        if(depth1 < shadowCoord.z) {
            blocker += depth1;
            blockerCount++;
        }

        if(depth0 < shadowCoord.z) {
            blocker2 += depth0;
            blockerCount2++;           
        }
    }

    if(blockerCount2 == 0 && blockerCount == 0) return vec3(1.0);

    blocker /= blockerCount > 0 ? float(blockerCount) : 1.0;
    blocker2 /= blockerCount2 > 0 ? float(blockerCount2) : 1.0;

    float penumbra = min((shadowCoord.z - blocker) / blocker, (shadowCoord.z - blocker2) / blocker2);
          penumbra = min(penumbra / Shadow_Depth_Mul * 32.0 + 1.0, 16.0) * TexelBlurRadius;
    #endif

    for(int i = 0; i < steps; i++) {
        float a = (float(i) + dither) * (sqrt(5.0) - 1.0) * Pi;
        float r = pow(float(i + 1) * invsteps, 0.75);
        vec2 offset = vec2(cos(a) * r, sin(a) * r) * penumbra;

        shading += CalculateShadowVisbility(shadowCoord + vec3(offset, 0.0));//step(shadowCoord.z, texture(shadowtex1, shadowCoord.xy + offset).x);
    }

    shading *= invsteps;
    #endif

    return shading;
}