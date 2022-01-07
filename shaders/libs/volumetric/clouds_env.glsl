vec3 CloudsShadow(in vec3 worldPosition, in vec3 L, in vec3 origin, in vec2 TracingClamp, in float transmittance, in int quality) {
    vec2 tracingClouds = TracingCloudsLayer(worldPosition * Altitude_Scale + vec3(0.0, origin.y, 0.0), L);

    float rayStart = tracingClouds.x;
    float rayEnd = tracingClouds.y;
    float stepLength = min(8000.0, rayEnd - rayStart);

    rayStart += stepLength * TracingClamp.x;

    vec3 rayPosition = worldPosition * Altitude_Scale + origin + rayStart * L;

    vec3 opticalDepth = CalculateCloudsMedia(rayPosition, origin).rgb * stepLength * 0.25;

    vec3 extinction = CloudsLocalLighting(opticalDepth * transmittance);

    return extinction;
}

vec3 CloudsShadowRayMarching(in vec3 worldPosition, in vec3 L, in vec3 origin, in vec2 TracingClamp, in float transmittance, in int quality) {
    int steps = quality < Ultra ? 4 : 6;
    float invsteps = 1.0 / float(steps);

    vec2 tracingClouds = TracingCloudsLayer(worldPosition * Altitude_Scale + vec3(0.0, origin.y, 0.0), L);

    float rayStart = tracingClouds.x;
    float rayEnd = tracingClouds.y;
    float stepLength = min(8000.0, rayEnd - rayStart);

    rayStart += stepLength * TracingClamp.x;
    vec3 rayStep = stepLength * (1.0 - TracingClamp.x) * TracingClamp.y * L;

    vec3 rayPosition = worldPosition * Altitude_Scale + origin + rayStart * L;

    stepLength *= invsteps;

    vec3 opticalDepth = vec3(0.0);

    for(int i = 0; i < steps; i++){
        opticalDepth += CalculateCloudsMedia(rayPosition, origin).rgb;

        rayPosition += rayStep;
    }

    opticalDepth *= stepLength;

    vec3 extinction = CloudsLocalLighting(opticalDepth * transmittance);

    return extinction;
}