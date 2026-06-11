#version 440

// Noise dissolve: pixels flip to the new wallpaper in a random order,
// quantised to a coarse grid so it reads as chunky speckle, not shimmer.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float progress;
};

layout(binding = 1) uniform sampler2D fromTex;
layout(binding = 2) uniform sampler2D toTex;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
    float n    = hash(floor(qt_TexCoord0 * vec2(640.0, 360.0)));
    float edge = 0.08;
    float p    = progress * (1.0 + edge);
    float wTo  = smoothstep(n, n + edge, p);

    fragColor = mix(texture(fromTex, qt_TexCoord0),
                    texture(toTex,   qt_TexCoord0), wTo) * qt_Opacity;
}
