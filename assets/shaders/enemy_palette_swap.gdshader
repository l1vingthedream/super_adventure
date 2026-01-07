shader_type canvas_item;

uniform int palette_frame : hint_range(0, 3) = 0;

// Original Octorok colors
const vec3 COLOR_RED = vec3(0.847, 0.157, 0.0);      // #d82800
const vec3 COLOR_WHITE = vec3(0.988, 0.988, 0.988);  // #fcfcfc
const vec3 COLOR_ORANGE = vec3(0.988, 0.596, 0.220); // #fc9838

// Frame 2 replacements
const vec3 PAL1_RED = vec3(0.0, 0.0, 0.659);         // #0000a8
const vec3 PAL1_WHITE = vec3(0.988, 0.988, 0.988);   // #fcfcfc (same)
const vec3 PAL1_ORANGE = vec3(0.361, 0.580, 0.988);  // #5c94fc

// Frame 3 replacements
const vec3 PAL2_RED = vec3(0.988, 0.847, 0.659);     // #fcd8a8
const vec3 PAL2_WHITE = vec3(0.125, 0.220, 0.925);   // #2038ec
const vec3 PAL2_ORANGE = vec3(0.784, 0.298, 0.047);  // #c84c0c

// Frame 4 replacements
const vec3 PAL3_RED = vec3(0.988, 0.596, 0.220);     // #fc9838
const vec3 PAL3_WHITE = vec3(0.847, 0.157, 0.0);     // #d82800
const vec3 PAL3_ORANGE = vec3(0.988, 0.988, 0.988);  // #fcfcfc

const float TOLERANCE = 0.05;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	vec3 rgb = tex_color.rgb;

	if (palette_frame == 0) {
		COLOR = tex_color;
	} else {
		vec3 new_red, new_white, new_orange;

		if (palette_frame == 1) {
			new_red = PAL1_RED;
			new_white = PAL1_WHITE;
			new_orange = PAL1_ORANGE;
		} else if (palette_frame == 2) {
			new_red = PAL2_RED;
			new_white = PAL2_WHITE;
			new_orange = PAL2_ORANGE;
		} else {
			new_red = PAL3_RED;
			new_white = PAL3_WHITE;
			new_orange = PAL3_ORANGE;
		}

		if (distance(rgb, COLOR_RED) < TOLERANCE) {
			rgb = new_red;
		} else if (distance(rgb, COLOR_WHITE) < TOLERANCE) {
			rgb = new_white;
		} else if (distance(rgb, COLOR_ORANGE) < TOLERANCE) {
			rgb = new_orange;
		}

		COLOR = vec4(rgb, tex_color.a);
	}
}
