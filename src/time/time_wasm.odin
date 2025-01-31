#+build freestanding
#+build wasm32, wasm64p32
#+private

package web_time

_IS_SUPPORTED :: true

@(default_calling_convention = "c")
foreign {
	unix_time_nanoseconds :: proc() -> u64 --- // custom c export
}

_now :: proc "contextless" () -> Time {
	return {i64(unix_time_nanoseconds())}
}

_sleep :: proc "contextless" (d: Duration) { }

_tick_now :: proc "contextless" () -> Tick { return {} }

_yield :: proc "contextless" () { }