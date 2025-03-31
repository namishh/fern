package fern

clamp :: proc(value, min_val, max_val: $T) -> T {
    if value < min_val do return min_val
    if value > max_val do return max_val
    return value
}

min :: proc(a, b: $T) -> T {
    return a if a < b else b
}

max :: proc(a, b: f32) -> f32 {
    return a if a > b else b
}

abs :: proc(a: f32) -> f32 {
    return a if a >= 0 else -a
}