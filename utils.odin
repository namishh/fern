package sakura

clamp :: proc(value, min_val, max_val: f32) -> f32 {
    return max(min_val, min(max_val, value))
}

min :: proc(a, b: f32) -> f32 {
    return a if a < b else b
}

max :: proc(a, b: f32) -> f32 {
    return a if a > b else b
}

abs :: proc(a: f32) -> f32 {
    return a if a >= 0 else -a
}