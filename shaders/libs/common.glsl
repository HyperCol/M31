#define MappingToSDR (1.0 / 3000.0)
#define MappingToHDR (3000.0)

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

float sum3(in vec3 x) {
    return (x.x + x.y + x.z) / 3.0;
}

vec3 LinearToGamma(in vec3 color) {
    return pow(color, vec3(2.2));
}

vec3 GammaToLinear(in vec3 color) {
    return pow(color, vec3(1.0 / 2.2));
}

float minComponent( vec3 a ) {
    return min(a.x, min(a.y, a.z) );
}

float maxComponent( vec3 a ) {
    return max(a.x, max(a.y, a.z) );
}

float rescale(in float v, in float vmin, in float vmax) {
    return (v - vmin) / (vmax - vmin);
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

float HG(in float m, in float g) {
  return (0.25 / Pi) * ((1.0 - g*g) / pow(1.0 + g*g - 2.0 * g * m, 1.5));
}

float IntersectPlane(vec3 origin, vec3 direction, vec3 point, vec3 normal) {
    return dot(point - origin, normal) / dot(direction, normal);
}

vec2 RaySphereIntersection(vec3 rayOrigin, vec3 rayDirection, vec3 sphereCenter, float sphereRadius) {
	rayOrigin -= sphereCenter;

	float a = dot(rayDirection, rayDirection);
	float b = 2.0 * dot(rayOrigin, rayDirection);
	float c = dot(rayOrigin, rayOrigin) - (sphereRadius * sphereRadius);
	float d = b * b - 4.0 * a * c;

	if (d < 0) return vec2(-1.0);

	d = sqrt(d);
	return vec2(-b - d, -b + d) / (2.0 * a);
}

vec2 IntersectCube(vec3 rayOrigin, in vec3 rayDirection, in vec3 shapeCenter, in vec3 size) {
    shapeCenter = rayOrigin - shapeCenter;

    vec3 dr = 1.0 / rayDirection;
    vec3 n = shapeCenter * dr;
    vec3 k = size * abs(dr);

    vec3 pin = -k - n;
    vec3 pout = k - n;

    float near = max(pin.x, max(pin.y, pin.z));
    float far = min(pout.x, min(pout.y, pout.z));

    if(far > near || far > 0.0) {
        return vec2(near, far);
    }else{
        return vec2(-1.0);
    }
}

float sdSphere( vec3 p, float s ) {
  return length(p)-s;
}

float sdBox( vec3 p, vec3 b ) {
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float sdRoundBox( vec3 p, vec3 b, float r ) {
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - r;
}

float sdRoundBox( vec2 p, vec2 b, float r ) {
  vec2 q = abs(p) - b;
  return length(max(q,vec2(0.0))) + min(max(q.x,q.y),0.0) - r;
}