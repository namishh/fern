const rl = @import("raylib");
const std = @import("std");
const Cursor = @import("cursor.zig").Cursor;

const ItemType = enum {
    Image,
};

const Image = struct {
    texture: rl.Texture2D,
    x: f32,
    y: f32,
    scale: f32 = 1.0,
};

const Item = union(ItemType) {
    Image: Image,

    pub fn deinit(self: *Item) void {
        switch (self.*) {
            .Image => |*img| rl.unloadTexture(img.texture),
        }
    }

    pub fn getBoundingBox(self: *Item) rl.Rectangle {
        const box = switch (self.*) {
            .Image => |img| rl.Rectangle{
                .x = img.x,
                .y = img.y,
                .width = @as(f32, @floatFromInt(img.texture.width)),
                .height = @as(f32, @floatFromInt(img.texture.height)),
            },
        };
        return box;
    }
};

const Selector = struct {
    selected_item: ?usize = null,
    handle_size: f32 = 8.0,
    rotation_line_length: f32 = 30.0,

    pub fn init() Selector {
        return Selector{};
    }

    pub fn draw(self: Selector, items: []const Item, canvas_x: f32, canvas_y: f32, canvas_scale: f32) void {
        if (self.selected_item) |idx| {
            if (idx >= items.len) {
                return;
            }
            var item = items[idx];
            const bounds = item.getBoundingBox();
            const adjusted_bounds = rl.Rectangle{
                .x = canvas_x + bounds.x * canvas_scale,
                .y = canvas_y + bounds.y * canvas_scale,
                .width = bounds.width * canvas_scale,
                .height = bounds.height * canvas_scale,
            };

            rl.drawRectangleLinesEx(adjusted_bounds, 1.0, rl.Color.blue);

            const half_handle = self.handle_size / 2.0;

            rl.drawRectangleRec(rl.Rectangle{ .x = adjusted_bounds.x - half_handle, .y = adjusted_bounds.y - half_handle, .width = self.handle_size, .height = self.handle_size }, rl.Color.white);
            rl.drawRectangleRec(rl.Rectangle{ .x = adjusted_bounds.x + adjusted_bounds.width - half_handle, .y = adjusted_bounds.y - half_handle, .width = self.handle_size, .height = self.handle_size }, rl.Color.white);
            rl.drawRectangleRec(rl.Rectangle{ .x = adjusted_bounds.x - half_handle, .y = adjusted_bounds.y + adjusted_bounds.height - half_handle, .width = self.handle_size, .height = self.handle_size }, rl.Color.white);
            rl.drawRectangleRec(rl.Rectangle{ .x = adjusted_bounds.x + adjusted_bounds.width - half_handle, .y = adjusted_bounds.y + adjusted_bounds.height - half_handle, .width = self.handle_size, .height = self.handle_size }, rl.Color.white);

            rl.drawRectangleRec(rl.Rectangle{ .x = adjusted_bounds.x + adjusted_bounds.width / 2.0 - half_handle, .y = adjusted_bounds.y - half_handle, .width = self.handle_size, .height = self.handle_size }, rl.Color.white);
            rl.drawRectangleRec(rl.Rectangle{ .x = adjusted_bounds.x + adjusted_bounds.width / 2.0 - half_handle, .y = adjusted_bounds.y + adjusted_bounds.height - half_handle, .width = self.handle_size, .height = self.handle_size }, rl.Color.white);
            rl.drawRectangleRec(rl.Rectangle{ .x = adjusted_bounds.x - half_handle, .y = adjusted_bounds.y + adjusted_bounds.height / 2.0 - half_handle, .width = self.handle_size, .height = self.handle_size }, rl.Color.white);
            rl.drawRectangleRec(rl.Rectangle{ .x = adjusted_bounds.x + adjusted_bounds.width - half_handle, .y = adjusted_bounds.y + adjusted_bounds.height / 2.0 - half_handle, .width = self.handle_size, .height = self.handle_size }, rl.Color.white);

            const top_center_x = adjusted_bounds.x + adjusted_bounds.width / 2.0;
            const top_center_y = adjusted_bounds.y;
            rl.drawLineEx(rl.Vector2{ .x = top_center_x, .y = top_center_y }, rl.Vector2{ .x = top_center_x, .y = top_center_y - self.rotation_line_length }, 1.0, rl.Color.blue);
            rl.drawCircleV(rl.Vector2{ .x = top_center_x, .y = top_center_y - self.rotation_line_length }, self.handle_size / 2.0, rl.Color.white);
        }
    }

    pub fn clearSelection(self: *Selector) void {
        self.selected_item = null;
    }
};

const Canvas = struct {
    items: std.ArrayList(Item),
    x: f32,
    y: f32,
    scale: f32 = 1.0,
    min_scale: f32 = 0.1,
    max_scale: f32 = 5.0,
    dragging: bool = false,
    dragging_item: bool = false,
    hand_mode: bool = false,
    initial_mouse_x: f32 = 0,
    initial_mouse_y: f32 = 0,
    initial_canvas_x: f32 = 0,
    initial_canvas_y: f32 = 0,
    initial_item_x: f32 = 0,
    initial_item_y: f32 = 0,
    select_start_x: f32 = 0,
    select_start_y: f32 = 0,
    selecting: bool = false,
    cursor: Cursor,
    selector: Selector = Selector.init(),
    grid_spacing: f32 = 50.0,

    pub fn init(allocator: std.mem.Allocator) !Canvas {
        const cursor = try Cursor.init();

        return Canvas{
            .items = std.ArrayList(Item).init(allocator),
            .x = 0,
            .y = 0,
            .cursor = cursor,
        };
    }

    pub fn deinit(self: *Canvas) void {
        for (self.items.items) |*item| {
            item.deinit();
        }
        self.items.deinit();
        self.cursor.deinit();
    }

    pub fn addImage(self: *Canvas, imagePath: [:0]const u8, x: f32, y: f32) !void {
        const image = try rl.loadImage(imagePath);
        defer rl.unloadImage(image);

        const texture = try rl.loadTextureFromImage(image);
        const new_image = Image{
            .texture = texture,
            .x = x,
            .y = y,
        };

        try self.items.append(Item{ .Image = new_image });
    }

    pub fn update(self: *Canvas) void {
        if (rl.isKeyPressed(.h)) {
            self.hand_mode = true;
            self.selecting = false;
            self.dragging = false;
            self.dragging_item = false;
            self.selector.clearSelection();
        } else if (rl.isKeyPressed(.v)) {
            self.hand_mode = false;
            self.dragging = false;
            self.dragging_item = false;
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
                if (self.selector.selected_item) |idx| {
                    var item = self.items.items[idx];
                    const bounds = item.getBoundingBox();
                    const adjusted_bounds = rl.Rectangle{
                        .x = self.x + bounds.x * self.scale,
                        .y = self.y + bounds.y * self.scale,
                        .width = bounds.width * self.scale,
                        .height = bounds.height * self.scale,
                    };
                    if (rl.checkCollisionPointRec(rl.Vector2{ .x = mouse_x, .y = mouse_y }, adjusted_bounds)) {
                        self.dragging_item = true;
                        self.initial_mouse_x = mouse_x;
                        self.initial_mouse_y = mouse_y;
                        self.initial_item_x = bounds.x;
                        self.initial_item_y = bounds.y;
                    }
                }

                if (!self.dragging_item) {
                    var found_item: ?usize = null;
                    for (self.items.items, 0..) |item, idx| {
                        var i = item;
                        const bounds = i.getBoundingBox();
                        const adjusted_bounds = rl.Rectangle{
                            .x = self.x + bounds.x * self.scale,
                            .y = self.y + bounds.y * self.scale,
                            .width = bounds.width * self.scale,
                            .height = bounds.height * self.scale,
                        };
                        if (rl.checkCollisionPointRec(rl.Vector2{ .x = mouse_x, .y = mouse_y }, adjusted_bounds)) {
                            found_item = idx;
                            break;
                        }
                    }
                    self.selector.selected_item = found_item;

                    if (found_item == null) {
                        self.selecting = true;
                        self.select_start_x = mouse_x;
                        self.select_start_y = mouse_y;
                    }
                }
            } else if (rl.isMouseButtonReleased(.left)) {
                self.selecting = false;
                self.dragging_item = false;
            }

            if (self.dragging_item) {
                if (self.selector.selected_item) |idx| {
                    const delta_x = (mouse_x - self.initial_mouse_x) / self.scale;
                    const delta_y = (mouse_y - self.initial_mouse_y) / self.scale;
                    switch (self.items.items[idx]) {
                        .Image => |*img| {
                            img.x = self.initial_item_x + delta_x;
                            img.y = self.initial_item_y + delta_y;
                        },
                    }
                }
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
        self.drawGrid();
        for (self.items.items) |item| {
            switch (item) {
                .Image => |img| {
                    const dest_rec = rl.Rectangle{
                        .x = self.x + img.x * self.scale,
                        .y = self.y + img.y * self.scale,
                        .width = @as(f32, @floatFromInt(img.texture.width)) * self.scale,
                        .height = @as(f32, @floatFromInt(img.texture.height)) * self.scale,
                    };

                    rl.drawTexturePro(img.texture, rl.Rectangle{
                        .x = 0,
                        .y = 0,
                        .width = @as(f32, @floatFromInt(img.texture.width)),
                        .height = @as(f32, @floatFromInt(img.texture.height)),
                    }, dest_rec, rl.Vector2{ .x = 0, .y = 0 }, 0, rl.Color.white);
                },
            }
        }

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

        if (!self.hand_mode) {
            self.selector.draw(self.items.items, self.x, self.y, self.scale);
        }

        self.cursor.draw(self.hand_mode, self.dragging);
    }

    fn drawGrid(self: Canvas) void {
        const screen_width = @as(f32, @floatFromInt(rl.getScreenWidth()));
        const screen_height = @as(f32, @floatFromInt(rl.getScreenHeight()));

        const base_spacing: f32 = 1400.0;
        const grid_spacing = std.math.pow(f32, base_spacing * self.scale, 0.5);

        const adjusted_spacing = @max(0, grid_spacing);

        const grid_color = rl.Color{ .r = 40, .g = 40, .b = 40, .a = 255 };
        const offset_x = @mod(self.x, adjusted_spacing);
        const offset_y = @mod(self.y, adjusted_spacing);

        const extend_area: f32 = @max(screen_width, screen_height);

        var x = self.x - extend_area - offset_x;
        while (x < self.x + screen_width + extend_area) : (x += adjusted_spacing) {
            rl.drawLineEx(rl.Vector2{ .x = x, .y = self.y - extend_area }, rl.Vector2{ .x = x, .y = self.y + screen_height + extend_area }, 1.0, grid_color);
        }

        var y = self.y - extend_area - offset_y;
        while (y < self.y + screen_height + extend_area) : (y += adjusted_spacing) {
            rl.drawLineEx(rl.Vector2{ .x = self.x - extend_area, .y = y }, rl.Vector2{ .x = self.x + screen_width + extend_area, .y = y }, 1.0, grid_color);
        }
    }
};

pub fn main() anyerror!void {
    const screenWidth = 1600;
    const screenHeight = 900;

    rl.setConfigFlags(.{ .window_resizable = true });
    rl.initWindow(screenWidth, screenHeight, "sakura");
    defer rl.closeWindow();
    rl.setTargetFPS(60);
    rl.setGesturesEnabled(.pinch_out);
    rl.setGesturesEnabled(.pinch_in);
    rl.hideCursor();

    const allocator = std.heap.page_allocator;
    var canvas = try Canvas.init(allocator);
    defer canvas.deinit();

    try canvas.addImage("test/image.png", 100, 100);
    try canvas.addImage("test/image2.png", 180, 180);

    while (!rl.windowShouldClose()) {
        canvas.update();

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color{ .a = 255, .r = 119, .g = 209, .b = 184 });
        canvas.draw();
    }
}
