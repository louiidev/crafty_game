#+build windows
package main

import "core:fmt"
import "core:log"

// TODO
// dump to file
// copy emscripten logger for location headers n shit


when DEBUG {
	LOG_LEVEL :: log.Level.Debug
} else {
	LOG_LEVEL :: log.Level.Info
}

logger_proc :: proc(
	data: rawptr,
	level: log.Level,
	text: string,
	options: log.Options,
	location := #caller_location,
) {
	fmt.println(level, LOG_LEVEL, level >= LOG_LEVEL)
	if level >= LOG_LEVEL {
		fmt.println(text)
	}
}

logger :: proc() -> log.Logger {
	return log.Logger{logger_proc, nil, log.Level.Debug, nil}
}
