const std = @import("std");
const rl = @import("raylib");
const triangle_mod = @import("triangle.zig");
const mat4_mod = @import("mat4.zig");
pub const Triangle2D = triangle_mod.Triangle2D;
pub const Triangle3D = triangle_mod.Triangle3D;
pub const Mat4 = mat4_mod.Mat4;

pub const Camera = struct {
    target: rl.Vector3,
    distance: f32,
    yaw: f32, // en radianes
    pitch: f32, // en radianes
    fov: f32, // campo de vision en radianes

    position: rl.Vector3,
    forward: rl.Vector3,
    right: rl.Vector3,
    up: rl.Vector3,

    pub fn init(target: rl.Vector3, distance: f32, yaw_deg: f32, pitch_deg: f32, fov_deg: f32) Camera {
        var cam = Camera{
            .target = target,
            .distance = distance,
            .yaw = yaw_deg * (std.math.pi / 180.0),
            .pitch = pitch_deg * (std.math.pi / 180.0),
            .fov = fov_deg * (std.math.pi / 180.0),
            .position = .zero(),
            .forward = .zero(),
            .right = .zero(),
            .up = .zero(),
        };
        cam.updateVectors();
        return cam;
    }

    pub fn updateVectors(self: *Camera) void {
        const cos_p = @cos(self.pitch);
        const sin_p = @sin(self.pitch);
        const cos_y = @cos(self.yaw);
        const sin_y = @sin(self.yaw);

        self.position = .{
            .x = self.target.x + self.distance * cos_p * sin_y,
            .y = self.target.y + self.distance * sin_p,
            .z = self.target.z + self.distance * cos_p * cos_y,
        };

        self.forward = self.target.subtract(self.position).normalize();

        const world_up = rl.Vector3{ .x = 0, .y = 1, .z = 0 };
        const dot = @abs(self.forward.dotProduct(world_up));
        const up_ref = if (dot > 0.99) rl.Vector3{ .x = 0, .y = 0, .z = -1 } else world_up;

        self.right = self.forward.crossProduct(up_ref).normalize();
        self.up = self.right.crossProduct(self.forward).normalize();
    }

    pub fn orbit(self: *Camera, delta_yaw: f32, delta_pitch: f32) void {
        self.yaw += delta_yaw;
        // normalizar yaw a [-pi, pi]
        while (self.yaw > std.math.pi) self.yaw -= 2.0 * std.math.pi;
        while (self.yaw < -std.math.pi) self.yaw += 2.0 * std.math.pi;

        self.pitch += delta_pitch;
        // limitar pitch para evitar bloqueo cardanico (gimbal lock)
        const max_pitch = 88.0 * (std.math.pi / 180.0);
        self.pitch = std.math.clamp(self.pitch, -max_pitch, max_pitch);

        self.updateVectors();
    }

    pub fn zoom(self: *Camera, delta: f32) void {
        self.distance += delta;
        if (self.distance < 0.5) self.distance = 0.5;
        if (self.distance > 100.0) self.distance = 100.0;
        self.updateVectors();
    }

    pub fn pan(self: *Camera, dx: f32, dy: f32) void {
        const pan_speed = self.distance * 0.002;
        const right_offset = self.right.scale(-dx * pan_speed);
        const up_offset = self.up.scale(dy * pan_speed);
        self.target = self.target.add(right_offset).add(up_offset);
        self.updateVectors();
    }

    // genera la matriz de vista (view matrix) con lookat
    pub fn getViewMatrix(self: *const Camera) Mat4 {
        const world_up = rl.Vector3{ .x = 0, .y = 1, .z = 0 };
        const dot = @abs(self.forward.dotProduct(world_up));
        const up_ref = if (dot > 0.99) rl.Vector3{ .x = 0, .y = 0, .z = -1 } else world_up;
        return Mat4.lookAt(self.position, self.target, up_ref);
    }

    // genera la matriz de proyeccion perspectiva
    pub fn getProjectionMatrix(self: *const Camera, aspect: f32) Mat4 {
        return Mat4.perspective(self.fov, aspect, 0.1, 100.0);
    }

    // proyecta un vertice 3d a coordenadas 2d de pantalla usando la matriz mvp
    pub fn projectPoint(self: *const Camera, mvp: Mat4, point: rl.Vector3, screen_w: f32, screen_h: f32) ?rl.Vector2 {
        _ = self;
        return projectPointWithMVP(mvp, point, screen_w, screen_h);
    }

    // proyecta un triangulo 3d a coordenadas 2d usando la matriz mvp
    pub fn projectTriangle(self: *const Camera, mvp: Mat4, tri: Triangle3D, screen_w: f32, screen_h: f32) ?Triangle2D {
        _ = self;
        return projectTriangleWithMVP(mvp, tri, screen_w, screen_h);
    }
};

// proyecta un vertice 3d a coordenadas 2d de pantalla usando la matriz mvp
pub fn projectPointWithMVP(mvp: Mat4, point: rl.Vector3, screen_w: f32, screen_h: f32) ?rl.Vector2 {
    const clip = mvp.transformPoint(point);

    // plano de corte cercano (near clipping plane)
    if (clip.w <= 0.05) return null;

    // division de perspectiva para obtener coordenadas normalizadas (ndc)
    const inv_w = 1.0 / clip.w;
    const ndc_x = clip.x * inv_w;
    const ndc_y = clip.y * inv_w;

    // transformacion a coordenadas de pantalla (viewport transform)
    return rl.Vector2{
        .x = (ndc_x + 1.0) * 0.5 * screen_w,
        .y = (1.0 - ndc_y) * 0.5 * screen_h,
    };
}

// proyecta un triangulo 3d a coordenadas 2d usando la matriz mvp
pub fn projectTriangleWithMVP(mvp: Mat4, tri: Triangle3D, screen_w: f32, screen_h: f32) ?Triangle2D {
    const p0 = projectPointWithMVP(mvp, tri.v0, screen_w, screen_h) orelse return null;
    const p1 = projectPointWithMVP(mvp, tri.v1, screen_w, screen_h) orelse return null;
    const p2 = projectPointWithMVP(mvp, tri.v2, screen_w, screen_h) orelse return null;

    return Triangle2D{
        .a = p0,
        .b = p1,
        .c = p2,
    };
}
