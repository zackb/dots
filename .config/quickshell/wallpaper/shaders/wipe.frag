#version 440

// Soft-edged linear wipe sweeping across the screen at a diagonal angle.
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
    vec2  dir   = normalize(vec2(1.0, 0.55));
    float denom = dot(vec2(1.0), abs(dir));
    float c     = dot(qt_TexCoord0, dir) / denom;   // ~0 .. 1 along sweep

    float edge = 0.12;
    // remap so the soft edge starts fully off-screen and ends fully off-screen
    float p   = progress * (1.0 + 2.0 * edge) - edge;
    float wTo = 1.0 - smoothstep(p - edge, p + edge, c);

    fragColor = mix(texture(fromTex, qt_TexCoord0),
                    texture(toTex,   qt_TexCoord0), wTo) * qt_Opacity;
}
