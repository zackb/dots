#version 440

// Push/slide: the old wallpaper slides off to the left while the new one
// pushes in from the right, the two moving together as one strip.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float progress;
};

layout(binding = 1) uniform sampler2D fromTex;
layout(binding = 2) uniform sampler2D toTex;

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 col;
    if (uv.x < 1.0 - progress)
        col = texture(fromTex, vec2(uv.x + progress, uv.y));        // old, sliding out
    else
        col = texture(toTex,   vec2(uv.x - (1.0 - progress), uv.y)); // new, sliding in
    fragColor = col * qt_Opacity;
}
