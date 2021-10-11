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

const float Pi = 3.14159265;
const float invPi = 1.0 / 3.14159265;