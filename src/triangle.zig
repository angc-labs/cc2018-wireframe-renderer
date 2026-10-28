const rl = @import("raylib");

pub const Triangle2D = struct {
    a: rl.Vector2,
    b: rl.Vector2,
    c: rl.Vector2,
};

pub const Triangle3D = struct {
    v0: rl.Vector3,
    v1: rl.Vector3,
    v2: rl.Vector3,

    pub fn normal(self: Triangle3D) rl.Vector3 {
        const edge1 = self.v1.subtract(self.v0);
        const edge2 = self.v2.subtract(self.v0);
        return edge1.crossProduct(edge2).normalize();
    }

    pub fn center(self: Triangle3D) rl.Vector3 {
        return .{
            .x = (self.v0.x + self.v1.x + self.v2.x) / 3.0,
            .y = (self.v0.y + self.v1.y + self.v2.y) / 3.0,
            .z = (self.v0.z + self.v1.z + self.v2.z) / 3.0,
        };
    }
};

pub const TriangleFace = struct {
    v0: usize,
    v1: usize,
    v2: usize,
};

// doble del area con signo en 2d (de c2018-triangulo-baricentrico)
pub fn edgeFunction2D(p1: rl.Vector2, p2: rl.Vector2, p3: rl.Vector2) f32 {
    return (p2.x - p1.x) * (p3.y - p1.y) - (p2.y - p1.y) * (p3.x - p1.x);
}

// centro de un triangulo 2d
pub fn triangleCenter2D(tri: Triangle2D) rl.Vector2 {
    return .{
        .x = (tri.a.x + tri.b.x + tri.c.x) / 3.0,
        .y = (tri.a.y + tri.b.y + tri.c.y) / 3.0,
    };
}
