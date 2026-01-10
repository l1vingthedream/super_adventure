shader_type canvas_item;

// Screen darkening shader for game over effect
// Applies a red-tinted darkening based on the game_over_palette.png colors

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float darken_progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 screen_color = texture(screen_texture, SCREEN_UV);

	// Calculate luminance for contrast preservation
	float lum = dot(screen_color.rgb, vec3(0.299, 0.587, 0.114));

	// Dark red target colors from game_over_palette.png
	// The palette transitions from bright red to dark red/black
	vec3 dark_red = vec3(0.6, 0.0, 0.0);   // Brighter areas become this
	vec3 darker_red = vec3(0.2, 0.0, 0.0); // Darker areas become this

	// Mix between dark_red and darker_red based on original luminance
	vec3 target_color = mix(darker_red, dark_red, lum);

	// Apply darkening based on progress
	vec3 final_color = mix(screen_color.rgb, target_color, darken_progress);

	COLOR = vec4(final_color, 1.0);
}
