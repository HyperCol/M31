const float     clouds_height       = 1500.0;
const float     clouds_thickness    = 1200.0;

const vec3      clouds_scattering   = vec3(0.08);

vec2 TracingCloudsLayer(in vec3 origin, in vec3 direction) {
    vec2 tracingBottom = RaySphereIntersection(origin, direction, vec3(0.0), planet_radius + clouds_height);
    vec2 tracingTop = RaySphereIntersection(origin, direction, vec3(0.0), planet_radius + clouds_height + clouds_thickness);
    
    float start = tracingBottom.x > 0.0 ? tracingBottom.x : max(0.0, tracingBottom.y);
    float end = tracingTop.x > 0.0 ? tracingTop.x : max(0.0, tracingTop.y);

    if(start > end) {
        float v = start;
        start = end;
        end = v;
    }

    return vec2(start, end);
}

float PerlinNoise2(in vec2 coord) {
    return (noise(coord) + noise(coord * 2.0) * 0.5) / 1.5;
}

float PerlinNoise2(in vec3 coord) {
    return (noise(coord) + noise(coord * 2.0) * 0.5) / 1.5;
}

float GetCloudsMap(in vec3 position, in float height) {
    vec3 worldPosition = vec3(position.x, position.z, position.y - planet_radius);

    #if 1
    
    float shapeSize = 0.0008;

    vec3 shapeCoord = worldPosition * shapeSize;
    float shape = PerlinNoise2(shapeCoord.xy);
    
    float weight = 1.0;
    float e = 1200.0 * shapeSize;

    shape += PerlinNoise2(shapeCoord.xy + vec2(e, 0.0)) * weight;
    shape += PerlinNoise2(shapeCoord.xy - vec2(e, 0.0)) * weight;
    shape += PerlinNoise2(shapeCoord.xy + vec2(0.0, e)) * weight;
    shape += PerlinNoise2(shapeCoord.xy - vec2(0.0, e)) * weight;
    shape /= 1.0 + weight * 4.0;

    shape = saturate(rescale(shape, 0.35, 0.8));
    
/*
    vec2 shapeCoord = worldPosition.xy * 0.0004;
    float shape = (noise(shapeCoord) + noise(shapeCoord * 2.0) * 0.5) / 1.5;
          //shape = (noise(shapeCoord * 0.5) + noise(shapeCoord * 0.25) * 0.5) / 1.5;//mix(shape, (noise(shapeCoord * 0.5) + noise(shapeCoord * 0.25) * 0.5) / 1.5, 0.3);
          shape = rescale(shape, 0.0, 1.0);
*/
    vec3 detailCoord = worldPosition * 0.0064;

    float detail = (noise(detailCoord) + noise(detailCoord * 2.0) * 0.5 + noise(detailCoord * 4.0) * 0.25) / 1.75;
    float detailWeight = 0.3;

    float density = (shape + detail * detailWeight) / (1.0 + detailWeight);
    #else
    float t = (frameTimeCounter) * Clouds_Speed;

    worldPosition.x += t * Clouds_X_Speed;
    worldPosition.x += height / 100.0 * Clouds_X_Speed;
    worldPosition.z += t * Clouds_Vertical_Speed;

    vec3 shapeCoord = worldPosition * 0.0005;
    float shape = (noise(shapeCoord.xy) + noise(shapeCoord.xy * 2.0) * 0.5) / 1.5;
          shape = shape + pow(max(0.0, rescale(shape, 0.2, 1.0)), 0.1) - 1.0;

    float shape2 = (noise(shapeCoord * 4.0) + noise(shapeCoord * 8.0) * 0.5) / 1.5;

    float density = max(0.0, rescale(mix(shape, shape2, 0.3), 0.1, 1.0));
    #endif

    return density;
}

float GetCloudsMapDetail(in vec3 position, in float shape, in float distortion) {
    vec3 worldPosition = vec3(position.x, position.z, position.y - planet_radius);

    float t = (frameTimeCounter) * Clouds_Speed;
    worldPosition.z += -t * Clouds_Vertical_Speed * 0.25;

    vec3 noiseCoord0 = worldPosition * 0.01;
    float noise0 = (noise(noiseCoord0) + noise(noiseCoord0 * 2.0) * 0.5 + noise(noiseCoord0 * 4.0) * 0.25) / (1.75);

    return shape;//saturate(rescale(shape - noise0 * distortion, 0.0, 1.0 - distortion));
} 

float GetCloudsCoverage(in float linearHeight) { 
    //return pow(/*mix(0.7, 0.3, rainStrength)*/0.35, remap(linearHeight, 0.7, 0.8, 1.0, mix(1.0, 0.5, 0.4)) * saturate(rescale(linearHeight, -0.01, 0.01)));
    return pow(0.7, remap(linearHeight, 0.7, 0.8, 1.0, mix(1.0, 0.5, 0.4)) * saturate(rescale(linearHeight, -0.01, 0.01)));
}

float CalculateCloudsCoverage(in float height, in float clouds) {
    float linearHeight = (height) / clouds_thickness;

    return saturate(rescale(clouds, GetCloudsCoverage(linearHeight), 1.0));
}

vec3 CloudsPowderEffect(in vec3 opticalDepth) {
    return 1.0 - exp(-opticalDepth * 2.0);
}

vec3 CloudsLocalLighting(in vec3 opticalDepth) {
    vec3 extinction = (exp(-opticalDepth) + exp(-opticalDepth * 0.25) * 0.7 + exp(-opticalDepth * 0.03) * 0.24) / (1.7 + 0.24);

    return extinction;
}

vec4 CalculateCloudsMedia(in vec3 rayPosition, in vec3 origin) {
    float worldHeight = length(rayPosition - vec3(origin.x, 0.0, origin.z)) - planet_radius;
    float height = worldHeight - clouds_height;

    float density = GetCloudsMap(rayPosition, height);
          density = GetCloudsMapDetail(rayPosition, density, 0.2);
          density = CalculateCloudsCoverage(height, density);

    return vec4(clouds_scattering * density, density);
}

vec4 CalculateCloudsMediaNoDetail(in vec3 rayPosition, in vec3 origin) {
    float worldHeight = length(rayPosition - vec3(origin.x, 0.0, origin.z)) - planet_radius;
    float height = worldHeight - clouds_height;

    float density = GetCloudsMap(rayPosition, height);
          //density = GetCloudsMapDetail(rayPosition, density, 0.2);
          density = CalculateCloudsCoverage(height, density);

    return vec4(clouds_scattering * density, density);
}