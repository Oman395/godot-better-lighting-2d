shader_type canvas_item;
render_mode unshaded;

uniform vec2 camera_position;

varying vec2 screen_pix_size;
varying mat4 inv_canvas_matrix;
varying mat4 canvas_matrix;

void vertex() {
	// whyyyy can't I have the matrices in fragment() or light()
	inv_canvas_matrix = inverse(CANVAS_MATRIX);
	canvas_matrix = CANVAS_MATRIX;
}

vec2 UVtoWorld(vec2 uv) {
	return (vec4(uv / screen_pix_size, 0, 0) * inv_canvas_matrix).xy;
}

vec2 worldToUV(vec2 coord) {
	return (vec4(coord, 0, 0) * inv_canvas_matrix).xy * screen_pix_size;
}

void fragment() {
	screen_pix_size = SCREEN_PIXEL_SIZE;
	COLOR = vec4(0);
	vec2 marchPos = UVtoWorld(SCREEN_UV);
	vec2 lightPos = camera_position;
	// We need screen positions for some weirdness later
	vec2 lightPosScreen = worldToUV(camera_position) / screen_pix_size;
	vec2 toLight = normalize(lightPos - marchPos); 
	float d0 = texture_sdf(screen_uv_to_sdf(SCREEN_UV));
	if(d0 <= 3.0 && d0 >= 0.0) {
		// Soft shadows based on code I found in the desmos beta discord lmao

		// We also need the directions relative to the screen for weirdness mentioned above
		vec2 toLightScreen = normalize(lightPosScreen - SCREEN_UV / screen_pix_size);
		float distToLight = distance(marchPos, lightPos);
		
		float d, t = 0.0;
		vec2 screenPos = SCREEN_UV / screen_pix_size;
		
		// We can figure out how much the distances should be scaled by figuring out the difference between a screenspace distance of 1px and a worldspace distance
		// of those points
		vec2 worldspaceScaleCalcA = UVtoWorld(vec2(0));
		vec2 worldspaceScaleCalcB = UVtoWorld(vec2(1,0) * screen_pix_size);
		float worldspaceDistanceScale = 1.0 / distance(worldspaceScaleCalcA, worldspaceScaleCalcB);
		
		marchPos += toLight * 5.0;
		screenPos += (5.0 / worldspaceDistanceScale) * toLightScreen;
		
		// Ideally I'd make this its own function but texture_sdf has forced my han
		bool found = false;
		for(int i = 0; i < 256; i++) {
			// texture_sdf returns screenspace distance, but we want world space distance
			d = texture_sdf(screen_uv_to_sdf(screenPos * screen_pix_size)) * worldspaceDistanceScale;
			if(i == 0) d += 0.05;
			// If we aren't using soft shadows, there's no reason to march through objects
			if(d <= 0.01) {
				break;
			}
			t += d;
			// If we pass the center we know we're done
			if(t >= distToLight) {
				found = true;
				break;
			}
			marchPos += d * toLight;
			screenPos += (d / worldspaceDistanceScale) * toLightScreen;
		}
		
		if(found) COLOR = vec4(1,0,0,1);
	}
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
