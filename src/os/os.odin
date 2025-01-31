/*
An abstraction of some `core:os` stuff that work on the web with emscripten. See
`os_web.odin` for the web implementations.
*/

package web_compatible_os

@(require_results)
exists :: proc(name: string) -> bool {
	return _exists(name)
}

@(require_results)
read_entire_file :: proc(name: string, allocator := context.allocator, loc := #caller_location, from_persist := false) -> (data: []byte, success: bool) {
	return _read_entire_file(name, allocator, loc, from_persist)
}

write_entire_file :: proc(name: string, data: []byte, truncate := true, persist := false) -> (success: bool) {
	return _write_entire_file(name, data, truncate, persist)
}