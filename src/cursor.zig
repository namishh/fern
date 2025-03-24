const rl = @import("raylib");

pub const Cursor = struct {
    normal: rl.Texture2D,
    hand_released: rl.Texture2D,
    hand_grabbing: rl.Texture2D,

    pub fn init() !Cursor {
        const normal_img = try rl.loadImage("assets/cursors/normal.png");
        defer rl.unloadImage(normal_img);
        const hand_released_img = try rl.loadImage("assets/cursors/hand_released.png");
        defer rl.unloadImage(hand_released_img);
        const hand_grabbing_img = try rl.loadImage("assets/cursors/hand_grabbing.png");
        defer rl.unloadImage(hand_grabbing_img);

        return Cursor{
            .normal = try rl.loadTextureFromImage(normal_img),
            .hand_released = try rl.loadTextureFromImage(hand_released_img),
            .hand_grabbing = try rl.loadTextureFromImage(hand_grabbing_img),
        };
    }

    pub fn deinit(self: *Cursor) void {
        rl.unloadTexture(self.normal);
        rl.unloadTexture(self.hand_released);
        rl.unloadTexture(self.hand_grabbing);
    }

    pub fn draw(self: Cursor, hand_mode: bool, dragging: bool) void {
        const mouse_x = @as(f32, @floatFromInt(rl.getMouseX()));
        const mouse_y = @as(f32, @floatFromInt(rl.getMouseY()));
        const texture = if (hand_mode) (if (dragging) self.hand_grabbing else self.hand_released) else self.normal;

        rl.drawTexturePro(texture, rl.Rectangle{ .x = 0, .y = 0, .width = @floatFromInt(texture.width), .height = @floatFromInt(texture.height) }, rl.Rectangle{ .x = mouse_x, .y = mouse_y, .width = @floatFromInt(texture.width), .height = @floatFromInt(texture.height) }, rl.Vector2{ .x = 0, .y = 0 }, 0, rl.Color.white);
    }
};
