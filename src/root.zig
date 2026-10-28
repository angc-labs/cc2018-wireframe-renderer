pub const triangle = @import("triangle.zig");
pub const model = @import("model.zig");
pub const framebuffer = @import("framebuffer.zig");
pub const camera = @import("camera.zig");
pub const mat4 = @import("mat4.zig");

pub const Triangle2D = triangle.Triangle2D;
pub const Triangle3D = triangle.Triangle3D;
pub const TriangleFace = triangle.TriangleFace;
pub const Mesh = model.Mesh;
pub const loadOBJ = model.loadOBJ;
pub const Framebuffer = framebuffer.Framebuffer;
pub const Camera = camera.Camera;
pub const Mat4 = mat4.Mat4;
pub const Vec4 = mat4.Vec4;
