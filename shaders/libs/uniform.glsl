uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;

uniform vec3 cameraPosition;

uniform float near;
uniform float far;

uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;

vec2 resolution = vec2(viewWidth, viewHeight);
vec2 texelSize = 1.0 / vec2(viewWidth, viewHeight);

const float Pi = 3.14159265;
const float invPi = 1.0 / 3.14159265;

uniform int frameCounter;

const vec2 R2Jitter[16] = vec2[16](
vec2(0.2548776662466927, 0.06984029099805333),
vec2(0.009755332493385449, 0.6396805819961064),
vec2(0.764632998740078, 0.20952087299415956),
vec2(0.5195106649867709, 0.7793611639922129),
vec2(0.27438833123346384, 0.3492014549902662),
vec2(0.029265997480155903, 0.9190417459883191),
vec2(0.7841436637268488, 0.48888203698637245),
vec2(0.5390213299735418, 0.05872232798442578),
vec2(0.29389899622023474, 0.6285626189824791),
vec2(0.04877666246692769, 0.19840290998053245),
vec2(0.8036543287136197, 0.7682432009785858),
vec2(0.5585319949603118, 0.33808349197663823),
vec2(0.31340966120700564, 0.9079237829746916),
vec2(0.0682873274536977, 0.4777640739727449),
vec2(0.8231649937003915, 0.04760436497079823),
vec2(0.5780426599470836, 0.6174446559688516));

const vec2 HaltonJitter[16] = vec2[16](
vec2(0.5    , 0.33333),
vec2(0.25   , 0.66666),
vec2(0.75   , 0.11111),
vec2(0.125  , 0.44444),
vec2(0.625  , 0.77777),
vec2(0.375  , 0.22222),
vec2(0.875  , 0.55555),
vec2(0.0625 , 0.88888),
vec2(0.5625 , 0.03703),
vec2(0.3125 , 0.37037),
vec2(0.8125 , 0.7037 ),
vec2(0.1875 , 0.14814),
vec2(0.6875 , 0.48148),
vec2(0.4375 , 0.81481),
vec2(0.9375 , 0.25925),
vec2(0.03125, 0.59259));

#define Jitter R2Jitter

void ApplyTAAJitter(inout vec4 coord) {
    #ifdef Enabled_TAA
    vec2 jitter = R2Jitter[int(mod(float(frameCounter), 16.0))] * 2.0 - 1.0;

    coord.xy += jitter * texelSize * 0.5 * coord.w;
    #endif
}

uniform mat4 gbufferPreviousModelView; 
uniform mat4 gbufferPreviousProjection;

uniform vec3 previousCameraPosition;

vec2 GetVelocity(in vec3 coord) {
    vec4 p = gbufferProjectionInverse * vec4(coord * 2.0 - 1.0, 1.0);
         p = gbufferModelViewInverse * vec4(p.xyz / p.w, 1.0);
         p.xyz += cameraPosition - previousCameraPosition;
         p = gbufferPreviousModelView * p;
         p = gbufferPreviousProjection * p;
         p /= p.w;
         p.xyz = p.xyz * 0.5 + 0.5;
    
    return coord.xy - p.xy;
}