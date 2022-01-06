const float     clouds_height       = 1500.0;
const float     clouds_thickness    = 1000.0;
const vec3      clouds_scattering   = vec3(0.08);

vec2 TracingCloudsLayer(in vec3 origin, in vec3 direction) {
    vec2 tracingBottom = RaySphereIntersection(origin, direction, vec3(0.0), planet_radius + clouds_height);
    vec2 tracingTop = RaySphereIntersection(origin, direction, vec3(0.0), planet_radius + clouds_height + clouds_thickness);

    float rayStart = max(0.0, tracingBottom.y);
    float rayEnd = max(0.0, tracingTop.y);

    if(rayStart > rayEnd) {
        float v = rayStart;
        rayStart = rayEnd;
        rayEnd = v;
    }

    return vec2(rayStart, rayEnd);
}

float GetCloudsMap(in vec3 position) {
    vec3 worldPosition = vec3(position.x, position.z, position.y - planet_radius);

    vec3 shapeCoord = worldPosition * 0.0005;
    float shape = (noise(shapeCoord.xy) + noise(shapeCoord.xy * 2.0) * 0.5) / 1.5;
    float shape2 = (noise(shapeCoord * 4.0) + noise(shapeCoord.xy * 8.0) * 0.5) / 1.5;

    float density = max(0.0, rescale((shape + shape2 * 0.5) / 1.5, 0.1, 1.0));

    return density;
}

float GetCloudsMapDetail(in vec3 position, in float shape, in float distortion) {
    vec3 worldPosition = vec3(position.x, position.z, position.y - planet_radius);

    vec3 noiseCoord0 = worldPosition * 0.01;
    float noise0 = (noise(noiseCoord0) + noise(noiseCoord0 * 2.0) * 0.5 + noise(noiseCoord0 * 4.0) * 0.25) / (1.75);

    return max(0.0, rescale(shape - noise0 * distortion, 0.0, 1.0 - distortion));
} 

float GetCloudsCoverage(in float linearHeight) {
    return pow(0.75, remap(linearHeight, 0.7, 0.8, 1.0, mix(1.0, 0.5, 0.5)) * saturate(rescale(linearHeight, -0.05, 0.1)));
}

float CalculateCloudsCoverage(in float height, in float clouds) {
    float linearHeight = (height - clouds_height) / clouds_thickness;    

    return saturate(rescale(clouds, GetCloudsCoverage(linearHeight), 1.0) * 2.0);
}

vec3 CalculateCloudsMediaSample(in float height) {
    return mix(vec3(0.09), vec3(0.05), height);
}

vec3 CloudsPowderEffect(in vec3 opticalDepth) {
    return 1.0 - exp(-opticalDepth * 2.0);
}

vec3 CloudsLocalLighting(in vec3 opticalDepth) {
    vec3 extinction = (exp(-opticalDepth) + exp(-opticalDepth * 0.25) * 0.7 + exp(-opticalDepth * 0.03) * 0.24) / (1.7 + 0.24);

    return extinction;
}

vec4 CalculateCloudsMedia(in vec3 rayPosition, in vec3 origin) {
    float height = length(rayPosition - vec3(origin.x, 0.0, origin.z)) - planet_radius;

    float density = GetCloudsMap(rayPosition);
          density = GetCloudsMapDetail(rayPosition, density, 0.2);
          density = CalculateCloudsCoverage(height, density);

    return vec4(clouds_scattering * density, density);
}