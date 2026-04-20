shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float scan_line_count : hint_range(0.0, 1080.0) = 200.0;
uniform float scan_line_intensity : hint_range(0.0, 1.0) = 0.35;
uniform float distortion : hint_range(0.0, 1.0) = 0.04;

// Add a slight curvature to the screen edges
vec2 crt_curve(vec2 uv) {
    uv = uv * 2.0 - 1.0;
    vec2 offset = abs(uv.yx) / vec2(6.0, 4.0);
    uv = uv + uv * offset * offset * distortion * 10.0;
    uv = uv * 0.5 + 0.5;
    return uv;
}

void fragment() {
    vec2 crt_uv = crt_curve(SCREEN_UV);
    
    // Cut off edges outside the curved screen
    if (crt_uv.x < 0.0 || crt_uv.x > 1.0 || crt_uv.y < 0.0 || crt_uv.y > 1.0) {
        COLOR = vec4(0.05, 0.06, 0.05, 1.0); // Very dark green/black border
    } else {
        vec4 color = texture(screen_texture, crt_uv);
        
        // Scanlines
        float s = sin(crt_uv.y * scan_line_count * 3.14159 * 2.0);
        float scanline = mix(1.0, s * 0.5 + 0.5, scan_line_intensity);
        
        // Subtle phosphor noise/flicker
        float noise = fract(sin(dot(crt_uv + vec2(TIME, -TIME), vec2(12.9898, 78.233))) * 43758.5453);
        
        color.rgb *= scanline;
        color.rgb += noise * 0.04 * vec3(0.1, 1.0, 0.1); // subtle green static
        
        // Slight bloom / tint to push it into that terminal green
        color.rgb *= vec3(0.9, 1.1, 0.9);
        
        COLOR = color;
    }
}
