shader_type spatial;
render_mode skip_vertex_transform, diffuse_lambert;

// Vertex snapping granularity (higher = less wobble)
uniform float snap_resolution : hint_range(40.0, 200.0, 1.0) = 120.0;

// Affine texture warping intensity (0 = perspective-correct, 1 = full PS1 affine)
uniform float affine_intensity : hint_range(0.0, 1.0, 0.01) = 0.5;

// Albedo texture (nearest-neighbor filtered)
uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform bool use_albedo_texture = false;

// Tint color
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Emission
uniform bool emission_enabled = false;
uniform vec3 emission_color : source_color = vec3(0.0, 0.0, 0.0);

// Varyings for affine texture mapping
varying vec2 affine_uv;
varying float affine_z;
varying vec2 corrected_uv;

void vertex() {
	// With skip_vertex_transform, we must handle the full transform manually.

	// Transform vertex to view space
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);

	// Save depth before snapping for affine mapping
	float depth = view_pos.z;

	// Snap X and Y to grid in view space (PSX vertex snapping / jitter)
	view_pos.x = floor(view_pos.x * snap_resolution + 0.5) / snap_resolution;
	view_pos.y = floor(view_pos.y * snap_resolution + 0.5) / snap_resolution;

	// Set the snapped view-space position
	VERTEX = view_pos.xyz;

	// Use inverse-transpose for normals so non-uniformly scaled meshes
	// (like stretched walls) keep correct lighting.
	mat3 normal_matrix = transpose(inverse(mat3(MODELVIEW_MATRIX)));
	NORMAL = normalize(normal_matrix * NORMAL);

	// Pass affine UV data to fragment shader
	// Multiply UV by depth for affine mapping (negate z since view space z is negative)
	affine_uv = UV * -depth;
	affine_z = -depth;
	corrected_uv = UV;

	// Apply projection
	POSITION = PROJECTION_MATRIX * view_pos;
}

void fragment() {
	// Recover perspective-correct UVs from affine data
	vec2 perspective_uv = affine_uv / affine_z;

	// Mix between perspective-correct and affine UVs
	// When affine_intensity = 0: fully perspective-correct
	// When affine_intensity = 1: fully affine (PS1-style warping)
	vec2 final_uv = mix(perspective_uv, corrected_uv, affine_intensity);

	// Use flat color by default. Test geometry in the level has no textures.
	vec4 final_color = albedo_color;
	if (use_albedo_texture) {
		final_color *= texture(albedo_texture, final_uv);
	}

	ALBEDO = final_color.rgb;

	// Handle emission for self-lit surfaces
	if (emission_enabled) {
		EMISSION = emission_color;
	}
}
