const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const PngError = error{
    InvalidSignature,
};

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

    // Check PNG signature
    const signature: u64 = std.mem.nativeToBig(u64, 0x89504E470D0A1A0A);
    if (!std.mem.eql(u8, try reader.peek(8), std.mem.asBytes(&signature))) return PngError.InvalidSignature;
    reader.take(8);

    return self;
}

pub fn deinit(self: *Self) void {
    self.gpa.destroy(self);
}
