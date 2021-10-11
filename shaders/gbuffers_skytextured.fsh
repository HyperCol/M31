#version 130

#include "/libs/mask_check.glsl"

void main() {
    gl_FragData[0] = vec4(0.0, 0.0, (255.0 + Mask_ID_Sky * 255.0) / 65535.0, 1.0);
}
/* DRAWBUFFERS:1 */