#version 440

// Clock wipe: a radial sweep rotates clockwise from 12 o'clock, revealing the
// new wallpaper like a second hand passing over the screen.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float progress;
    float aspect;
};

layout(binding = 1) uniform sampler2D fromTex;
layout(binding = 2) uniform sampler2D toTex;

const float PI = 3.14159265359;

void main() {
    vec2  d   = vec2((qt_TexCoord0.x - 0.5) * aspect, qt_TexCoord0.y - 0.5);
    // angle measured clockwise starting at the top, normalised to 0..1
    float ang = fract(atan(d.x, -d.y) / (2.0 * PI) + 1.0);

    float edge = 0.03;
    float p    = progress * (1.0 + 2.0 * edge) - edge;
    float wTo  = 1.0 - smoothstep(p - edge, p + edge, ang);

    fragColor = mix(texture(fromTex, qt_TexCoord0),
                    texture(toTex,   qt_TexCoord0), wTo) * qt_Opacity;
}
