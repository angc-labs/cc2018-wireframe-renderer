const rl = @import("raylib");
const triangle_mod = @import("triangle.zig");
pub const Triangle2D = triangle_mod.Triangle2D;

pub const Framebuffer = struct {
    width: i32,
    height: i32,
    image: rl.Image,
    texture: ?rl.Texture = null,
    background_color: rl.Color,
    current_color: rl.Color,

    pub fn init(width: i32, height: i32, background_color: ?rl.Color, draw_color: ?rl.Color) Framebuffer {
        const bg = background_color orelse rl.Color.black;
        const fg = draw_color orelse rl.Color.white;
        return .{
            .width = width,
            .height = height,
            .image = rl.genImageColor(width, height, bg),
            .texture = null,
            .background_color = bg,
            .current_color = fg,
        };
    }

    pub fn deinit(self: *Framebuffer) void {
        if (self.texture) |texture| {
            rl.unloadTexture(texture);
            self.texture = null;
        }
        self.image.unload();
    }

    pub fn clear(self: *Framebuffer) void {
        self.image.clearBackground(self.background_color);
        if (self.texture) |texture| {
            rl.unloadTexture(texture);
            self.texture = null;
        }
    }

    pub fn set_pixel(self: *Framebuffer, x: i32, y: i32, color: rl.Color) void {
        if (x >= 0 and x < self.width and y >= 0 and y < self.height) {
            self.image.drawPixel(x, y, color);
        }
    }

    // algoritmo de lineas de bresenham (del primer laboratorio)
    pub fn draw_line(self: *Framebuffer, p0: rl.Vector2, p1: rl.Vector2, color: rl.Color) void {
        var x0: i32 = @intFromFloat(p0.x);
        var y0: i32 = @intFromFloat(p0.y);
        const x1: i32 = @intFromFloat(p1.x);
        const y1: i32 = @intFromFloat(p1.y);

        // descarte rapido si ambos extremos estan completamente fuera del mismo borde
        if ((x0 < 0 and x1 < 0) or (x0 >= self.width and x1 >= self.width) or
            (y0 < 0 and y1 < 0) or (y0 >= self.height and y1 >= self.height))
        {
            return;
        }

        const dx: i32 = @intCast(@abs(x1 - x0));
        const dy: i32 = -@as(i32, @intCast(@abs(y1 - y0)));
        const sx: i32 = if (x0 < x1) 1 else -1;
        const sy: i32 = if (y0 < y1) 1 else -1;
        var err = dx + dy;

        while (true) {
            if (x0 >= 0 and x0 < self.width and y0 >= 0 and y0 < self.height) {
                self.image.drawPixel(x0, y0, color);
            }
            if (x0 == x1 and y0 == y1) break;
            const e2 = 2 * err;
            if (e2 >= dy) {
                err += dy;
                x0 += sx;
            }
            if (e2 <= dx) {
                err += dx;
                y0 += sy;
            }
        }
    }

    pub fn draw_triangle_wireframe(self: *Framebuffer, tri: Triangle2D, color: rl.Color) void {
        self.draw_line(tri.a, tri.b, color);
        self.draw_line(tri.b, tri.c, color);
        self.draw_line(tri.c, tri.a, color);
    }

    pub fn swap(self: *Framebuffer) !void {
        const texture = try rl.loadTextureFromImage(self.image);
        self.texture = texture;
        rl.drawTexture(texture, 0, 0, .white);
    }
};
