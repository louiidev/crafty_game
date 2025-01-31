package main
import "base:intrinsics"

BaseEntity :: struct {
	active:   bool,
	position: Vector2,
}


// cleanup_base_entity :: proc(data: ^[dynamic]BaseEntity) {
// 	for i := len(data) - 1; i >= 0; i -= 1 {
// 		if (!data[i].active) {
// 			ordered_remove(data, i)
// 		}
// 	}
// }


cleanup_base_entity :: proc(data: ^[dynamic]$T) where intrinsics.type_is_struct(T) {
	// Iterate in reverse order to avoid issues when removing items
	for i := len(data) - 1; i >= 0; i -= 1 {
		if !data[i].active {
			ordered_remove(data, i)
		}
	}
}
