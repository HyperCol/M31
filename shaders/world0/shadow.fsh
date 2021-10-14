#version 130

uniform sampler2D tex;

in vec2 texcoord;

in vec4 color;

void main() {
    vec4 albedo = texture(tex, texcoord) * color;

    gl_FragData[0] = albedo;
    gl_FragData[1] = vec4(1.0);
}