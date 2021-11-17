#version 130

#include "/libs/setting.glsl"
#include "/libs/vertex_data_inout.glsl"
#include "/libs/uniform.glsl"
#include "/libs/common.glsl"
#include "/libs/gbuffers_data.glsl"
#include "/libs/lighting/brdf.glsl"
#include "/libs/volumetric/atmospheric_common.glsl"
#include "/libs/lighting/shadowmap_common.glsl"
#include "/libs/misc/night_sky.glsl"

uniform float centerDepthSmooth;

float t(in float z){
  if(0.0 <= z && z < 0.5) return 2.0*z;
  if(0.5 <= z && z < 1.0) return 2.0 - 2.0*z;
  return 0.0;
}

float R2Dither(in vec2 coord){
  float a1 = 1.0 / 0.75487766624669276;
  float a2 = 1.0 / 0.569840290998;

  return mod(coord.x * a1 + coord.y * a2, 1.0);
}

#include "/libs/lighting/shadowmap.glsl"

vec3 CalculateLocalInScattering(in vec3 rayOrigin, in vec3 rayDirection) {
    int steps = 6;
    float invsteps = 1.0 / float(steps);

    vec2 tracingPlanet = RaySphereIntersection(rayOrigin, rayDirection, vec3(0.0, -1.0, 0.0), planet_radius);
    vec2 tracingAtmosphere = RaySphereIntersection(rayOrigin, rayDirection, vec3(0.0), atmosphere_radius);

    #ifndef Soft_Planet_Shadow
    if(tracingPlanet.x > 0.0 && tracingPlanet.y > 0.0) return vec3(0.0);
    #endif

    if(tracingAtmosphere.y < 0.0) return vec3(1.0);

    float stepLength = tracingAtmosphere.y * invsteps;

    vec3 opticalDepth = vec3(0.0);

    for(int i = 0; i < steps; i++) {
        vec3 p = rayOrigin + rayDirection * (stepLength + stepLength * float(i));
        float h = max(1e-5, length(p) - planet_radius);

        float density_rayleigh  = stepLength * exp(-h / rayleigh_distribution);
        float density_mie       = stepLength * exp(-h / mie_distribution);
        float density_ozone     = stepLength * max(0.0, 1.0 - abs(h - 25000.0) / 15000.0);

        opticalDepth += vec3(density_rayleigh, density_mie, density_ozone);
    }

    vec3 tau = (rayleigh_scattering + rayleigh_absorption) * opticalDepth.x + (mie_scattering + mie_absorption) * opticalDepth.y + (ozone_absorption + ozone_scattering) * opticalDepth.z;
    vec3 transmittance = exp(-tau);

    #ifdef Soft_Planet_Shadow
        if(tracingPlanet.x > 0.0 && tracingPlanet.y > 0.0) {
            transmittance *= exp(-0.00001 * (tracingPlanet.y - tracingPlanet.x));
        }
    #endif

    return transmittance;
}

void CalculateAtmosphericScattering(inout vec3 color, inout vec3 atmosphere_color, in vec3 rayOrigin, in vec3 rayDirection, in vec3 mainLightDirection, in vec3 secLightDirection, in vec2 tracing) {
    int steps = 16;
    float invsteps = 1.0 / float(steps);

    rayOrigin = vec3(0.0, planet_radius + max(1.0, (cameraPosition.y - 63.0) * 1.0), 0.0);

    vec2 tracingAtmosphere = RaySphereIntersection(rayOrigin, rayDirection, vec3(0.0), atmosphere_radius);
    vec2 tracingPlanet = RaySphereIntersection(rayOrigin, rayDirection, vec3(0.0), planet_radius);

    float end = tracingPlanet.x > 0.0 ? tracingPlanet.x : tracingAtmosphere.y;
    float start = tracingAtmosphere.x > 0.0 ? tracingAtmosphere.x : 0.0;

    float theta = dot(rayDirection, mainLightDirection);
    float mainPhaseR = (3.0 / 16.0 / Pi) * (1.0 + theta * theta);
    float mainPhaseM = HG(theta, 0.76);

    float secTheta = dot(rayDirection, secLightDirection);
    float secPhaseR = (3.0 / 16.0 / Pi) * (1.0 + secTheta * secTheta);
    float secPhaseM = HG(secTheta, 0.76);

    float stepLength = (end - start) * invsteps;

    vec3 opticalDepth = vec3(0.0);

    vec3 r = vec3(0.0);
    vec3 m = vec3(0.0);

    vec3 transmittance = vec3(1.0);

    for(int i = 0; i < steps; i++) {
        vec3 p = rayOrigin + rayDirection * (stepLength + stepLength * float(i) + start);
        float h = max(1e-5, length(p) - planet_radius);

        float density_rayleigh  = stepLength * exp(-h / rayleigh_distribution);
        float density_mie       = stepLength * exp(-h / mie_distribution);
        float density_ozone     = stepLength * max(0.0, 1.0 - abs(h - 25000.0) / 15000.0);

        vec3 tau = (rayleigh_scattering + rayleigh_absorption) * (density_rayleigh) + (mie_scattering + mie_absorption) * (density_mie) + (ozone_absorption + ozone_scattering) * density_ozone;
        vec3 attenuation = exp(-tau);

        vec3 L1 = CalculateLocalInScattering(p, mainLightDirection) * Sun_Light_Luminance;
        vec3 alphaMain = (L1 - L1 * attenuation) * transmittance / tau;

        vec3 L2 = CalculateLocalInScattering(p, secLightDirection) * Moon_Light_Luminance;
        vec3 alphaSec = (L2 - L2 * attenuation) * transmittance / tau;

        r += (alphaMain * mainPhaseR + alphaSec * secPhaseR) * density_rayleigh;
        m += (alphaMain * mainPhaseM + alphaSec * secPhaseM) * density_mie;
        transmittance *= attenuation;
    }

    color *= transmittance;

    atmosphere_color = (r * rayleigh_scattering + m * mie_scattering);
}

vec3 CalculatePlanetSurface(in vec3 LightColor0, in vec3 LightColor1, in vec3 L, in vec3 direction, in float h, in float t) {
    if(t <= 0.0) return vec3(0.0);

    float cosTheta = dot(L, direction);

    float phaseM0 = HG(cosTheta, 0.76);
    float phaseM1 = HG(-cosTheta, 0.76);

    float phaseR = (3.0 / 16.0 / Pi) * (1.0 + cosTheta * cosTheta);

    vec3 Tr = exp(-h / rayleigh_distribution) * (rayleigh_absorption + rayleigh_scattering);
    vec3 Tm = exp(-h / mie_distribution) * (mie_absorption + mie_scattering);

    vec3 transmittance = 1.0 - exp(-sqrt(pow2(t) + pow2(h)) * 3.0 * (Tr + Tm));

    return LightColor0 * (phaseM0 + phaseR) * (transmittance) + LightColor1 * (phaseM1 + phaseR) * (transmittance);
}

float ComputeAO(in vec3 P, in vec3 N, in vec3 S) {
    vec3 V = S - P;
    float vodtv = dot(V, V);
    float ndotv = dot(N, V) * inversesqrt(vodtv);

    float falloff = vodtv * -pow2(SSAO_Falloff) + 1.0;

    // Use saturate(x) instead of max(x,0.f) because that is faster
    return saturate(ndotv - SSAO_Bias) * saturate(falloff);
}

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

    float dither = 0.5;//R2Dither(ApplyTAAJitter(texcoord) * resolution);

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

float ScreenSpaceContactShadow(in Gbuffers m, in Vector v, in vec3 LightDirection, in float material_bias) {
    float shading = 1.0;

    int steps = 8;
    float invsteps = 1.0 / float(steps);

    float ndotl = dot(LightDirection, m.geometryNormal);
    if(ndotl < 0.02 || material_bias > 0.0) return 1.0;

    float dist = ExpToLinerDepth(v.depth);
    float distanceStepLength = clamp((dist - shadowDistance * 0.5) / 2.0, 1.0, 16.0);

    vec3 bias = LightDirection / dot(LightDirection, m.geometryNormal) * dist / 500.0;

    float dither = R2Dither(ApplyTAAJitter(texcoord) * vec2(viewWidth, viewHeight));

    float maxLength = 0.2 * distanceStepLength;
    float thickness = 0.1 * distanceStepLength;

    vec3 direction = LightDirection * invsteps * maxLength;
    vec3 position = v.vP + direction * dither + bias;

    for(int i = 0; i < steps; i++) {
        vec3 sampleCoord = nvec3(gbufferProjection * nvec4(position)) * 0.5 + 0.5;
        if(abs(sampleCoord.x - 0.5) > 0.5 || abs(sampleCoord.y - 0.5) > 0.5) break;

        float testDepth = texture(depthtex0, sampleCoord.xy).x;

        if(sampleCoord.z > testDepth && ExpToLinerDepth(testDepth) + thickness > ExpToLinerDepth(sampleCoord.z)) {
            shading = 0.0;
            break;
        }

        position += direction;
    }

    return shading;
}

vec3 Diffusion(in float depth, in vec3 t) {
    depth = max(1e-5, depth);

    return exp(-depth * t) / (4.0 * Pi * t * max(1.0, depth));
}

vec3 LeavesShading(vec3 L, vec3 eye, vec3 n, vec3 albedo, vec3 sigma_t, vec3 sigma_s) {
    albedo = pow(albedo, vec3(0.9));

    //vec2 t = IntersectCube(-worldLightVector, worldLightVector, vec3(0.0), vec3(0.03125 * 0.5));
    //float depth = max(0.0, t.y - max(0.0, t.x));

    float depth = 0.03125;

    vec3 R = Diffusion(depth, sigma_t);

    float mu = dot(L, -eye);
    float phase = mix(HG(mu, -0.1), HG(mu, 0.7), 0.3);

    float ndotl = max(0.0, dot(L, n));

    return (R * albedo / sigma_t * sigma_s) * (invPi * phase * (1.0 - ndotl));
}

void main() {
    //material
    Gbuffers    m = GetGbuffersData(texcoord);

    //opaque
    Vector      o = GetVector(texcoord, depthtex0);

    vec3 color = vec3(0.0);

    vec3 shading = CalculateShading(vec3(texcoord, o.depth), lightVector, m.geometryNormal, m.maskLeaves + m.maskGrass * 2.0);
         shading *= ScreenSpaceContactShadow(m, o, lightVector, m.maskLeaves + m.maskGrass);

    vec3 sunLight = DiffuseLighting(m, lightVector, o.eyeDirection);
         sunLight += SpecularLighting(m, lightVector, o.eyeDirection);
         sunLight += LeavesShading(lightVector, o.eyeDirection, m.texturedNormal, m.albedo.rgb, vec3(0.05), vec3(0.05)) * (m.maskGrass + m.maskLeaves);

    color += sunLight * LightingColor * shading * shadowFade;

    float ao = ScreenSpaceAmbientOcclusion(m, o);

    float SkyLighting0 = saturate(rescale(ao * pow2(m.lightmap.y * m.lightmap.y), 0.7, 1.0));
    float SkyLighting1 = pow2(m.lightmap.y) * m.lightmap.y * pow(ao, max((1.0 - m.lightmap.y) * 8.0, 1.0));

    vec3 AmbientLight = vec3(0.0);
         AmbientLight += m.albedo * SunLightingColor * (saturate(dot(m.texturedNormal, sunVector)) * HG(dot(m.texturedNormal, sunVector), 0.1) * HG(0.5, 0.76) * invPi);
         AmbientLight += m.albedo * SkyLightingColor * (rescale(dot(m.texturedNormal, upVector) * 0.5 + 0.5, -0.5, 1.0) * invPi);
         AmbientLight *= mix(SkyLighting0, SkyLighting1, 0.7) * (1.0 - m.metal) * (1.0 - m.metallic);

    color += AmbientLight;

    vec3 handHeldLight = m.albedo * invPi * BlockLightingColor * (float(heldBlockLightValue) + float(heldBlockLightValue2)) / 15.0;

    #if Held_Light_Quality == High
    vec3 handOffset = nvec3(gbufferProjectionInverse * nvec4(vec3(1.0, 0.5, 0.0) * 2.0 - 1.0)) * vec3(1.0, 1.0, 0.0);
    if(m.tile_mask == MaskIDHand) handOffset = vec3(0.0);

    vec3 lP1 = o.vP - handOffset * 4.0;
    vec3 lP2 = o.vP + handOffset * 4.0;

    float heldLightDistance1 = min(3.0, 1.0 / pow2(length(lP1)));
    float heldLightDistance2 = min(3.0, 1.0 / pow2(length(lP2)));

    lP1 = normalize(lP1);
    lP2 = normalize(lP2);

    vec3 heldLight1  = BlockLightingColor * SpecularLighting(m, -lP1, o.eyeDirection) * heldLightDistance1;
         heldLight1 += BlockLightingColor * DiffuseLighting(m, -lP1, o.eyeDirection) * max(0.0, rescale(heldLightDistance1, 1e-3, 1.0));
         heldLight1 *= float(heldBlockLightValue) / 15.0;
    
    vec3 heldLight2  = BlockLightingColor * SpecularLighting(m, -lP2, o.eyeDirection) * heldLightDistance2;
         heldLight2 += BlockLightingColor * DiffuseLighting(m, -lP2, o.eyeDirection) * max(0.0, rescale(heldLightDistance2, 1e-3, 1.0)) * 6.0;
         heldLight2 *= float(heldBlockLightValue2) / 15.0;

    color += heldLight1 + heldLight2;
    #else
    float heldLightDistance = min(3.0, 1.0 / pow2(o.viewLength));

    vec3 heldLight  = BlockLightingColor * SpecularLighting(m, o.eyeDirection, o.eyeDirection) * heldLightDistance;
         heldLight += BlockLightingColor * DiffuseLighting(m, o.eyeDirection, o.eyeDirection) * max(0.0, rescale(heldLightDistance, 1e-3, 1.0)) * 6.0;
         heldLight *= max(float(heldBlockLightValue), float(heldBlockLightValue2)) / 15.0;
    
    color += heldLight;
    #endif

    float blockLight0 = (m.lightmap.x * m.lightmap.x * m.lightmap.x) * (ao * ao * ao);
    float blockLight1 = 1.0 / pow2(max(1.0, (1.0 - m.lightmap.x) * 15.0));

    vec3 blockLight = (BlockLightingColor * m.albedo);
         blockLight *= (1.0 / 4.0 * Pi) * m.lightmap.x * (blockLight0 + blockLight1) * (1.0 - m.metallic) * (1.0 - m.metal) * (1.0 - m.emissive);

    color += blockLight;

    vec3 emissiveColor = m.albedo;
         emissiveColor *= invPi * m.emissive * (1.0 - SchlickFresnel(dot(o.eyeDirection, normalize(o.eyeDirection + normalize(reflect(o.viewDirection, m.geometryNormal))))));

    color += emissiveColor;

    if(m.tile_mask == Mask_ID_Sky) {
        vec3 rayOrigin = vec3(0.0, planet_radius + max(1.0, (cameraPosition.y - 63.0) * 1.0), 0.0);
        vec3 rayDirection = o.worldViewDirection;

        vec2 tracingAtmosphere = RaySphereIntersection(rayOrigin, rayDirection, vec3(0.0), atmosphere_radius);
        vec2 tracingPlanet = RaySphereIntersection(rayOrigin, rayDirection, vec3(0.0), planet_radius);

        color = vec3(0.0);

        vec3 stars = DrawStars(o.worldViewDirection, tracingPlanet.x);
        color += starsFade * stars;

        vec4 moonTexture = DrawMoon(worldMoonVector, o.worldViewDirection, tracingPlanet.x);
        color = mix(color, moonTexture.rgb, vec3(moonTexture.a));

        color += CalculatePlanetSurface(SunLightingColor, MoonLightingColor, worldSunVector, o.worldViewDirection, 1000.0, tracingPlanet.x);

        vec3 atmosphere_color = vec3(0.0);
        CalculateAtmosphericScattering(color, atmosphere_color, vec3(0.0, planet_radius, 0.0), o.worldViewDirection, worldSunVector, worldMoonVector, vec2(0.0));
        color += atmosphere_color;
    }

    //color *= MappingToSDR;
    //color = GammaToLinear(color);

    color = color / (color + 1.0);
    color = GammaToLinear(color);

	#ifdef Camera_Focal_Distance_Auto
	float P = ExpToLinerDepth(centerDepthSmooth);
	#else
	float P = Camera_Focal_Distance;
	#endif

	float z = ExpToLinerDepth(texture(depthtex0, texcoord).x);

    float CoC = Camera_Aperture * ((Camera_Focal_Length * (z - P)) / (z * (P - Camera_Focal_Length)));
          //CoC = min(32.0, CoC) / 32.0;

    float alpha = clamp(CoC / 32.0, -1.0, 1.0) * 0.5 + 0.5;

    gl_FragData[0] = vec4(color, alpha);
}
/* DRAWBUFFERS:3 */