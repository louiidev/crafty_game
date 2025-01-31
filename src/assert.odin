#+build freestanding
#+build wasm32, wasm64p32
package main

import "base:runtime"
import "core:log"
import "core:strings"

web_assertion_failure_proc :: proc(
	prefix, message: string,
	loc: runtime.Source_Code_Location,
) -> ! {
	prefix: cstring = strings.clone_to_cstring(prefix, context.temp_allocator)
	message: cstring = strings.clone_to_cstring(message, context.temp_allocator)
	web_assertion_contextless_failure_proc(prefix, message, loc)
}

web_assertion_contextless_failure_proc :: proc "contextless" (
	prefix, message: cstring,
	loc: runtime.Source_Code_Location,
) -> ! {

	puts(prefix)
	puts(message)

	runtime.trap()
}
