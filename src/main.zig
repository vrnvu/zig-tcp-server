const std = @import("std");
const log = std.log;
const net = std.net;
const testing = std.testing;

const Connection = net.StreamServer.Connection;

pub const io_mode = .evented;

const Client = struct {
    conn: Connection,
    handle: @Frame(Client.handle),

    pub fn init(conn: Connection) Client {
        return Client {
            .conn = conn,
            .handle = Client.handle,
        };
    }

    pub fn deinit(self: *Client) void {
        self.conn.stream.close();
    }

    pub fn handle() void {

    }
};

const Room = struct {
    active_connections: std.ArrayList(?Connection),

    pub fn init(allocator: std.mem.Allocator) Room {
        return Room{
            .active_connections= std.ArrayList(?Connection).init(allocator),
        };
    }
};

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const name = "127.0.0.1";
    const port = 8080;
    var stream_server = try listenStreamServer(name, port);
    defer stream_server.deinit();
  
    log.info("listening on {s}:{d}", .{ name, port });

    var room = Room.init(allocator); 

    var i: usize = 0;
    while (i < 3) : (i += 1) {
        const conn = try stream_server.accept();
        try room.active_connections.append(conn);
        // TODO
        _ = async handle(conn, &room);
    }

    // TODO
    log.err("maximum number of clients reached, disconnecting!", .{});
}

fn handle(conn: Connection, room: *Room) !void {
    var buf: [128]u8 = undefined;
    while (true) {
        log.info("reading on: {}", .{conn.address});
        const n = try conn.stream.reader().read(&buf);
        if (n == 0) {
            return;
        }

        const msg = buf[0..n];
        for (room.active_connections.items) |opt| {
            if (opt) |c| {
                try c.stream.writer().print("write: {s}\n", .{msg});
            }
        }
    }
}

fn listenStreamServer(name: []const u8, port :u16) !net.StreamServer {
    var stream_server = net.StreamServer.init(.{});

    const address = try net.Address.resolveIp(name, port);
    try stream_server.listen(address);

    return stream_server;
}

test "tcp connections" {
    const name = "127.0.0.1";
    const port = 8080;

    var server = try listenStreamServer(name, port);
    const expected = server.listen_address.getPort();
    try testing.expect(expected == port);

    var client1 = try listenStreamServer(name, 10001);
    var client2 = try listenStreamServer(name, 10002);
    try testing.expect(client1.listen_address.getPort() == 10001);
    try testing.expect(client2.listen_address.getPort() == 10002);

}

var workers_counter: usize = 0;
test "workers" {
    var threads: std.ArrayList(std.Thread) = std.ArrayList(std.Thread).init(testing.allocator);
    defer threads.deinit();

    try testing.expect(workers_counter == 0);

    var i: usize = 0; 
    while (i < 3) : (i += 1) {
        try threads.append(try std.Thread.spawn(.{}, worker, .{}));
    }

    for (threads.items) |thread| {
        thread.join();
    }

}

fn worker() void {
    workers_counter += 1;
}