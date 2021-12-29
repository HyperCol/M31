vec3 CalculateLocalInScattering(in vec3 rayOrigin, in vec3 rayDirection) {
    #if Far_Atmospheric_Scattering_Quality == High
    const int steps = 6;
    #elif Far_Atmospheric_Scattering_Quality > High
    const int steps = 9;
    #else
    const int steps = 3;
    #endif

    const float invsteps = 1.0 / float(steps);

    vec2 tracingPlanet = RaySphereIntersection(rayOrigin, rayDirection, vec3(0.0, -1.0, 0.0), planet_radius);
    vec2 tracingAtmosphere = RaySphereIntersection(rayOrigin, rayDirection, vec3(0.0), atmosphere_radius);

    if(tracingPlanet.x > 0.0 && tracingPlanet.y > 0.0) return vec3(0.0);

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

    return transmittance;
}

void CalculateAtmosphericScattering(inout vec3 color, inout vec3 atmosphere_color, in vec3 rayOrigin, in vec3 rayDirection, in vec3 L, in vec2 tracing) {
    const int steps = 12;
    const float invsteps = 1.0 / float(steps);

    vec2 tracingAtmosphere = RaySphereIntersection(rayOrigin, rayDirection, vec3(0.0), atmosphere_radius);
    vec2 tracingPlanet = RaySphereIntersection(rayOrigin, rayDirection, vec3(0.0), planet_radius);

    float end = tracingPlanet.x > 0.0 ? tracingPlanet.x : tracingAtmosphere.y;
    float start = tracingAtmosphere.x > 0.0 ? tracingAtmosphere.x : 0.0;

    float theta = dot(rayDirection, L);
    float miePhase = HG(theta, 0.76);
    float miePhase2 = HG(-theta, 0.76);
    float rayleighPhase = (3.0 / 16.0 / Pi) * (1.0 + theta * theta);

    float stepLength = (end - start) * invsteps;

    vec3 r = vec3(0.0);
    vec3 m = vec3(0.0);
    vec3 m2 = vec3(0.0);

    vec3 transmittance = vec3(1.0);

    for(int i = 0; i < steps; i++) {
        vec3 p = rayOrigin + rayDirection * (stepLength + stepLength * float(i) + start);
        float h = max(1e-5, length(p) - planet_radius);

        float density_rayleigh  = exp(-h / rayleigh_distribution);
        float density_mie       = exp(-h / mie_distribution);
        float density_ozone     = max(0.0, 1.0 - abs(h - 25000.0) / 15000.0);

        vec3 tau = (rayleigh_scattering + rayleigh_absorption) * (density_rayleigh) + (mie_scattering + mie_absorption) * (density_mie) + (ozone_absorption + ozone_scattering) * density_ozone;
        vec3 attenuation = exp(-tau * stepLength);

        vec3 L1 = CalculateLocalInScattering(p, L) * Sun_Light_Luminance;
        vec3 S1 = (L1 - L1 * attenuation) * transmittance / tau;

        vec3 L2 = CalculateLocalInScattering(p, -L) * Moon_Light_Luminance;
        vec3 S2 = (L2 - L2 * attenuation) * transmittance / tau;

        r += (S1 + S2) * density_rayleigh;
        m += S1 * density_mie;
        m2 += S2 * density_mie; 

        transmittance *= attenuation;
    }

    color *= transmittance;

    atmosphere_color = r * rayleigh_scattering * rayleighPhase + m * mie_scattering * miePhase + m2 * mie_scattering * miePhase2;
}