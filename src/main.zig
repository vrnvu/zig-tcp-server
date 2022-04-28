const std = @import("std");
const log = std.log;
const net = std.net;
const Connection = net.StreamServer.Connection;

pub const io_mode = .evented;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var stream_server = net.StreamServer.init(.{});
    defer stream_server.deinit();

    const name = "127.0.0.1";
    const port = 8080;
    const address = try net.Address.resolveIp(name, port);

    try stream_server.listen(address);
    log.info("listening on {s}:{d}", .{ name, port });

    var active_connections = std.ArrayList(?Connection).init(allocator);

    var i: usize = 0;
    while (i < 3) : (i += 1) {
        const conn = try stream_server.accept();
        try active_connections.append(conn);
        // TODO
        _ = async handle(conn, active_connections);
    }

    // TODO
    log.err("maximum number of clients reached, disconnecting!", .{});
}

fn handle(conn: Connection, active_connections: std.ArrayList(?Connection)) !void {
    var buf: [128]u8 = undefined;
    while (true) {
        log.info("reading on: {}", .{conn.address});
        const n = try conn.stream.reader().read(&buf);
        if (n == 0) {
            return;
        }

        const msg = buf[0..n];
        for (active_connections.items) |opt| {
            if (opt) |c| {
                try c.stream.writer().print("write: {s}\n", .{msg});
            }
        }
    }
}
