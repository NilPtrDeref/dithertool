const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const Self = @This();
io: Io,
gpa: Allocator,
reader: *Io.Reader,
width: u32,
height: u32,

pub fn parse(io: Io, gpa: Allocator, reader: *Io.Reader) !*Self {
    var self = try gpa.create(Self);
    errdefer gpa.destroy(self);
    self.io = io;
    self.gpa = gpa;
    self.reader = reader;
    self.width = 0;
    self.height = 0;
    return self;
}

pub fn deinit(self: *Self) void {
    self.gpa.destroy(self);
}
