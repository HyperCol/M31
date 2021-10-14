vec3 CalculateShading(in vec3 wP) {
    vec3 shadowCoord = ConvertToShadowCoord(wP);
    float distortion = ShadowMapDistortion(shadowCoord.xy);
    shadowCoord.xy *= distortion;
    shadowCoord = RemapShadowCoord(shadowCoord);
    shadowCoord = shadowCoord * 0.5 + 0.5;

    float bias = 10.0 / distortion;
          bias = bias * Shadow_Depth_Mul * shadowTexelSize;

    float distortionSize = shadowTexelSize;

    shadowCoord.z -= bias;

    //depth += bias;
    //float shading = step(shadowCoord.z, depth);

    float shading = 0.0;

    float dither = R2Dither(texcoord * vec2(viewWidth, viewHeight));
    float dither2 = R2Dither((1.0 - texcoord) * vec2(viewWidth, viewHeight));

    int steps = 16;
    float invsteps = 1.0 / float(steps);

    float blocker = 0.0;
    float blocker2 = 0.0;
    int blockerCount = 0;

    for(int i = 0; i < steps; i++) {
        float a = (float(i) + dither) * (sqrt(5.0) - 1.0) * Pi;
        float r = pow(float(i + 1) * invsteps, 0.75);
        vec2 offset = vec2(cos(a) * r, sin(a) * r) * shadowTexelSize * 4.0;

        float depth = texture(shadowtex0, shadowCoord.xy + offset).x;

        if(depth < shadowCoord.z) {
            blocker2 += depth * depth;
            blocker += depth;
            blockerCount++;
        }

        //shading += step(shadowCoord.z, texture(shadowtex0, shadowCoord.xy + offset).x);
    }

    if(blockerCount > 0) {
        blocker /= float(blockerCount);
        blocker2 /= float(blockerCount);
    }

    float depth = texture(shadowtex0, shadowCoord.xy).x;
    float penumbra = (shadowCoord.z - blocker) / blocker / Shadow_Depth_Mul * 32.0;
          penumbra = penumbra * shadowTexelSize + shadowTexelSize;

    for(int i = 0; i < steps; i++) {
        float a = (float(i) + dither) * (sqrt(5.0) - 1.0) * Pi;
        float r = pow(float(i + 1) * invsteps, 0.75);
        vec2 offset = vec2(cos(a) * r, sin(a) * r) * penumbra;

        shading += step(shadowCoord.z, texture(shadowtex0, shadowCoord.xy + offset).x);
    }

    shading *= invsteps;

    //float variance = blocker - blocker2;

    //shading = 1.0 - saturate(100.0 * variance / (variance + pow(shadowCoord.z - blocker, 2.0)));

    return vec3(shading);
}