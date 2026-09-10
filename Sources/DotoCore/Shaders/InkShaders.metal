#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// High-contrast luminous bloom shader:
/// Produces a sharp luminous core with smooth exponential falloff glow.
[[stitchable]] half4 luminousGlow(
    float2 position,
    half4 currentColor,
    float2 center,
    float radius,
    half4 glowColor,
    float intensity
) {
    float d = length(position - center);
    if (d > radius * 3.5) {
        return currentColor;
    }

    // Exponential falloff for laser-sharp luminous core
    float factor = exp(-d / (radius * 0.85)) * intensity;
    factor = clamp(factor, 0.0f, 1.0f);

    return mix(currentColor, glowColor, half(factor));
}

/// Snappy radial ripple pulse shader on completion
[[stitchable]] half4 dotPulse(
    float2 position,
    half4 currentColor,
    float2 center,
    float progress,
    float maxRadius
) {
    if (progress <= 0.0 || progress >= 1.0) {
        return currentColor;
    }

    float d = length(position - center);
    float ringRadius = maxRadius * progress;
    float thickness = 2.0;

    float ring = smoothstep(ringRadius - thickness, ringRadius, d) *
                 (1.0 - smoothstep(ringRadius, ringRadius + thickness, d));

    float alpha = ring * (1.0 - progress) * 0.8;
    half4 flashColor = half4(1.0, 1.0, 1.0, half(alpha));

    return mix(currentColor, flashColor, flashColor.a);
}
