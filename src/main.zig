const rl = @import("raylib");
const std = @import("std");

const Canvas = struct {
    texture: rl.Texture2D,
    x: f32,
    y: f32,
    scale: f32 = 1.0,
    min_scale: f32 = 0.1,
    max_scale: f32 = 5.0,
    dragging: bool = false,
    hand_mode: bool = false,
    initial_mouse_x: f32 = 0,
    initial_mouse_y: f32 = 0,
    initial_canvas_x: f32 = 0,
    initial_canvas_y: f32 = 0,
    select_start_x: f32 = 0,
    select_start_y: f32 = 0,
    selecting: bool = false,

    pub fn init(screenWidth: i32, screenHeight: i32, imagePath: [:0]const u8) !Canvas {
        const image = try rl.loadImage(imagePath);
        defer rl.unloadImage(image);

        const texture = try rl.loadTextureFromImage(image);
        const x = @as(f32, @floatFromInt(@divTrunc((screenWidth - texture.width), 2)));
        const y = @as(f32, @floatFromInt(@divTrunc((screenHeight - texture.height), 2)));

        return Canvas{
            .texture = texture,
            .x = x,
            .y = y,
        };
    }

    pub fn deinit(self: *Canvas) void {
        rl.unloadTexture(self.texture);
    }

    pub fn update(self: *Canvas) void {
        if (rl.isKeyPressed(.h)) {
            self.hand_mode = true;
            self.selecting = false;
            self.dragging = false;
        } else if (rl.isKeyPressed(.v)) {
            self.hand_mode = false;
            self.dragging = false;
            self.selecting = false;
        }

        const mouse_x = @as(f32, @floatFromInt(rl.getMouseX()));
        const mouse_y = @as(f32, @floatFromInt(rl.getMouseY()));
        const ctrl_pressed = rl.isKeyDown(.left_control) or rl.isKeyDown(.right_control);

        const wheel_move = rl.getMouseWheelMove();
        if (ctrl_pressed and wheel_move != 0) {
            self.zoom(mouse_x, mouse_y, wheel_move * 0.2);
        }

        if (rl.isKeyDown(.left_control)) {
            if (rl.isKeyPressed(.kp_add) or rl.isKeyPressed(.equal)) {
                self.zoom(mouse_x, mouse_y, 0.5);
            }
            if (rl.isKeyPressed(.kp_subtract) or rl.isKeyPressed(.minus)) {
                self.zoom(mouse_x, mouse_y, -0.5);
            }
        }

        if (rl.getGestureDetected() == .pinch_in or rl.getGestureDetected() == .pinch_out) {
            const pinch = rl.getGesturePinchVector();
            self.zoom(mouse_x, mouse_y, pinch.x * 0.02);
        }

        if (self.hand_mode) {
            if (rl.isMouseButtonPressed(.left)) {
                self.dragging = true;
                self.initial_mouse_x = mouse_x;
                self.initial_mouse_y = mouse_y;
                self.initial_canvas_x = self.x;
                self.initial_canvas_y = self.y;
            } else if (rl.isMouseButtonReleased(.left)) {
                self.dragging = false;
            }

            if (self.dragging) {
                const delta_x = (mouse_x - self.initial_mouse_x) / self.scale;
                const delta_y = (mouse_y - self.initial_mouse_y) / self.scale;
                self.x = self.initial_canvas_x + delta_x;
                self.y = self.initial_canvas_y + delta_y;
            }
        } else {
            if (rl.isMouseButtonPressed(.left)) {
                self.selecting = true;
                self.select_start_x = mouse_x;
                self.select_start_y = mouse_y;
            } else if (rl.isMouseButtonReleased(.left)) {
                self.selecting = false;
            }
        }
    }

    fn zoom(self: *Canvas, mouse_x: f32, mouse_y: f32, delta: f32) void {
        const old_scale = self.scale;
        self.scale = std.math.clamp(self.scale + delta, self.min_scale, self.max_scale);

        const world_x = (mouse_x - self.x) / old_scale;
        const world_y = (mouse_y - self.y) / old_scale;
        self.x = mouse_x - (world_x * self.scale);
        self.y = mouse_y - (world_y * self.scale);
    }

    pub fn draw(self: Canvas) void {
        const dest_rec = rl.Rectangle{
            .x = self.x,
            .y = self.y,
            .width = @as(f32, @floatFromInt(self.texture.width)) * self.scale,
            .height = @as(f32, @floatFromInt(self.texture.height)) * self.scale,
        };

        rl.drawTexturePro(self.texture, rl.Rectangle{
            .x = 0,
            .y = 0,
            .width = @as(f32, @floatFromInt(self.texture.width)),
            .height = @as(f32, @floatFromInt(self.texture.height)),
        }, dest_rec, rl.Vector2{ .x = 0, .y = 0 }, 0, rl.Color.white);

        if (!self.hand_mode and self.selecting) {
            const current_mouse_x = @as(f32, @floatFromInt(rl.getMouseX()));
            const current_mouse_y = @as(f32, @floatFromInt(rl.getMouseY()));

            const rect_x = @min(self.select_start_x, current_mouse_x);
            const rect_y = @min(self.select_start_y, current_mouse_y);
            const rect_width = @abs(current_mouse_x - self.select_start_x);
            const rect_height = @abs(current_mouse_y - self.select_start_y);

            const rect = rl.Rectangle{
                .x = rect_x,
                .y = rect_y,
                .width = rect_width,
                .height = rect_height,
            };
            rl.drawRectangleRec(rect, rl.Color{ .r = 0, .g = 128, .b = 255, .a = 128 });
            rl.drawRectangleLinesEx(rect, 1.0, rl.Color.blue);
        }
    }
};

pub fn main() anyerror!void {
    const screenWidth = 800;
    const screenHeight = 600;

    rl.setConfigFlags(.{ .window_resizable = true });
    rl.initWindow(screenWidth, screenHeight, "sakura");
    defer rl.closeWindow();
    rl.setTargetFPS(60);
    rl.setGesturesEnabled(.pinch_out);
    rl.setGesturesEnabled(.pinch_in);

    var canvas = try Canvas.init(screenWidth, screenHeight, "test/image.png");
    defer canvas.deinit();

    while (!rl.windowShouldClose()) {
        canvas.update();

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.light_gray);
        canvas.draw();
    }
}
