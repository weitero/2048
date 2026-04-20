shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float grain_amount = 0.08;
uniform float vignette_intensity = 0.5;

float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
    vec4 color = texture(screen_texture, SCREEN_UV);
    
    // Animated Film grain
    float noise = (rand(SCREEN_UV + vec2(TIME, -TIME)) - 0.5) * grain_amount;
    color.rgb += noise;
    
    // Vignette
    float dist = distance(UV, vec2(0.5, 0.5));
    // vignette: 1.0 at center, drops to 0 at edges.
    float vignette = smoothstep(0.8, 0.2, dist * 1.5);
    
    color.rgb = mix(color.rgb * vignette, color.rgb, 1.0 - vignette_intensity);
    
    COLOR = color;
}
