const std = @import("std");
const rl = @import("raylib");
const model = @import("model.zig");
const camera = @import("camera.zig");
const framebuffer = @import("framebuffer.zig");
const triangle = @import("triangle.zig");
const mat4 = @import("mat4.zig");
const Mat4 = mat4.Mat4;

pub fn main() !void {
    const screenWidth: i32 = 800;
    const screenHeight: i32 = 800;

    const allocator = std.heap.page_allocator;

    // RUTA AL MODELO
    const default_path: [:0]const u8 = "assets/cohete.obj";
    const alt_path: [:0]const u8 = "RUTA ABSOLUTA LOCAL";

    var obj_path: [:0]const u8 = default_path;

    // inicializar ventana de raylib
    rl.initWindow(screenWidth, screenHeight, "CC2018 - Cohete");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    // cargar el modelo obj
    var mesh = model.loadOBJ(allocator, obj_path) catch |err| blk: {
        std.debug.print("No se pudo cargar desde {s} ({any}), intentando ruta alterna {s}...\n", .{ obj_path, err, alt_path });
        obj_path = alt_path;
        break :blk try model.loadOBJ(allocator, obj_path);
    };
    defer mesh.deinit();

    std.debug.print("Modelo cargado exitosamente:\n", .{});
    std.debug.print("  Vertices:   {d}\n", .{mesh.vertices.len});
    std.debug.print("  Triangulos: {d}\n", .{mesh.triangles.len});
    std.debug.print("  Centro:     ({d:.2}, {d:.2}, {d:.2})\n", .{ mesh.center.x, mesh.center.y, mesh.center.z });
    std.debug.print("  Radio:      {d:.2}\n", .{mesh.radius});

    // inicializar framebuffer con fondo negro y lineas blancas (algoritmo bresenham)
    var fb = framebuffer.Framebuffer.init(screenWidth, screenHeight, rl.Color.black, rl.Color.white);
    defer fb.deinit();

    // inicializar camara orbital alrededor del centro del modelo
    const initial_target = mesh.center;
    const initial_distance = @max(3.5, mesh.radius * 2.2);
    const initial_yaw: f32 = 35.0;
    const initial_pitch: f32 = 18.0;

    var cam = camera.Camera.init(initial_target, initial_distance, initial_yaw, initial_pitch, 55.0);

    var prev_mouse = rl.getMousePosition();

    // paleta de colores para el wireframe
    const colors = [_]rl.Color{
        rl.Color.white,
        rl.Color.green,
        rl.Color.sky_blue,
        rl.Color.yellow,
        rl.Color.lime,
        rl.Color.orange,
    };
    var color_index: usize = 0;

    while (!rl.windowShouldClose()) {
        const mouse = rl.getMousePosition();
        const delta_x = mouse.x - prev_mouse.x;
        const delta_y = mouse.y - prev_mouse.y;
        prev_mouse = mouse;

        // controles de camara con raton
        // clic izquierdo: orbitar
        if (rl.isMouseButtonDown(.left)) {
            const rot_speed: f32 = 0.006;
            cam.orbit(-delta_x * rot_speed, -delta_y * rot_speed);
        }

        // clic derecho: paneo (desplazar objetivo)
        if (rl.isMouseButtonDown(.right)) {
            cam.pan(delta_x, delta_y);
        }

        // rueda del raton: acercar/alejar (zoom)
        const wheel = rl.getMouseWheelMove();
        if (wheel != 0.0) {
            cam.zoom(-wheel * 0.35);
        }

        // controles de teclado
        if (rl.isKeyPressed(.r)) {
            cam.target = initial_target;
            cam.distance = initial_distance;
            cam.yaw = initial_yaw * (std.math.pi / 180.0);
            cam.pitch = initial_pitch * (std.math.pi / 180.0);
            cam.updateVectors();
        }

        if (rl.isKeyPressed(.c)) {
            color_index = (color_index + 1) % colors.len;
        }

        // limpiar el framebuffer con el color de fondo
        fb.clear();

        // pipeline de matrices world, view y projection segun codinglabs
        const screen_w_f: f32 = @floatFromInt(screenWidth);
        const screen_h_f: f32 = @floatFromInt(screenHeight);
        const aspect = screen_w_f / screen_h_f;

        // 1. model matrix (identidad, el modelo ya esta ubicado en su centro)
        const model_mat = Mat4.identity();

        // 2. view matrix (lookat desde la posicion de la camara hacia el objetivo)
        const view_mat = cam.getViewMatrix();

        // 3. projection matrix (proyeccion perspectiva con fov y relacion de aspecto)
        const proj_mat = cam.getProjectionMatrix(aspect);

        // multiplicacion unificada: mvp = projection * view * model
        const view_model = Mat4.multiply(view_mat, model_mat);
        const mvp = Mat4.multiply(proj_mat, view_model);

        const wire_color = colors[color_index];

        // renderizar las aristas de los triangulos proyectados con bresenham
        for (0..mesh.triangles.len) |i| {
            const tri3d = mesh.getTriangle(i);
            if (camera.projectTriangleWithMVP(mvp, tri3d, screen_w_f, screen_h_f)) |tri2d| {
                fb.draw_triangle_wireframe(tri2d, wire_color);
            }
        }

        // comenzar dibujo en pantalla
        rl.beginDrawing();

        // transferir la imagen del framebuffer al gpu y dibujarla en 2d
        try fb.swap();

        rl.endDrawing();
    }
}
