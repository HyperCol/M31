vec3 nvec3(in vec4 x) {
    return x.xyz / x.w;
}

vec4 nvec4(in vec3 x) {
    return vec4(x, 1.0);
}

float saturate(in float x) {
    return clamp(x, 0.0, 1.0);
}

vec2 saturate(in vec2 x) {
    return clamp(x, vec2(0.0), vec2(1.0));
}

vec3 saturate(in vec3 x) {
    return clamp(x, vec3(0.0), vec3(1.0));
}

float pow2(in float x) {
    return x * x;
}

float pow5(in float x) {
    return x * x * x * x * x;
}

vec3 LinearToGamma(in vec3 color) {
    return pow(color, vec3(2.2));
}

vec3 GammaToLinear(in vec3 color) {
    return pow(color, vec3(1.0 / 2.2));
}

float pack2x8(in vec2 x) {
    float pack = dot(round(x * 255.0), vec2(1.0, 256.0));
    return pack / 65535.0;
}

float pack2x8(in float x, in float y){
    return pack2x8(vec2(x, y));
}

vec2 unpack2x8(in float x) {
    x *= 65535.0;
    return vec2(mod(x, 256.0), floor(x / 256.0)) / 255.0;
}

float unpack2x8X(in float packge) {
    return (256.0 / 255.0) * fract(packge * (256.0));
}

float unpack2x8Y(in float packge) {
    return (1.0 / 255.0) * floor(packge * (256.0));
}

vec2 signNotZero(vec2 v) {
    return vec2((v.x >= 0.0) ? +1.0 : -1.0, (v.y >= 0.0) ? +1.0 : -1.0);
}
// Assume normalized input. Output is on [-1, 1] for each component.
vec2 EncodeOctahedralmap(in vec3 v) {
    // Project the sphere onto the octahedron, and then onto the xy plane
    vec2 p = v.xy * (1.0 / (abs(v.x) + abs(v.y) + abs(v.z)));
    // Reflect the folds of the lower hemisphere over the diagonals
    return (v.z <= 0.0) ? ((1.0 - abs(p.yx)) * signNotZero(p)) : p;
}

vec3 DecodeOctahedralmap(vec2 e) {
    vec3 v = vec3(e.xy, 1.0 - abs(e.x) - abs(e.y));
    if (v.z < 0) v.xy = (1.0 - abs(v.yx)) * signNotZero(v.xy);
    return normalize(v);
}

vec2 EncodeSpheremap(vec3 n) {
    float f = sqrt(8.0 * n.z + 8.0);
    return n.xy / f + 0.5;
}

vec3 DecodeSpheremap(vec2 enc) {
    vec2 fenc = enc * 4.0 - 2.0;
    float f = dot(fenc, fenc);
    float g = sqrt(1.0 - f / 4.0);
    vec3 n;
    n.xy = fenc * g;
    n.z = 1.0 - f / 2.0;
    return n;
}

float expToLinerDepth(float depth) {
    vec2 viewDepth = vec2(depth * 2.0 - 1.0, 1.0) * mat2(gbufferProjectionInverse[2].zw, gbufferProjectionInverse[3].zw);
    return -viewDepth.x / viewDepth.y;
}

float linerToExpDepth(float linerDepth) {
    float expDepth = (far + near - 2.0 * far * near / linerDepth) / (near - far);
    return expDepth * 0.5 + 0.5;
}