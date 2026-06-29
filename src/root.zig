const std = @import("std");
// Cuz zig is an asshole in terms of file i/o
extern fn ks_log(fmt: [*:0]const u8, ...) void;

const HMODULE = *anyopaque;
extern "kernel32" fn LoadLibraryW(
    lpLibFileName: [*:0]const u16,
) callconv(.winapi) ?HMODULE;

extern "kernel32" fn GetProcAddress(
    hModule: HMODULE,
    lpProcName: [*:0]const u8,
) callconv(.winapi) ?*anyopaque;

extern "kernel32" fn FreeLibrary(
    hModule: HMODULE,
) callconv(.winapi) i32;
const u8to16 = std.unicode.utf8ToUtf16LeStringLiteral;

const exports: []const u8 = @embedFile("exports.txt");

const export_names = blk: {
    @setEvalBranchQuota(500000);

    var count: usize = 0;
    var iter = std.mem.splitScalar(u8, exports, '\n');

    while (iter.next()) |line| {
        if (std.mem.trim(u8, line, "\r").len != 0)
            count += 1;
    }

    var arr: [count][]const u8 = undefined;

    iter = std.mem.splitScalar(u8, exports, '\n');

    var i: usize = 0;
    while (iter.next()) |line| {
        const trimmed = std.mem.trim(u8, line, "\r");
        if (trimmed.len == 0) continue;

        arr[i] = trimmed;
        i += 1;
    }

    break :blk arr;
};

const stage1_dll: [*:0]const u16 = u8to16("killswitch/killswitch.dll");
const stage2_dll: [*:0]const u16 = u8to16("steam_o.dll");
var real_addresses: [export_names.len]*anyopaque = undefined;
var stage: u8 = 0;
var dll: ?HMODULE = null;

comptime {
    @setEvalBranchQuota(50000);
    for (export_names, 0..) |name, i| {
        if (std.mem.eql(u8, name, "SteamAPI_RestartAppIfNecessary")) {
            continue;
        }
        const exporter = struct {
            const id = i;
            pub fn proxy() callconv(.naked) void {
                asm volatile (
                    \\ jmp *%[target]
                    :
                    : [target] "r" (real_addresses[id]),
                );
            }
        };
        @export(&exporter.proxy, .{ .name = name, .linkage = .strong });
    }
}

fn c_string(buf: []u8, str: []const u8) [:0]u8 {
    @memcpy(buf[0..str.len], str);
    buf[str.len] = 0;
    return buf[0..str.len :0];
}

fn load_dll() void {
    var targetDll: [*:0]const u16 = stage1_dll;
    if (stage != 0) {
        _ = FreeLibrary(dll.?);
        dll = null;
        targetDll = stage2_dll;
    }
    ks_log("Loading DLL: %d", stage);
    dll = LoadLibraryW(targetDll) orelse {
        ks_log("DLL not found");
        @panic("nigga wut ?");
    };
    ks_log("Loaded!");
    @setEvalBranchQuota(500000);
    inline for (export_names, 0..) |name, id| {
        var buf: [name.len + 1:0]u8 = undefined;
        buf[name.len] = 0;
        real_addresses[id] =
            GetProcAddress(dll.?, c_string(&buf, name)) orelse {
                ks_log("failed to proc id: %d", id);
                @panic("FUCK");
            };
    }
}

pub export fn SteamAPI_RestartAppIfNecessary(appid: i32) bool {
    load_dll();
    ks_log("successfully loaded DLL and its exports");
    const real_fn_type =
        *const fn (i32) callconv(.c) bool;

    const real_fn_addr =
        GetProcAddress(dll.?, "SteamAPI_RestartAppIfNecessary") orelse {
            ks_log("RestartIfNecessary not found, likely problem with how the string is parsed ?");
            @panic("Wrong API structure ?");
        };
    ks_log("Loaded RestartIfNecessary");
    ks_log("AppID: %d", appid);
    const real_fn: real_fn_type = @ptrCast(real_fn_addr);
    ks_log("Casting to real function succeeded. Running the function");
    const ret = real_fn(appid);
    ks_log("Function returned value");
    stage += 1;
    return ret;
}
