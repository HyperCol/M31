
#if SSAO_Stage == 0
float ScreenSpaceAmbientOcclusion(in Gbuffers m, in Vector v) {
    #if SSAO_Quality == OFF
    return 1.0;
    #else
    int steps = SSAO_Rotation_Step;
    float invsteps = 1.0 / float(steps);

    int rounds = SSAO_Direction_Step;

    if(m.maskHand > 0.9) return 1.0;

    float ao = 0.0;

    float radius = SSAO_Radius / (float(rounds) * v.viewLength);

    float dither = R2Dither(ApplyTAAJitter(texcoord) * resolution);

    for(int j = 0; j < rounds; j++){
        for(int i = 0; i < steps; i++) {
            float a = (float(i) + dither) * invsteps * 2.0 * Pi;
            vec2 offset = vec2(cos(a), sin(a)) * (float(j + 1) * radius);

            vec2 offsetCoord = texcoord + offset;
            //if(abs(offsetCoord.x - 0.5) >= 0.5 || abs(offsetCoord.y - 0.5) >= 0.5) break;

            float offsetDepth = texture(depthtex0, offsetCoord).x;

            vec3 S = nvec3(gbufferProjectionInverse * nvec4(vec3(ApplyTAAJitter(offsetCoord), offsetDepth) * 2.0 - 1.0));

            ao += ComputeAO(v.vP, m.texturedNormal, S);
            //ao += ComputeAO(v.vP, m.texturedNormal, S) * step(max(abs(offsetCoord.x - 0.5), abs(offsetCoord.y - 0.5)), 0.5);
        }
    }

    return 1.0 - ao / (float(rounds) * float(steps));
    
    #endif
}
#elif SSAO_Stage == 1
float UpResolutionAO() {
    vec3 normal = DecodeSpheremap(texture(colortex2, texcoord).xy);

    float ao = 0.0;
    float total = 0.0;

    float depth = texture(depthtex0, texcoord).x;
    float linearDepth = ExpToLinerDepth(depth);

    for(float i = -2.0; i <= 2.0; i += 1.0) {
        for(float j = -2.0; j <= 2.0; j += 1.0) {
            vec2 coord = texcoord * 0.5 + vec2(i, j) * texelSize;
                 coord = min(coord, vec2(0.5) - texelSize);

            vec3 sampleNormal = DecodeSpheremap(texture(colortex4, coord).xy);
            float sampleLinearDepth = ExpToLinerDepth(texture(depthtex0, coord / 0.25).x);

            float weight = pow(saturate(dot(sampleNormal, normal)), 128.0) * saturate(1.0 - abs(sampleLinearDepth - linearDepth) * 4.0) + 1e-5;

            ao += texture(colortex4, coord).z * weight;
            total += weight;
        }
    }

    ao /= total;

    return ao;
}
#elif SSAO_Stage == 2
//Sharpeness
#endif
