//------------------------------------------------------------------------------
//  math.odin
//
//  The Odin glsl math package doesn't use the same conventions as
//  HandmadeMath in the original sokol samples, so just replicate
//  HandmadeMath to be consistent.
//------------------------------------------------------------------------------
package main
import "core:math"
import "core:math/linalg"

TAU :: 6.28318530717958647692528676655900576
PI :: 3.14159265358979323846264338327950288

Vector2 :: [2]f32
Vector2Int :: [2]int
Vector3 :: [3]f32
Vector4 :: [4]f32
Matrix4 :: linalg.Matrix4f32
v2 :: Vector2
v3 :: Vector3
v4 :: Vector4
mat4 :: Matrix4

COLOR_WHITE :: Vector4{1, 1, 1, 1}
COLOR_BLACK :: Vector4{0, 0, 0, 1}
COLOR_GREEN :: Vector4{0, 1, 0, 1}
COLOR_RED :: Vector4{1, 0, 0, 1}


extend :: proc(v: Vector2, z: f32 = 0.0) -> Vector3 {
	return {v.x, v.y, z}
}


radians :: proc(degrees: f32) -> f32 {return degrees * TAU / 360.0}

up :: proc() -> v3 {return {0.0, 1.0, 0.0}}

dot :: proc {
	dot_v3,
}
dot_v3 :: proc(v0, v1: v3) -> f32 {return v0.x * v1.x + v0.y * v1.y + v0.z * v1.z}

// len :: proc {
// 	len_v3,
// }
len_v3 :: proc(v: v3) -> f32 {return math.sqrt(dot(v, v))}

norm :: proc {
	norm_v3,
}
norm_v3 :: proc(v: v3) -> v3 {
	l := len_v3(v)
	if (l != 0) {
		return {v.x / l, v.y / l, v.z / l}
	} else {
		return {}
	}
}

cross :: proc {
	cross_v3,
}
cross_v3 :: proc(v0, v1: v3) -> v3 {
	return {
		(v0.y * v1.z) - (v0.z * v1.y),
		(v0.z * v1.x) - (v0.x * v1.z),
		(v0.x * v1.y) - (v0.y * v1.x),
	}
}

identity :: proc {
	identity_mat4,
}
identity_mat4 :: proc() -> mat4 {
	m: mat4 = {}
	m[0][0] = 1.0
	m[1][1] = 1.0
	m[2][2] = 1.0
	m[3][3] = 1.0
	return m
}

persp :: proc {
	persp_mat4,
}
persp_mat4 :: proc(fov, aspect, near, far: f32) -> mat4 {
	m := identity()
	t := math.tan(fov * (PI / 360))
	m[0][0] = 1.0 / t
	m[1][1] = aspect / t
	m[2][3] = -1.0
	m[2][2] = (near + far) / (near - far)
	m[3][2] = (2.0 * near * far) / (near - far)
	m[3][3] = 0
	return m
}


lookat :: proc {
	lookat_mat4,
}
lookat_mat4 :: proc(eye, center, up: v3) -> mat4 {
	m := mat4{}
	f := norm(center - eye)
	s := norm(cross(f, up))
	u := cross(s, f)

	m[0][0] = s.x
	m[0][1] = u.x
	m[0][2] = -f.x

	m[1][0] = s.y
	m[1][1] = u.y
	m[1][2] = -f.y

	m[2][0] = s.z
	m[2][1] = u.z
	m[2][2] = -f.z

	m[3][0] = -dot(s, eye)
	m[3][1] = -dot(u, eye)
	m[3][2] = dot(f, eye)
	m[3][3] = 1.0

	return m
}

rotate :: proc {
	rotate_mat4,
}
rotate_mat4 :: proc(angle: f32, axis_unorm: v3) -> mat4 {
	m := identity()

	axis := norm(axis_unorm)
	sin_theta := math.sin(radians(angle))
	cos_theta := math.cos(radians(angle))
	cos_value := 1.0 - cos_theta

	m[0][0] = (axis.x * axis.x * cos_value) + cos_theta
	m[0][1] = (axis.x * axis.y * cos_value) + (axis.z * sin_theta)
	m[0][2] = (axis.x * axis.z * cos_value) - (axis.y * sin_theta)
	m[1][0] = (axis.y * axis.x * cos_value) - (axis.z * sin_theta)
	m[1][1] = (axis.y * axis.y * cos_value) + cos_theta
	m[1][2] = (axis.y * axis.z * cos_value) + (axis.x * sin_theta)
	m[2][0] = (axis.z * axis.x * cos_value) + (axis.y * sin_theta)
	m[2][1] = (axis.z * axis.y * cos_value) - (axis.x * sin_theta)
	m[2][2] = (axis.z * axis.z * cos_value) + cos_theta

	return m
}

translate :: proc {
	translate_mat4,
}
translate_mat4 :: proc(translation: v3) -> mat4 {
	m := identity()
	m[3][0] = translation.x
	m[3][1] = translation.y
	m[3][2] = translation.z

	return m
}


V2_ZERO :: Vector2{0.0, 0.0}
V2_ONE :: Vector2{1.0, 1.0}
transform_2d :: proc(
	translation: v2 = V2_ZERO,
	rotation_z: f32 = 0.0,
	scale: Vector2 = V2_ONE,
) -> mat4 {
	tranform: Matrix4 = translate_mat4(extend(translation))

	if rotation_z != 0.0 {
		tranform *= linalg.matrix4_rotate(rotation_z, Vector3{0, 0, 1})
	}

	if scale != V2_ONE {
		tranform *= linalg.matrix4_scale(Vector3{scale.x, scale.y, 1.0})
	}

	return tranform
}

m4_transform :: proc(m: mat4, v: v4) -> v4 {
	result: v4
	result.x = m[0][0] * v.x + m[0][1] * v.y + m[0][2] * v.z + m[0][3] * v.w
	result.y = m[1][0] * v.x + m[1][1] * v.y + m[1][2] * v.z + m[1][3] * v.w
	result.z = m[2][0] * v.x + m[2][1] * v.y + m[2][2] * v.z + m[2][3] * v.w
	result.w = m[3][0] * v.x + m[3][1] * v.y + m[3][2] * v.z + m[3][3] * v.w

	return result
}

mul :: proc {
	m4_mul,
}
m4_mul :: proc(left, right: mat4) -> mat4 {
	m := mat4{}
	for col := 0; col < 4; col += 1 {
		for row := 0; row < 4; row += 1 {
			m[col][row] =
				left[0][row] * right[col][0] +
				left[1][row] * right[col][1] +
				left[2][row] * right[col][2] +
				left[3][row] * right[col][3]
		}
	}
	return m
}


m4_scalar :: proc(scalar: f32) -> mat4 {
	m: mat4
	m[0][0] = scalar
	m[1][1] = scalar
	m[2][2] = scalar
	m[3][3] = scalar
	return m
}


m4_inverse :: proc(m: mat4) -> mat4 {
	inv: mat4
	det: f32

	inv[0][0] =
		m[1][1] * m[2][2] * m[3][3] -
		m[1][1] * m[2][3] * m[3][2] -
		m[2][1] * m[1][2] * m[3][3] +
		m[2][1] * m[1][3] * m[3][2] +
		m[3][1] * m[1][2] * m[2][3] -
		m[3][1] * m[1][3] * m[2][2]

	inv[1][0] =
		-m[1][0] * m[2][2] * m[3][3] +
		m[1][0] * m[2][3] * m[3][2] +
		m[2][0] * m[1][2] * m[3][3] -
		m[2][0] * m[1][3] * m[3][2] -
		m[3][0] * m[1][2] * m[2][3] +
		m[3][0] * m[1][3] * m[2][2]

	inv[2][0] =
		m[1][0] * m[2][1] * m[3][3] -
		m[1][0] * m[2][3] * m[3][1] -
		m[2][0] * m[1][1] * m[3][3] +
		m[2][0] * m[1][3] * m[3][1] +
		m[3][0] * m[1][1] * m[2][3] -
		m[3][0] * m[1][3] * m[2][1]

	inv[3][0] =
		-m[1][0] * m[2][1] * m[3][2] +
		m[1][0] * m[2][2] * m[3][1] +
		m[2][0] * m[1][1] * m[3][2] -
		m[2][0] * m[1][2] * m[3][1] -
		m[3][0] * m[1][1] * m[2][2] +
		m[3][0] * m[1][2] * m[2][1]

	inv[0][1] =
		-m[0][1] * m[2][2] * m[3][3] +
		m[0][1] * m[2][3] * m[3][2] +
		m[2][1] * m[0][2] * m[3][3] -
		m[2][1] * m[0][3] * m[3][2] -
		m[3][1] * m[0][2] * m[2][3] +
		m[3][1] * m[0][3] * m[2][2]

	inv[1][1] =
		m[0][0] * m[2][2] * m[3][3] -
		m[0][0] * m[2][3] * m[3][2] -
		m[2][0] * m[0][2] * m[3][3] +
		m[2][0] * m[0][3] * m[3][2] +
		m[3][0] * m[0][2] * m[2][3] -
		m[3][0] * m[0][3] * m[2][2]

	inv[2][1] =
		-m[0][0] * m[2][1] * m[3][3] +
		m[0][0] * m[2][3] * m[3][1] +
		m[2][0] * m[0][1] * m[3][3] -
		m[2][0] * m[0][3] * m[3][1] -
		m[3][0] * m[0][1] * m[2][3] +
		m[3][0] * m[0][3] * m[2][1]

	inv[3][1] =
		m[0][0] * m[2][1] * m[3][2] -
		m[0][0] * m[2][2] * m[3][1] -
		m[2][0] * m[0][1] * m[3][2] +
		m[2][0] * m[0][2] * m[3][1] +
		m[3][0] * m[0][1] * m[2][2] -
		m[3][0] * m[0][2] * m[2][1]

	inv[0][2] =
		m[0][1] * m[1][2] * m[3][3] -
		m[0][1] * m[1][3] * m[3][2] -
		m[1][1] * m[0][2] * m[3][3] +
		m[1][1] * m[0][3] * m[3][2] +
		m[3][1] * m[0][2] * m[1][3] -
		m[3][1] * m[0][3] * m[1][2]

	inv[1][2] =
		-m[0][0] * m[1][2] * m[3][3] +
		m[0][0] * m[1][3] * m[3][2] +
		m[1][0] * m[0][2] * m[3][3] -
		m[1][0] * m[0][3] * m[3][2] -
		m[3][0] * m[0][2] * m[1][3] +
		m[3][0] * m[0][3] * m[1][2]

	inv[2][2] =
		m[0][0] * m[1][1] * m[3][3] -
		m[0][0] * m[1][3] * m[3][1] -
		m[1][0] * m[0][1] * m[3][3] +
		m[1][0] * m[0][3] * m[3][1] +
		m[3][0] * m[0][1] * m[1][3] -
		m[3][0] * m[0][3] * m[1][1]

	inv[3][2] =
		-m[0][0] * m[1][1] * m[3][2] +
		m[0][0] * m[1][2] * m[3][1] +
		m[1][0] * m[0][1] * m[3][2] -
		m[1][0] * m[0][2] * m[3][1] -
		m[3][0] * m[0][1] * m[1][2] +
		m[3][0] * m[0][2] * m[1][1]

	inv[0][3] =
		-m[0][1] * m[1][2] * m[2][3] +
		m[0][1] * m[1][3] * m[2][2] +
		m[1][1] * m[0][2] * m[2][3] -
		m[1][1] * m[0][3] * m[2][2] -
		m[2][1] * m[0][2] * m[1][3] +
		m[2][1] * m[0][3] * m[1][2]

	inv[1][3] =
		m[0][0] * m[1][2] * m[2][3] -
		m[0][0] * m[1][3] * m[2][2] -
		m[1][0] * m[0][2] * m[2][3] +
		m[1][0] * m[0][3] * m[2][2] +
		m[2][0] * m[0][2] * m[1][3] -
		m[2][0] * m[0][3] * m[1][2]

	inv[2][3] =
		-m[0][0] * m[1][1] * m[2][3] +
		m[0][0] * m[1][3] * m[2][1] +
		m[1][0] * m[0][1] * m[2][3] -
		m[1][0] * m[0][3] * m[2][1] -
		m[2][0] * m[0][1] * m[1][3] +
		m[2][0] * m[0][3] * m[1][1]

	inv[3][3] =
		m[0][0] * m[1][1] * m[2][2] -
		m[0][0] * m[1][2] * m[2][1] -
		m[1][0] * m[0][1] * m[2][2] +
		m[1][0] * m[0][2] * m[2][1] +
		m[2][0] * m[0][1] * m[1][2] -
		m[2][0] * m[0][2] * m[1][1]

	det = m[0][0] * inv[0][0] + m[0][1] * inv[1][0] + m[0][2] * inv[2][0] + m[0][3] * inv[3][0]

	if (det == 0) {
		return m4_scalar(0)
	}
	det = 1.0 / det

	for i := 0; i < 4; i += 1 {
		for j := 0; j < 4; j += 1 {
			inv[i][j] *= det
		}
	}

	return inv
}


hex_to_rgb :: proc(hex: int) -> Vector4 {
	r := (hex >> 16) & 0xFF
	g := (hex >> 8) & 0xFF
	b := hex & 0xFF
	return Vector4{f32(r) / 255.0, f32(g) / 255.0, f32(b) / 255.0, 1}
}


matrix_position :: proc(mat: Matrix4) -> Vector2 {
	return Vector2 {
		mat[3][0], // Translation in X
		mat[3][1], // Translation in Y
	}
}
