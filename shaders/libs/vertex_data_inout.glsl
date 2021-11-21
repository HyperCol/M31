#ifndef io
#define io in
#endif

#if defined(MC_VERSION)
uniform vec3 lightVector;
uniform vec3 worldLightVector;

uniform vec3 sunVector;
uniform vec3 worldSunVector;

uniform vec3 moonVector;
uniform vec3 worldMoonVector;

uniform vec3 upVector;
uniform vec3 worldUpVector;
#else
io vec3 lightVector;
io vec3 worldLightVector;

io vec3 sunVector;
io vec3 worldSunVector;

io vec3 moonVector;
io vec3 worldMoonVector;

io vec3 upVector;
io vec3 worldUpVector;
#endif

io float shadowFade;
io float starsFade;

io vec3 SunLightingColor;
io vec3 MoonLightingColor;
io vec3 LightingColor;
io vec3 SkyLightingColor;
io vec3 BlockLightingColor;

io vec2 texcoord;