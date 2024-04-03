shader_type canvas_item;

// I hate that this is required, but godot has forced my hand-- see https://github.com/godotengine/godot-proposals/discussions/9354
uniform int light_count;

uniform bool apply_distance_fade;

uniform bool shadows;
uniform bool soft_shadows;
uniform float light_radius;
uniform uint shadow_march_count;
uniform float shadow_march_min_step;
uniform float shadow_march_step_scale;

uniform float ambient_amount : hint_range(0,1);
uniform bool ambient_occlusion;
uniform uint ao_step_count;
uniform float ao_step_size;
uniform float ao_influence : hint_range(0.0, 1.0);

varying vec2 screen_pix_size;
varying vec2 world_pos;
varying vec2 worldPosMin;
varying vec2 worldPosMax;
varying mat4 inv_canvas_matrix;
varying mat4 canvas_matrix;
varying vec2 screen_offset;
varying vec2 screen_scale;

// Beckmann distribution
float kSpec(vec3 N, vec3 H, float m) {
	float alpha = acos(dot(N,H));
	// alpha = max(abs(alpha) - angleTolerance, 0.0) * sign(alpha);
	float mSquared = m * m;
	return (exp(-pow(tan(alpha) / mSquared, 2.0)) / (PI * mSquared * pow(cos(alpha), 4.0)));
}
 
void vertex() {
	// whyyyy can't I have the matrices in fragment() or light()
	inv_canvas_matrix = inverse(CANVAS_MATRIX);
	canvas_matrix = CANVAS_MATRIX;
	// Saves a bit of time later
	world_pos = VERTEX;
	
	// I hate this but it's the only decent way I've found to get zoom in a canvas_shader
	vec2 minP = (vec4(vec2(0), 0, 1) * inverse(CANVAS_MATRIX)).xy;
	vec2 maxP = (vec4(100,100, 0, 1) * inverse(CANVAS_MATRIX)).xy;
	screen_scale = (maxP - minP) / 100.0;
}

void fragment() {
	// whyyyyy can't I have SCREEN_PIXEL_SIZE in vertex() or light()
	screen_pix_size = SCREEN_PIXEL_SIZE; 
	// When we apply the inverse CANVAS_MATRIX to a canvas coordinate, we won't be applying
	// offset-- this calculates how much we're offsetting, because the world space coordinates
	// from vertex() are accurate
	vec2 world_pos_without_offset = (vec4(VERTEX, 0, 1) * inv_canvas_matrix).xy;
	screen_offset = world_pos_without_offset - world_pos;
}

vec2 UVtoWorld(vec2 uv) {
	return (vec4((uv) / screen_pix_size, 0, 1) * inv_canvas_matrix).xy - screen_offset;
}

vec2 worldToUV(vec2 coord) {
	return (vec4((coord + screen_offset) * screen_pix_size, 0, 1) * canvas_matrix).xy;
}

void light() {
	// Soft shadows based on https://iquilezles.org/articles/rmshadows/
	vec2 marchPos = world_pos;
	vec2 lightPos = UVtoWorld(LIGHT_POSITION.xy * screen_pix_size);
	vec2 toLight = normalize(lightPos - marchPos);
	
	vec2 screenPos = LIGHT_VERTEX.xy;
	vec2 lightPosScreen = LIGHT_POSITION.xy;
	vec2 toLightScreen = normalize(lightPosScreen - screenPos);
	// We need to scale this by our scale factor because if we don't, everything breaks.
	// We also need this to respect x and y, hence not just multiplying by the length.
	float distToLight = distance(vec2(0), (lightPos - marchPos) * screen_scale);
	
	// Step distance, total distance
	float d, t = 0.0; 
	// Obscurity - basically, how obscured our ray is
	float obs = 1.0;
	
	// We can figure out how much the distances should be scaled by figuring out the difference
	// between a screenspace distance of 1px and a worldspace distanc of those points. We also
	// need to include our scaling factor, again bc everything breaks if we don't
	vec2 worldspaceScaleCalcA = UVtoWorld(vec2(0));
	vec2 worldspaceScaleCalcB = UVtoWorld((1.0 / screen_scale ) * screen_pix_size);
	float worldspaceDistanceScale = distance(vec2(0), vec2(screen_scale)) / distance(worldspaceScaleCalcA, worldspaceScaleCalcB);
	
	// Ideally I'd make this its own function but texture_sdf has forced my hand
	if(shadows) {
		obs = 0.0;
		for(uint i = uint(0); i < shadow_march_count; i++) {
			// texture_sdf returns screenspace distance, but we want world space distance
			d = texture_sdf(screen_uv_to_sdf(screenPos * screen_pix_size)) * worldspaceDistanceScale;
			// If we aren't using soft shadows, there's no reason to march through objects
			if(!soft_shadows && d <= 0.0001) {
				obs = 1.0;
				break;
			}
			// I don't entirely understand how this works, but the gist is that we can get a very good looking
			// soft shadow effect by storing how close the ray got to an obstacle
			if(soft_shadows) obs = max(0.5 - length(1.0 / screen_scale) * d * distToLight / (2.0 * light_radius * t), obs);
			// If we're in shadow no need to continue
			if(obs > 0.99) break;
			// Prevent getting stuck on the border of objects
			// 0.1 is a number I pulled out of my ass but it seems to work well enough
			// light_radius*t/distToLight is the relative size of the light or something idk I'm dumb
			d = max(d * shadow_march_step_scale, shadow_march_min_step  * light_radius*t/distToLight);
			t += d;
			// If we pass the light we know we're done
			if(t >= distToLight) break;
			marchPos += d * toLight;
			// To be frank, I have no idea why we need to divide by scale here, but it works
			screenPos += (d / worldspaceDistanceScale) * toLightScreen / screen_scale;
		}
		// Make sure we don't have any weird values lol
		obs = 1.0 - clamp(obs, 0.0, 1.0);
	}
	
	float ao = 1.0;
	if(ambient_occlusion) {
		// Ambient occlusion based on some random stuff I found on discord .-.
		marchPos = FRAGCOORD.xy;
		vec2 Epsilon = vec2(2.0, 0.0);
		// These normals are horrible but they seem to work well enough
		vec2 norm = texture_sdf_normal(screen_uv_to_sdf(SCREEN_UV));
		float res = 0.0;
		vec2 rp;
		// TBH I like vaguely understand how this works but not enough to explain it
		for(uint i = uint(1); i<ao_step_count; i++) {
			rp = marchPos + ao_step_size*float(i)*norm * screen_pix_size;
			res+=(1.0/pow(2.0,float(i)))*(ao_step_size*float(i)-(texture_sdf(screen_uv_to_sdf(rp * screen_pix_size))));
		}
		// We need an influence scaler bc otherwise I've found it to look rlly weird
		// That's probably just a skill issue though
		if(res >= 0.0) {
			ao = 1.0 - ao_influence * clamp(1.0 - ao_step_size / res, 0.0, 1.0);
		}
	}
	
	// Finally get the world distance (including height) for the final magnitude
	vec2 worldPos = UVtoWorld(SCREEN_UV);
	vec3 worldPosLight = vec3(UVtoWorld(LIGHT_POSITION.xy * screen_pix_size), LIGHT_POSITION.z);
	float worldDist = distance(vec3(0), (worldPosLight - vec3(worldPos, 0)) * vec3(screen_scale, 1));
	
	// PBR Lighting
	float roughness = SPECULAR_SHININESS.r;
	float specular = 1.0 - SPECULAR_SHININESS.g;
	float metallic = SPECULAR_SHININESS.b;
	
	float distance_fade = 1.0 / pow(worldDist / (200.0), 2.0);
	
	LIGHT = COLOR * ambient_amount * dot(NORMAL, vec3(0,0,1)) * ao / float(light_count);
	
	vec4 specularColor = mix(vec4(1), COLOR, metallic);
	vec4 specularAddition = specularColor * LIGHT_COLOR * LIGHT_ENERGY * max(kSpec(NORMAL, (LIGHT_DIRECTION + vec3(0,0,1)) * 0.5, specular), 0.0) * obs;
	vec4 diffuseAddition = roughness * LIGHT_COLOR * LIGHT_ENERGY * COLOR * max(dot(NORMAL, LIGHT_DIRECTION), 0.0) * obs;
	if(apply_distance_fade) {
		specularAddition *= distance_fade;
		diffuseAddition *= distance_fade;
	}
	LIGHT += specularAddition + diffuseAddition;
	LIGHT.a = 1.0;
}