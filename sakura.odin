package sakura

import rl "vendor:raylib"
import img "core:image"
import math "core:math"
import fmt "core:fmt"
import os "core:os"

// ITEM
item_type :: enum {
    image,
    text
}

item :: struct {
    type: item_type,
    using image: image_item,
}

image_item :: struct {
    image_data: [^]u8,
    texture: rl.Texture2D,
    x, y: f32,
    scale_x, scale_y: f32,
    width, height: f32,
    rotation: f32
}

item_deinit :: proc(i: ^item) {
    switch i.type {
        case .image:
            rl.UnloadTexture(i.texture)
        case .text:
            // Add handling for text type if needed
    }
}

item_get_bounding_box :: proc(self: ^item) -> rl.Rectangle { 
    switch self.type {
    case .image:
        return rl.Rectangle{
            x = self.x,
            y = self.y,
            width = self.width * self.scale_x,
            height = self.height * self.scale_y,
        }
    case .text:
        return rl.Rectangle{}
    }
    return rl.Rectangle{}
}

// SELECTOR
selector :: struct {
    selected_item: Maybe(int),
    handle_size: f32,
    rotation_line_length: f32,
    resizing: bool,
    active_handle: Maybe(handle_type),
    border_color: rl.Color,
    handle_color: rl.Color,
}

handle_type :: enum {
    top_left,
    top_right,
    bottom_left,
    bottom_right,
    top_mid,
    bottom_mid,
    left_mid,
    right_mid,
}

selector_init :: proc() -> selector {
    return selector{
        selected_item = nil,
        handle_size = 12.0,
        rotation_line_length = 30.0,
        resizing = false,
        active_handle = nil,
        border_color = rl.Color{177, 98, 134, 255},
        handle_color = rl.Color{177, 99, 134, 255},
    }
}

selector_get_handle_at_position :: proc(self: selector, items: []item, canvas_x, canvas_y, canvas_scale, mouse_x, mouse_y: f32) -> Maybe(handle_type) {
    if idx, ok := self.selected_item.?; ok {
        if idx >= len(items) {
            return nil
        }
        item := items[idx]
        bounds := item_get_bounding_box(&item)
        adjusted_bounds := rl.Rectangle{
            x = canvas_x + bounds.x * canvas_scale,
            y = canvas_y + bounds.y * canvas_scale,
            width = bounds.width * canvas_scale,
            height = bounds.height * canvas_scale,
        }

        half_handle := self.handle_size / 2.0

        handles := []struct{type: handle_type, x, y: f32}{
            {type = .top_left,     x = adjusted_bounds.x - half_handle,                   y = adjusted_bounds.y - half_handle},
            {type = .top_right,    x = adjusted_bounds.x + adjusted_bounds.width - half_handle, y = adjusted_bounds.y - half_handle},
            {type = .bottom_left,  x = adjusted_bounds.x - half_handle,                   y = adjusted_bounds.y + adjusted_bounds.height - half_handle},
            {type = .bottom_right, x = adjusted_bounds.x + adjusted_bounds.width - half_handle, y = adjusted_bounds.y + adjusted_bounds.height - half_handle},
            {type = .top_mid,      x = adjusted_bounds.x + adjusted_bounds.width / 2.0 - half_handle, y = adjusted_bounds.y - half_handle},
            {type = .bottom_mid,   x = adjusted_bounds.x + adjusted_bounds.width / 2.0 - half_handle, y = adjusted_bounds.y + adjusted_bounds.height - half_handle},
            {type = .left_mid,     x = adjusted_bounds.x - half_handle,                   y = adjusted_bounds.y + adjusted_bounds.height / 2.0 - half_handle},
            {type = .right_mid,    x = adjusted_bounds.x + adjusted_bounds.width - half_handle, y = adjusted_bounds.y + adjusted_bounds.height / 2.0 - half_handle},
        }

        for handle in handles {
            handle_rect := rl.Rectangle{
                x = handle.x,
                y = handle.y,
                width = self.handle_size,
                height = self.handle_size,
            }
            if rl.CheckCollisionPointRec(rl.Vector2{mouse_x, mouse_y}, handle_rect) {
                return handle.type
            }
        }
    }
    return nil
}

selector_draw :: proc(self: selector, items: []item, canvas_x, canvas_y, canvas_scale: f32) {
    if idx, ok := self.selected_item.?; ok {
        if idx >= len(items) {
            return
        }
        item := items[idx]
        bounds := item_get_bounding_box(&item)
        adjusted_bounds := rl.Rectangle{
            x = canvas_x + bounds.x * canvas_scale,
            y = canvas_y + bounds.y * canvas_scale,
            width = bounds.width * canvas_scale,
            height = bounds.height * canvas_scale,
        }

        rl.DrawRectangleLinesEx(adjusted_bounds, 3, self.border_color)

        half_handle := self.handle_size / 2.0

        top_center_x := adjusted_bounds.x + adjusted_bounds.width / 2.0
        top_center_y := adjusted_bounds.y
        rl.DrawLineEx(
            rl.Vector2{top_center_x, top_center_y},
            rl.Vector2{top_center_x, top_center_y - self.rotation_line_length},
            1.0,
            self.border_color,
        )
        rl.DrawCircleV(
            rl.Vector2{top_center_x, top_center_y - self.rotation_line_length},
            self.handle_size / 2.0,
            self.border_color,
        )

        rl.DrawRectangleRec(rl.Rectangle{
            x = adjusted_bounds.x - half_handle,
            y = adjusted_bounds.y - half_handle,
            width = self.handle_size,
            height = self.handle_size,
        }, self.handle_color)
        
        rl.DrawRectangleRec(rl.Rectangle{
            x = adjusted_bounds.x + adjusted_bounds.width - half_handle,
            y = adjusted_bounds.y - half_handle,
            width = self.handle_size,
            height = self.handle_size,
        }, self.handle_color)
        
        rl.DrawRectangleRec(rl.Rectangle{
            x = adjusted_bounds.x - half_handle,
            y = adjusted_bounds.y + adjusted_bounds.height - half_handle,
            width = self.handle_size,
            height = self.handle_size,
        }, self.handle_color)
        
        rl.DrawRectangleRec(rl.Rectangle{
            x = adjusted_bounds.x + adjusted_bounds.width - half_handle,
            y = adjusted_bounds.y + adjusted_bounds.height - half_handle,
            width = self.handle_size,
            height = self.handle_size,
        }, self.handle_color)
        
        rl.DrawRectangleRec(rl.Rectangle{
            x = adjusted_bounds.x + adjusted_bounds.width / 2.0 - half_handle,
            y = adjusted_bounds.y - half_handle,
            width = self.handle_size,
            height = self.handle_size,
        }, self.handle_color)
        
        rl.DrawRectangleRec(rl.Rectangle{
            x = adjusted_bounds.x + adjusted_bounds.width / 2.0 - half_handle,
            y = adjusted_bounds.y + adjusted_bounds.height - half_handle,
            width = self.handle_size,
            height = self.handle_size,
        }, self.handle_color)
        
        rl.DrawRectangleRec(rl.Rectangle{
            x = adjusted_bounds.x - half_handle,
            y = adjusted_bounds.y + adjusted_bounds.height / 2.0 - half_handle,
            width = self.handle_size,
            height = self.handle_size,
        }, self.handle_color)
        
        rl.DrawRectangleRec(rl.Rectangle{
            x = adjusted_bounds.x + adjusted_bounds.width - half_handle,
            y = adjusted_bounds.y + adjusted_bounds.height / 2.0 - half_handle,
            width = self.handle_size,
            height = self.handle_size,
        }, self.handle_color)
    }
}

selector_clear_selection :: proc(self: ^selector) {
    self.selected_item = nil
    self.resizing = false
    self.active_handle = nil
}

// CANVAS
canvas :: struct {
    items : [dynamic]item,
    x, y: f32,
    cursor: ^cursor,
    selector: ^selector,
    scale, min_scale, max_scale: f32,
    dragging, draggin_item, hand_mode: bool,
    selecting: bool,
    grid_spacing: f32,
    imx, imy : f32, // initial mouse x and y
    icx, icy : f32, // initial canvas x and y
    iix, iiy : f32, // initial item x and y
    iiw, iih : f32, // initial item width and height
    iisx, iisy : f32, // initial item scale x and y
    selector_start_x, selector_start_y: f32,
}

canvas_init :: proc() -> canvas {
    s := selector_init()
    c := cursor_init()
    sel := new(selector)
    cur := new(cursor)
    sel^ = s
    cur^ = c
    return canvas{
        items = [dynamic]item{},
        x = 0,
        y = 0,
        cursor = cur,
        selector = sel,
        scale = 1.0,
        min_scale = 0.1,
        max_scale = 5.0,
        dragging = false,
        draggin_item = false,
        hand_mode = false,
        selecting = false,
        grid_spacing = 50.0,
        imx = 0, imy = 0, 
        icx = 0, icy = 0, 
        iix = 0, iiy = 0, 
        iiw = 0, iih = 0, 
        iisx = 0, iisy = 0,
        selector_start_x = 0,
        selector_start_y = 0,
    }
}

canvas_deinit :: proc(self: ^canvas) {
    for &i in self.items {
        item_deinit(&i)
    }
    cursor_deinit(self.cursor)
    selector_clear_selection(self.selector)
    free(self.cursor)
    free(self.selector)
    delete(self.items)
}

canvas_add_image :: proc(self: ^canvas, image_path: cstring, x, y: f32) -> bool {
    image := rl.LoadImage(image_path)
    image_data := cast([^]u8)image.data
    if image.data == nil {
        return false
    }
    defer rl.UnloadImage(image)

    texture := rl.LoadTextureFromImage(image)
    new_image := image_item{
        texture = texture,
        x = x,
        y = y,
        image_data = image_data,
        scale_x = 1.0,
        scale_y = 1.0,
        width = f32(texture.width),
        height = f32(texture.height),
        rotation = 0,
    }

    append(&self.items, item{
        type = .image,
        image = new_image,
    })
    return true
}

canvas_update :: proc(self: ^canvas) {
    if rl.IsKeyPressed(.H) {
        self.hand_mode = true
        self.selecting = false
        self.dragging = false
        self.draggin_item = false
        selector_clear_selection(self.selector)
    } else if rl.IsKeyPressed(.V) {
        self.hand_mode = false
        self.dragging = false
        self.draggin_item = false
        self.selecting = false
    }

    mouse_x := f32(rl.GetMouseX())
    mouse_y := f32(rl.GetMouseY())
    ctrl_pressed := rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL)

    wheel_move := rl.GetMouseWheelMove()
    if ctrl_pressed && wheel_move != 0 {
        canvas_zoom(self, mouse_x, mouse_y, wheel_move * 0.2)
    }

    if ctrl_pressed {
        if rl.IsKeyPressed(.KP_ADD) || rl.IsKeyPressed(.EQUAL) {
            canvas_zoom(self, mouse_x, mouse_y, 0.5)
        }
        if rl.IsKeyPressed(.KP_SUBTRACT) || rl.IsKeyPressed(.MINUS) {
            canvas_zoom(self, mouse_x, mouse_y, -0.5)
        }
    }

    if self.hand_mode {
        if rl.IsMouseButtonPressed(.LEFT) {
            self.dragging = true
            self.imx = mouse_x
            self.imy = mouse_y
            self.icx = self.x
            self.icy = self.y
        } else if rl.IsMouseButtonReleased(.LEFT) {
            self.dragging = false
        }

        if self.dragging {
            delta_x := (mouse_x - self.imx) / self.scale
            delta_y := (mouse_y - self.imy) / self.scale
            self.x = self.icx + delta_x
            self.y = self.icy + delta_y
        }
    } else {
        if rl.IsMouseButtonPressed(.LEFT) {
            if idx, ok := self.selector.selected_item.?; ok {
                if self.selector.active_handle == nil {
                    self.selector.active_handle = selector_get_handle_at_position(self.selector^, self.items[:], self.x, self.y, self.scale, mouse_x, mouse_y)
                    if self.selector.active_handle != nil {
                        self.selector.resizing = true
                        bounds := item_get_bounding_box(&self.items[idx])
                        self.iiw = bounds.width
                        self.iih = bounds.height
                        self.iix = bounds.x
                        self.iiy = bounds.y
                        self.imx = mouse_x
                        self.imy = mouse_y
                        if self.items[idx].type == .image {
                            self.iisx = self.items[idx].scale_x
                            self.iisy = self.items[idx].scale_y
                        }
                    }
                }
            }

            if !self.selector.resizing {
                found_item: Maybe(int) = nil
                for i := len(self.items) - 1; i >= 0; i -= 1 {
                    bounds := item_get_bounding_box(&self.items[i])
                    adjusted_bounds := rl.Rectangle{
                        x = self.x + bounds.x * self.scale,
                        y = self.y + bounds.y * self.scale,
                        width = bounds.width * self.scale,
                        height = bounds.height * self.scale,
                    }
                    if rl.CheckCollisionPointRec(rl.Vector2{mouse_x, mouse_y}, adjusted_bounds) {
                        found_item = i
                        break
                    }
                }

                if idx, ok := found_item.?; ok {
                    self.selector.selected_item = found_item
                    self.draggin_item = true
                    self.imx = mouse_x
                    self.imy = mouse_y
                    bounds := item_get_bounding_box(&self.items[idx])
                    self.iix = bounds.x
                    self.iiy = bounds.y
                } else {
                    self.selector.selected_item = nil
                    self.selecting = true
                    self.selector_start_x = mouse_x
                    self.selector_start_y = mouse_y
                }
            }
        } else if rl.IsMouseButtonReleased(.LEFT) {
            self.selecting = false
            self.draggin_item = false
            self.selector.resizing = false
            self.selector.active_handle = nil
        }

        if self.selector.resizing && self.selector.active_handle != nil && self.selector.selected_item != nil {
            if idx, ok := self.selector.selected_item.?; ok {
                if handle, ok := self.selector.active_handle.?; ok {
                    delta_x := (mouse_x - self.imx) / self.scale
                    delta_y := (mouse_y - self.imy) / self.scale

                    if self.items[idx].type == .image {
                        new_scale_x := self.items[idx].scale_x
                        new_scale_y := self.items[idx].scale_y
                        new_x := self.items[idx].x
                        new_y := self.items[idx].y

                        switch handle {
                        case .top_left:
                            new_scale_x = (self.iiw - delta_x) / self.items[idx].width
                            new_scale_y = (self.iih - delta_y) / self.items[idx].height
                            new_scale := clamp((new_scale_x + new_scale_y) / 2.0, 0.1, 10.0)
                            new_scale_x = new_scale
                            new_scale_y = new_scale
                            new_x = self.iix + delta_x
                            new_y = self.iiy + delta_y
                        case .top_right:
                            new_scale_x = (self.iiw + delta_x) / self.items[idx].width
                            new_scale_y = (self.iih - delta_y) / self.items[idx].height
                            new_scale := clamp((new_scale_x + new_scale_y) / 2.0, 0.1, 10.0)
                            new_scale_x = new_scale
                            new_scale_y = new_scale
                            new_y = self.iiy + delta_y
                        case .bottom_left:
                            new_scale_x = (self.iiw - delta_x) / self.items[idx].width
                            new_scale_y = (self.iih + delta_y) / self.items[idx].height
                            new_scale := clamp((new_scale_x + new_scale_y) / 2.0, 0.1, 10.0)
                            new_scale_x = new_scale
                            new_scale_y = new_scale
                            new_x = self.iix + delta_x
                        case .bottom_right:
                            new_scale_x = (self.iiw + delta_x) / self.items[idx].width
                            new_scale_y = (self.iih + delta_y) / self.items[idx].height
                            new_scale := clamp((new_scale_x + new_scale_y) / 2.0, 0.1, 10.0)
                            new_scale_x = new_scale
                            new_scale_y = new_scale
                        case .top_mid:
                            new_scale_y = clamp((self.iih - delta_y) / self.items[idx].height, 0.1, 10.0)
                            new_y = self.iiy + delta_y
                        case .bottom_mid:
                            new_scale_y = clamp((self.iih + delta_y) / self.items[idx].height, 0.1, 10.0)
                        case .left_mid:
                            new_scale_x = clamp((self.iiw - delta_x) / self.items[idx].width, 0.1, 10.0)
                            new_x = self.iix + delta_x
                        case .right_mid:
                            new_scale_x = clamp((self.iiw + delta_x) / self.items[idx].width, 0.1, 10.0)
                        }

                        self.items[idx].scale_x = new_scale_x
                        self.items[idx].scale_y = new_scale_y
                        self.items[idx].x = new_x
                        self.items[idx].y = new_y
                    }
                }
            }
        }

        if self.draggin_item {
            if idx, ok := self.selector.selected_item.?; ok {
                delta_x := (mouse_x - self.imx) / self.scale
                delta_y := (mouse_y - self.imy) / self.scale
                if self.items[idx].type == .image {
                    self.items[idx].x = self.iix + delta_x
                    self.items[idx].y = self.iiy + delta_y
                }
            }
        }
    }
}

canvas_zoom :: proc(self: ^canvas, mouse_x, mouse_y, delta: f32) {
    old_scale := self.scale
    self.scale = clamp(self.scale + delta, self.min_scale, self.max_scale)

    world_x := (mouse_x - self.x) / old_scale
    world_y := (mouse_y - self.y) / old_scale
    self.x = mouse_x - (world_x * self.scale)
    self.y = mouse_y - (world_y * self.scale)
}

canvas_draw :: proc(self: ^canvas) {
    canvas_draw_grid(self)
    
    for &item in self.items {
        switch item.type {
        case .image:
            dest_rec := rl.Rectangle{
                x = self.x + item.x * self.scale,
                y = self.y + item.y * self.scale,
                width = item.width * item.scale_x * self.scale,
                height = item.height * item.scale_y * self.scale,
            }
            rl.DrawTexturePro(
                item.texture,
                rl.Rectangle{x = 0, y = 0, width = f32(item.texture.width), height = f32(item.texture.height)},
                dest_rec,
                rl.Vector2{0, 0},
                item.rotation,
                rl.WHITE,
            )
        case .text:
            // Add text drawing if needed
        }
    }

    if !self.hand_mode && self.selecting {
        current_mouse_x := f32(rl.GetMouseX())
        current_mouse_y := f32(rl.GetMouseY())

        rect_x := min(self.selector_start_x, current_mouse_x)
        rect_y := min(self.selector_start_y, current_mouse_y)
        rect_width := abs(current_mouse_x - self.selector_start_x)
        rect_height := abs(current_mouse_y - self.selector_start_y)

        rect := rl.Rectangle{
            x = rect_x,
            y = rect_y,
            width = rect_width,
            height = rect_height,
        }
        rl.DrawRectangleRec(rect, rl.Color{204, 112, 154, 128})
        rl.DrawRectangleLinesEx(rect, 1.0, rl.Color{204, 112, 154, 255})
    }

    if !self.hand_mode {
        selector_draw(self.selector^, self.items[:], self.x, self.y, self.scale)
    }

    cursor_draw(self.cursor, self.hand_mode, self.dragging)
}

canvas_draw_grid :: proc(self: ^canvas) {
    screen_width := f32(rl.GetScreenWidth())
    screen_height := f32(rl.GetScreenHeight())

    base_spacing: f32 = 3200.0
    grid_spacing := math.pow(base_spacing * self.scale, 0.5)

    adjusted_spacing := max(0, grid_spacing)
    grid_color := rl.Color{101, 156, 140, 255}
    offset_x := math.mod(self.x, adjusted_spacing)
    offset_y := math.mod(self.y, adjusted_spacing)
    extend_area := max(screen_width, screen_height)

    x := self.x - extend_area - offset_x
    for x < self.x + screen_width + extend_area {
        rl.DrawLineEx(
            rl.Vector2{x, self.y - extend_area},
            rl.Vector2{x, self.y + screen_height + extend_area},
            1.0,
            grid_color,
        )
        x += adjusted_spacing
    }

    y := self.y - extend_area - offset_y
    for y < self.y + screen_height + extend_area {
        rl.DrawLineEx(
            rl.Vector2{self.x - extend_area, y},
            rl.Vector2{self.x + screen_width + extend_area, y},
            1.0,
            grid_color,
        )
        y += adjusted_spacing
    }
}

main :: proc() {
    rl.SetConfigFlags({.WINDOW_RESIZABLE, .MSAA_4X_HINT})
    rl.InitWindow(1600, 900, "My First Game")
    rl.SetTargetFPS(144)
    rl.HideCursor()

    model_ctx, model_ok := init_onnx_model("models/rmbg.onnx")
    if !model_ok {
        fmt.println("Failed to initialize ONNX model")
        rl.CloseWindow()
        return
    }
    defer deinit_onnx_model(&model_ctx)

    c := canvas_init()
    defer canvas_deinit(&c)

    canvas_add_image(&c, "test/image.png", 100, 100)
    canvas_add_image(&c, "test/image2.png", 100, 100)

    for !rl.WindowShouldClose() {
        canvas_update(&c)
        
        rl.BeginDrawing()
        rl.ClearBackground(rl.Color{119, 209, 184, 255})
        canvas_draw(&c)
        rl.DrawFPS(10, 10)
        rl.EndDrawing()
    }

    rl.CloseWindow()
}