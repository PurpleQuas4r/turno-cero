shader_type canvas_item;
render_mode unshaded;

uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 sun_uv = vec2(0.5, 0.484);
uniform bool sunlight = true;

float transmission(vec3 color) {
	float light = dot(color, vec3(0.31, 0.55, 0.14));
	return smoothstep(0.21, 0.58, light);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 pixel = SCREEN_PIXEL_SIZE;
	vec3 original = texture(scene_color, uv).rgb;
	vec3 soft = (
		texture(scene_color, uv + vec2(pixel.x, 0.0)).rgb +
		texture(scene_color, uv - vec2(pixel.x, 0.0)).rgb +
		texture(scene_color, uv + vec2(0.0, pixel.y)).rgb +
		texture(scene_color, uv - vec2(0.0, pixel.y)).rgb
	) * 0.25;
	vec3 result = mix(original, soft, 0.18);
	if (sunlight) {
		vec2 from_sun = uv - sun_uv;
		vec2 aspect = vec2(pixel.y / pixel.x, 1.0);
		float distance_to_sun = length(from_sun * aspect);
		vec2 direction = normalize(from_sun + vec2(0.00001));
		vec2 cross_ray = vec2(-direction.y, direction.x);
		float center_visibility = 0.0;
		float nearby_visibility = 0.0;
		for (int i = 1; i <= 18; i++) {
			float t = float(i) / 19.0;
			vec2 sample_uv = mix(uv, sun_uv, t * 0.82);
			vec2 separation = cross_ray * pixel * 6.0 * (1.0 - t);
			center_visibility += transmission(texture(scene_color, sample_uv).rgb);
			nearby_visibility += 0.5 * (
				transmission(texture(scene_color, sample_uv + separation).rgb) +
				transmission(texture(scene_color, sample_uv - separation).rgb)
			);
		}
		center_visibility /= 18.0;
		nearby_visibility /= 18.0;
		float fade = smoothstep(0.12, 0.22, distance_to_sun) * (1.0 - smoothstep(0.38, 0.86, distance_to_sun));
		float angle = atan(from_sun.y, from_sun.x * aspect.x);
		float fan = pow(0.5 + 0.5 * cos(angle * 25.0 + 1.1), 5.0);
		float shaft = max(0.0, center_visibility - nearby_visibility) * 0.53;
		shaft += fan * center_visibility * 0.047;
		float glow = pow(center_visibility, 2.0) * 0.032;
		float edge = max(0.0, transmission(texture(scene_color, uv - direction * pixel * 1.3).rgb) - transmission(original));
		vec3 warm = vec3(1.0, 0.64, 0.36);
		result += warm * ((shaft + glow) * fade + edge * 0.12 * (1.0 - smoothstep(0.26, 0.68, distance_to_sun)));
	}
	COLOR = vec4(result, 1.0);
}
