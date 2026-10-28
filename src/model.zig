const std = @import("std");
const rl = @import("raylib");
const triangle_mod = @import("triangle.zig");
pub const TriangleFace = triangle_mod.TriangleFace;
pub const Triangle3D = triangle_mod.Triangle3D;

pub const Mesh = struct {
    vertices: []rl.Vector3,
    triangles: []TriangleFace,
    min_bound: rl.Vector3,
    max_bound: rl.Vector3,
    center: rl.Vector3,
    radius: f32,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Mesh) void {
        self.allocator.free(self.vertices);
        self.allocator.free(self.triangles);
    }

    pub fn getTriangle(self: *const Mesh, index: usize) Triangle3D {
        const face = self.triangles[index];
        return Triangle3D{
            .v0 = self.vertices[face.v0],
            .v1 = self.vertices[face.v1],
            .v2 = self.vertices[face.v2],
        };
    }
};

pub fn loadOBJ(allocator: std.mem.Allocator, path: [:0]const u8) !Mesh {
    const raw_text = rl.loadFileText(path);
    if (raw_text.len == 0) {
        return error.FileNotFoundOrEmpty;
    }
    defer rl.unloadFileText(raw_text);

    var vertices: std.ArrayList(rl.Vector3) = .empty;
    defer vertices.deinit(allocator);

    var triangles: std.ArrayList(TriangleFace) = .empty;
    defer triangles.deinit(allocator);

    var min_x: f32 = std.math.inf(f32);
    var min_y: f32 = std.math.inf(f32);
    var min_z: f32 = std.math.inf(f32);
    var max_x: f32 = -std.math.inf(f32);
    var max_y: f32 = -std.math.inf(f32);
    var max_z: f32 = -std.math.inf(f32);

    var face_vertex_indices: std.ArrayList(usize) = .empty;
    defer face_vertex_indices.deinit(allocator);

    var line_it = std.mem.splitScalar(u8, raw_text, '\n');
    while (line_it.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0 or line[0] == '#') {
            continue;
        }

        if (std.mem.startsWith(u8, line, "v ")) {
            var tok_it = std.mem.tokenizeAny(u8, line[2..], " \t");
            const x_str = tok_it.next() orelse continue;
            const y_str = tok_it.next() orelse continue;
            const z_str = tok_it.next() orelse continue;

            const x = std.fmt.parseFloat(f32, x_str) catch continue;
            const y = std.fmt.parseFloat(f32, y_str) catch continue;
            const z = std.fmt.parseFloat(f32, z_str) catch continue;

            try vertices.append(allocator, .{ .x = x, .y = y, .z = z });

            if (x < min_x) min_x = x;
            if (y < min_y) min_y = y;
            if (z < min_z) min_z = z;
            if (x > max_x) max_x = x;
            if (y > max_y) max_y = y;
            if (z > max_z) max_z = z;
        } else if (std.mem.startsWith(u8, line, "f ")) {
            face_vertex_indices.clearRetainingCapacity();
            var tok_it = std.mem.tokenizeAny(u8, line[2..], " \t");

            while (tok_it.next()) |token| {
                // el indice del vertice es la subcadena antes del primer '/'
                var slash_it = std.mem.splitScalar(u8, token, '/');
                const v_idx_str = slash_it.next() orelse continue;
                if (v_idx_str.len == 0) continue;

                const raw_idx = std.fmt.parseInt(i32, v_idx_str, 10) catch continue;
                const v_idx: usize = if (raw_idx > 0)
                    @intCast(raw_idx - 1)
                else if (raw_idx < 0)
                    @intCast(@as(i32, @intCast(vertices.items.len)) + raw_idx)
                else
                    continue;

                try face_vertex_indices.append(allocator, v_idx);
            }

            // triangular poligono usando abanico (fan triangulation)
            const n = face_vertex_indices.items.len;
            if (n >= 3) {
                var i: usize = 1;
                while (i + 1 < n) : (i += 1) {
                    try triangles.append(allocator, .{
                        .v0 = face_vertex_indices.items[0],
                        .v1 = face_vertex_indices.items[i],
                        .v2 = face_vertex_indices.items[i + 1],
                    });
                }
            }
        }
    }

    if (vertices.items.len == 0) {
        return error.NoVerticesFound;
    }

    const center = rl.Vector3{
        .x = (min_x + max_x) * 0.5,
        .y = (min_y + max_y) * 0.5,
        .z = (min_z + max_z) * 0.5,
    };

    var max_radius_sq: f32 = 0.0;
    for (vertices.items) |v| {
        const dx = v.x - center.x;
        const dy = v.y - center.y;
        const dz = v.z - center.z;
        const dist_sq = dx * dx + dy * dy + dz * dz;
        if (dist_sq > max_radius_sq) {
            max_radius_sq = dist_sq;
        }
    }

    const owned_vertices = try vertices.toOwnedSlice(allocator);
    const owned_triangles = try triangles.toOwnedSlice(allocator);

    return Mesh{
        .vertices = owned_vertices,
        .triangles = owned_triangles,
        .min_bound = .{ .x = min_x, .y = min_y, .z = min_z },
        .max_bound = .{ .x = max_x, .y = max_y, .z = max_z },
        .center = center,
        .radius = @sqrt(max_radius_sq),
        .allocator = allocator,
    };
}
