package tests

import "core:fmt"
import "core:testing"


e :: enum {
	one,
	two,
	three,
}

@(test)
my_test :: proc(t: ^testing.T) {
	// This tests succeeds by default.
	for value in e {
		fmt.printfln("Enum: {}", value)

	}


}
