#version 130

out vec2 texcoord;

void main() {
    gl_Position = ftransform();

    texcoord = gl_MultiTexCoord0.xy;

    gl_Position.xy = gl_Position.xy * 0.5 + 0.5;
    gl_Position.xy *= 0.375;
    gl_Position.xy = gl_Position.xy * 2.0 - 1.0;
}