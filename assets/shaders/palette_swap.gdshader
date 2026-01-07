shader_type canvas_item;

uniform int palette_frame : hint_range(0, 3) = 0;

// Original colors
const vec3 COLOR_GREEN = vec3(0.502, 0.816, 0.063);   // #80d010
const vec3 COLOR_ORANGE = vec3(0.988, 0.596, 0.220);  // #fc9838
const vec3 COLOR_BROWN = vec3(0.784, 0.298, 0.047);   // #c84c0c

// Replacement palettes [frame][color]
const vec3 PALETTE_1_GREEN = vec3(0.0, 0.0, 0.0);           // #000000
const vec3 PALETTE_1_ORANGE = vec3(0.0, 0.502, 0.533);      // #008088
const vec3 PALETTE_1_BROWN = vec3(0.847, 0.157, 0.0);       // #d82800

const vec3 PALETTE_2_GREEN = vec3(0.847, 0.157, 0.0);       // #d82800
const vec3 PALETTE_2_ORANGE = vec3(0.988, 0.596, 0.220);    // #fc9838 (same)
const vec3 PALETTE_2_BROWN = vec3(0.988, 0.988, 0.988);     // #fcfcfc

const vec3 PALETTE_3_GREEN = vec3(0.0, 0.0, 0.659);         // #0000a8
const vec3 PALETTE_3_ORANGE = vec3(0.361, 0.580, 0.988);    // #5c94fc
const vec3 PALETTE_3_BROWN = vec3(0.988, 0.988, 0.988);     // #fcfcfc

const float TOLERANCE = 0.05;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	vec3 rgb = tex_color.rgb;

	if (palette_frame == 0) {
		COLOR = tex_color;  // Original colors
	} else {
		vec3 new_green, new_orange, new_brown;

		if (palette_frame == 1) {
			new_green = PALETTE_1_GREEN;
			new_orange = PALETTE_1_ORANGE;
			new_brown = PALETTE_1_BROWN;
		} else if (palette_frame == 2) {
			new_green = PALETTE_2_GREEN;
			new_orange = PALETTE_2_ORANGE;
			new_brown = PALETTE_2_BROWN;
		} else {
			new_green = PALETTE_3_GREEN;
			new_orange = PALETTE_3_ORANGE;
			new_brown = PALETTE_3_BROWN;
		}

		if (distance(rgb, COLOR_GREEN) < TOLERANCE) {
			rgb = new_green;
		} else if (distance(rgb, COLOR_ORANGE) < TOLERANCE) {
			rgb = new_orange;
		} else if (distance(rgb, COLOR_BROWN) < TOLERANCE) {
			rgb = new_brown;
		}

		COLOR = vec4(rgb, tex_color.a);
	}
}
