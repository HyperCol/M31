#version 130

uniform sampler2D tex;

in float TileMask;

in vec2 texcoord;
in vec3 normal;
in vec4 color;

#include "/libs/mask_check.glsl"

void main() {
    vec4 albedo = texture(tex, texcoord) * color;

    float absorption = 0.0;
    float scattering = 0.0;

    float tileMask = round(TileMask);

    if(tileMask == Water) {
        scattering = 0.8;
        absorption = 8.0;

        albedo = vec4(color.rgb, 0.05);
    } else if(tileMask == Glass || tileMask == GlassPane) {

    } else if(tileMask == StainedGlass || tileMask == StainedGlassPane) {
        scattering = 0.999;
        absorption = 7.0;
    } else if(tileMask == TintedGlass) {
        scattering = 0.125;
    } else if(tileMask == SlimeBlock) {
        scattering = 0.4;
    } else if(tileMask == HoneyBlock) {
        scattering = 0.6;
    } else {
        scattering = 1.0 - albedo.a;
    }

    if(albedo.a > 0.0) albedo.a = albedo.a + 0.2;

    //scattering = (scattering * 190.0 + 65.0) / 255.0;
    absorption = absorption / 15.0;

    float packTransmittance = dot(round(vec2(absorption, scattering) * 15.0), vec2(1.0, 16.0)) / 255.0;

    gl_FragData[0] = albedo;
    gl_FragData[1] = vec4(normal * 0.5 + 0.5, packTransmittance);
}