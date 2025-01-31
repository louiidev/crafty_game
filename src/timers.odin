
package main

Timer :: struct {
    on_end: proc(),
    loop: bool,
    time_left: f32
}
