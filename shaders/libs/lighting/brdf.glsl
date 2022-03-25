float SchlickFresnel(in float cosTheta){
	return pow5(1.0 - cosTheta);
}

vec3 SchlickFresnel(in vec3 F0, in float cosTheta){
	return F0 + (1.0 - F0) * SchlickFresnel(cosTheta);
}

float DistributionTerm( float ndoth, float roughness ) {
    float a2 = max(roughness * roughness, 1e-5);
	float d	 = ( ndoth * a2 - ndoth ) * ndoth + 1.0;
	return a2 / ( d * d * Pi );
}

float SmithGGX(float cosTheta, float a2){
    float c2 = cosTheta * cosTheta;

    //return (2.0 * cosTheta) / (cosTheta + sqrt(a2 + (1.0 - a2) * c2));
    return cosTheta / (cosTheta * (1.0 - a2) + a2);
}

float VisibilityTerm(float cosTheta1, float cosTheta2, float roughness){
    
    float a = roughness;

    float Vis_SmithV = cosTheta1 * (cosTheta2 * (1.0 - a) + a);
    float Vis_SmithL = cosTheta2 * (cosTheta1 * (1.0 - a) + a);
    return 0.5 / (Vis_SmithV + Vis_SmithL);
    
    /*
    float a2 = pow2(roughness * 0.5 + 0.5) / 2.0;

    float G1 = SmithGGX(cosTheta1, a2);
    float G2 = SmithGGX(cosTheta2, a2);

    float c = 4.0 * cosTheta1 * cosTheta2 + 1e-5;

    return G1 * G2 / c;
    */   
}

vec4 ImportanceSampleGGX(in vec2 E, in float roughness){
    float a2 = roughness * roughness;

    float Phi = E.x * 2.0 * Pi;
    float CosTheta = sqrt((1.0 - E.y) / ( 1.0 + (a2 - 1.0) * E.y));
    float SinTheta = sqrt(1.0 - CosTheta * CosTheta);

    vec3 H = vec3(cos(Phi) * SinTheta, sin(Phi) * SinTheta, CosTheta);
    float D = DistributionTerm(roughness, CosTheta) * CosTheta;

    return vec4(H, D);
}

vec3 DiffuseLighting(in Gbuffers m, in vec3 L, in vec3 E) {
    float ndotv = max(0.0, dot(m.texturedNormal, E));
    float ndotl = max(0.0, dot(m.texturedNormal, L));
    float gndotl = max(0.0, dot(m.geometryNormal, L));

    if(ndotl == 0.0) return vec3(0.0);

    vec3 h = normalize(L + E);

    float hdotl = max(0.0, dot(L, h));

    vec3 kS = SchlickFresnel(m.F0, hdotl);
    vec3 kD = 1.0 - kS;

    float FD90 =  hdotl * hdotl * m.roughness * 2.0 + 0.5;
    float FDV = 1.0 + (FD90 - 1.0) * SchlickFresnel(ndotv);
    float FDL = 1.0 + (FD90 - 1.0) * SchlickFresnel(ndotl);

    vec3 diffuse = m.albedo.rgb * kD * FDL * FDV * ndotl * saturate(rescale(gndotl, 0.05, 0.1)) * invPi * (1.0 - m.metallic) * (1.0 - m.metal);

    return diffuse;
}

vec3 SpecularLighting(in Gbuffers m, in vec3 L, in vec3 E) {
    float ndotv = max(0.0, dot(m.texturedNormal, E));
    float ndotl = max(0.0, dot(m.texturedNormal, L));

    if(ndotl == 0.0 || ndotv == 0.0) return vec3(0.0);

    vec3 h = normalize(L + E);

    float ndoth = max(0.0, dot(m.texturedNormal, h));
    float hdotl = max(0.0, dot(L, h));

    vec3 f = SchlickFresnel(m.F0, hdotl);

    float d = DistributionTerm(ndoth, m.roughness);
    float g = VisibilityTerm(ndotl, ndotv, m.roughness);

    vec3 specular = f * (g * d * ndotl);

    specular *= mix(vec3(1.0), m.albedo, vec3(hdotl * m.porosity));

    return specular;
}

#define Minimum_Angle 0.0

vec3 SpecularLightingClamped(in Gbuffers m, in vec3 normal, in vec3 L, in vec3 E) {
    vec3 h = normalize(L + E);

    float ndotv = abs(dot(normal, E));
    float ndotl = abs(dot(normal, L));
    float ndoth = abs(dot(normal, h));
    float hdotl = max(0.0, dot(L, h));

    vec3 f = SchlickFresnel(m.F0, hdotl);

    float d = DistributionTerm(ndoth, m.roughness);
    float g = VisibilityTerm(ndotl, ndotv, m.roughness);

    vec3 specular = f * min(1.0, g * d * ndotl);

    specular *= mix(vec3(1.0), m.albedo, vec3(hdotl * m.porosity));

    return specular;
}