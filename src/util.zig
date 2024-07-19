const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const List = std.ArrayList;
const Map = std.AutoHashMap;
const StrMap = std.StringHashMap;
const BitSet = std.DynamicBitSet;
const Str = []const u8;

var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
pub const gpa = if (builtin.is_test) testing.allocator else gpa_impl.allocator();

// Add utility functions here

// Useful stdlib functions
const tokenizeAny = std.mem.tokenizeAny;
const tokenizeSeq = std.mem.tokenizeSequence;
const tokenizeSca = std.mem.tokenizeScalar;
const splitAny = std.mem.splitAny;
const splitSeq = std.mem.splitSequence;
const splitSca = std.mem.splitScalar;
const indexOf = std.mem.indexOfScalar;
const indexOfAny = std.mem.indexOfAny;
const indexOfStr = std.mem.indexOfPosLinear;
const lastIndexOf = std.mem.lastIndexOfScalar;
const lastIndexOfAny = std.mem.lastIndexOfAny;
const lastIndexOfStr = std.mem.lastIndexOfLinear;
const trim = std.mem.trim;
const sliceMin = std.mem.min;
const sliceMax = std.mem.max;

const parseInt = std.fmt.parseInt;
const parseFloat = std.fmt.parseFloat;

const print = std.debug.print;
const assert = std.debug.assert;

const sort = std.sort.block;
const asc = std.sort.asc;
const desc = std.sort.desc;

pub const Client = struct {
    year: u16,
    day: u9,
    cookie: ?[]const u8 = null,
    http_client: std.http.Client,

    const IncorrectAnswser = "That's not the right answer.";
    const RetryLater = "You gave an answer too recently;";

    pub const Part = enum(u2) {
        part1 = 1,
        part2 = 2,
    };

    pub const Response = struct {
        buffer: []u8,
        allocator: std.mem.Allocator,

        pub fn deinit(self: *Response) void {
            self.allocator.free(self.buffer);
        }
    };

    pub fn deinit(self: *Client) void {
        self.http_client.allocator.free(self.cookie);
        self.http_client.deinit();
    }

    pub fn getInput(self: *Client) !Response {
        var buf: [1024]u8 = undefined;
        const path = try std.fmt.bufPrint(&buf, "src/data/day{d:0>2}.txt", .{self.day});
        var cache = std.fs.cwd().openFile(path, .{}) catch |err| switch (err) {
            error.FileNotFound => return try self.getInputOnline(),
            else => |e| return e,
        };
        return .{
            .allocator = self.http_client.allocator,
            .buffer = try cache.readToEndAlloc(self.http_client.allocator, 100 * 1024),
        };
    }

    pub fn getInputOnline(self: *Client) !Response {
        var buf: [1024]u8 = undefined;
        var response_storage = std.ArrayList(u8).init(self.http_client.allocator);
        defer response_storage.deinit();
        const url = try std.fmt.bufPrint(
            &buf,
            "https://adventofcode.com/{d}/day/{d}/input",
            .{ self.year, self.day },
        );
        const res = try self.http_client.fetch(.{
            .method = .GET,
            .extra_headers = &.{
                .{ .name = "Cookie", .value = try self.getCookie() },
            },
            .location = .{ .url = url },
            .response_storage = .{ .dynamic = &response_storage },
        });
        if (res.status != .ok) return error.StatusFailed;
        const path = try std.fmt.bufPrint(&buf, "src/data/day{d:0>2}.txt", .{self.day});
        var cache_file = try std.fs.cwd().createFile(path, .{});
        try cache_file.writeAll(response_storage.items);
        return .{
            .allocator = self.http_client.allocator,
            .buffer = try response_storage.toOwnedSlice(),
        };
    }

    pub const SubmitAnswerOptions = struct {
        part: Part,
        anwser: usize,
    };

    pub fn submitAnswer(self: *Client, options: SubmitAnswerOptions) !void {
        var buf: [1024]u8 = undefined;
        var response_storage = std.ArrayList(u8).init(self.http_client.allocator);
        defer response_storage.deinit();
        const url = try std.fmt.bufPrint(
            &buf,
            "https://adventofcode.com/{d}/day/{d}/answer",
            .{ self.year, self.day },
        );
        const res = try self.http_client.fetch(.{
            .method = .POST,
            .headers = .{
                .content_type = .{ .override = "application/x-www-form-urlencoded" },
            },
            .extra_headers = &.{
                .{ .name = "Cookie", .value = try self.getCookie() },
            },
            .payload = try std.fmt.bufPrint(
                buf[url.len..],
                "level={d}&answer={d}",
                .{ @intFromEnum(options.part), options.anwser },
            ),
            .location = .{ .url = url },
            .response_storage = .{ .dynamic = &response_storage },
        });
        if (res.status != .ok) return error.StatusFailed;
        if (std.mem.containsAtLeast(u8, response_storage.items, 1, RetryLater)) {
            return error.RetryLater;
        }
        if (std.mem.containsAtLeast(u8, response_storage.items, 1, IncorrectAnswser)) {
            return error.IncorrectAnswser;
        }
    }

    fn getCookie(self: *Client) ![]const u8 {
        const allocator = self.http_client.allocator;
        if (self.cookie == null) {
            const session = std.posix.getenv("SESSION") orelse return error.NoSession;
            self.cookie = try std.fmt.allocPrint(allocator, "session={s}", .{session});
        }
        return self.cookie.?;
    }
};
