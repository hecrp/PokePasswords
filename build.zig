const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zigimg_dep = b.dependency("zigimg", .{
        .target = target,
        .optimize = optimize,
    });

    const entropy_mod = b.addModule("entropy", .{
        .root_source_file = b.path("src/entropy.zig"),
        .target = target,
        .optimize = optimize,
    });

    const password_mod = b.addModule("password", .{
        .root_source_file = b.path("src/password.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("zigimg", zigimg_dep.module("zigimg"));
    exe_mod.addImport("entropy", entropy_mod);
    exe_mod.addImport("password", password_mod);

    const exe = b.addExecutable(.{
        .name = "pokepasswords",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const entropy_tests = b.addTest(.{
        .root_module = entropy_mod,
    });
    const password_tests = b.addTest(.{
        .root_module = password_mod,
    });

    const security_mod = b.createModule(.{
        .root_source_file = b.path("test/security.zig"),
        .target = target,
        .optimize = optimize,
    });
    security_mod.addImport("entropy", entropy_mod);
    security_mod.addImport("password", password_mod);

    const security_tests = b.addTest(.{
        .root_module = security_mod,
    });

    const run_entropy_tests = b.addRunArtifact(entropy_tests);
    const run_password_tests = b.addRunArtifact(password_tests);
    const run_security_tests = b.addRunArtifact(security_tests);

    const test_step = b.step("test", "Run unit and security tests");
    test_step.dependOn(&run_entropy_tests.step);
    test_step.dependOn(&run_password_tests.step);
    test_step.dependOn(&run_security_tests.step);
}
