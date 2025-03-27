package sakura

import rl "vendor:raylib"

// CURSOR
cursor :: struct {
    normal, hand_released, hand_grabbing: rl.Texture2D,
}

cursor_init :: proc() -> cursor {
    normal_img := rl.LoadImage("assets/cursors/normal.png")
    defer rl.UnloadImage(normal_img)

    hand_released_img := rl.LoadImage("assets/cursors/hand_released.png")
    defer rl.UnloadImage(hand_released_img)

    hand_grabbing_img := rl.LoadImage("assets/cursors/hand_grabbing.png")
    defer rl.UnloadImage(hand_grabbing_img)

    return cursor{
        normal = rl.LoadTextureFromImage(normal_img),
        hand_released = rl.LoadTextureFromImage(hand_released_img),
        hand_grabbing = rl.LoadTextureFromImage(hand_grabbing_img),
    }
}

cursor_deinit :: proc(self: ^cursor) {
    rl.UnloadTexture(self.normal)
    rl.UnloadTexture(self.hand_released)
    rl.UnloadTexture(self.hand_grabbing)
}

cursor_draw :: proc(self: ^cursor, hand_mode: bool, dragging: bool) {
    if !rl.IsWindowFocused() || !rl.IsCursorOnScreen() {
        return
    }

    mouse_x := f32(rl.GetMouseX())
    mouse_y := f32(rl.GetMouseY())
    texture := hand_mode ? (dragging ? self.hand_grabbing : self.hand_released) : self.normal

    rl.DrawTexturePro(
        texture,
        rl.Rectangle{x = 0, y = 0, width = f32(texture.width), height = f32(texture.height)},
        rl.Rectangle{x = mouse_x, y = mouse_y, width = f32(texture.width), height = f32(texture.height)},
        rl.Vector2{0, 0}, 
        0,
        rl.WHITE,
    )
}