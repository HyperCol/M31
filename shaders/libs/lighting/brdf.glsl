float SchlickFresnel(in float cosTheta){
	return pow5(1.0 - cosTheta);
}

vec3 SchlickFresnel(in vec3 F0, in float cosTheta){
	return F0 + (1.0 - F0) * SchlickFresnel(cosTheta);
}

float DistributionTerm( float ndoth, float roughness ) {
	float d	 = ( ndoth * roughness - ndoth ) * ndoth + 1.0;
	return roughness / ( d * d * Pi );
}

float SmithGGX(float cosTheta, float roughness){
    float r2 = roughness * roughness;
    float c2 = cosTheta * cosTheta;

    return (2.0 * cosTheta) / (cosTheta + sqrt(r2 + (1.0 - r2) * c2));
}

float VisibilityTerm(float cosTheta1, float cosTheta2, float roughness){
    return SmithGGX(cosTheta1, roughness) * SmithGGX(cosTheta2, roughness);
}

vec4 ImportanceSampleGGX(in vec2 E, in float roughness){
    E.y = mix(E.y, 0.0, 0.7);

    float Phi = E.x * 2.0 * Pi;
    float CosTheta = sqrt((1.0 - E.y) / ( 1.0 + (roughness - 1.0) * E.y));
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

    if(ndotl == 0.0) return vec3(0.0);

    vec3 h = normalize(L + E);

    float ndoth = max(0.0, dot(m.texturedNormal, h));
    float hdotl = max(0.0, dot(L, h));

    vec3 f = SchlickFresnel(m.F0, hdotl);

    float d = DistributionTerm(ndoth, m.roughness);
    float g = VisibilityTerm(ndotl, ndotv, m.roughness);
    float c = 4.0 * ndotv * ndotl + 1e-5; 

    vec3 specular = f * (g * d / c * ndotl);

    specular *= mix(vec3(1.0), m.albedo, vec3(hdotl * m.porosity));

    return specular;
}

vec3 SpecularLightingClamped(in Gbuffers m, in vec3 normal, in vec3 L, in vec3 E) {
    vec3 h = normalize(L + E);

    float ndotv = abs(dot(normal, E));
    float ndotl = abs(dot(normal, L));
    float ndoth = abs(dot(normal, h));
    float hdotl = max(0.0, dot(L, h));

    vec3 f = SchlickFresnel(m.F0, hdotl);

    float d = DistributionTerm(ndoth, m.roughness);
    float g = VisibilityTerm(ndotl, ndotv, m.roughness);
    float c = max(1e-5, 4.0 * ndotv * ndotl);

    vec3 specular = f * min(1.0, g * min(1.0, d / c));

    specular *= mix(vec3(1.0), m.albedo, vec3(hdotl * m.porosity));

    return specular;
}