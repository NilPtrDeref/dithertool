const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const PngError = error{
    InvalidSignature,
};

const PngSignature: u64 = 0x89504E470D0A1A0A;
const ChunkType = enum(u32) {
    IHDR = 0x49484452,
    PLTE = 0x504C5445,
    IDAT = 0x49444154,
    IEND = 0x49454E44,
    tRNS = 0x74524E53,
    cHRM = 0x6348524D,
    gAMA = 0x67414D41,
    iCCP = 0x69434350,
    sBIT = 0x73424954,
    sRGB = 0x73524742,
    cICP = 0x63494350,
    MDCV = 0x6D444356,
    cLLI = 0x634C4C49,
    tEXt = 0x74455874,
    zTXt = 0x7A545874,
    iTXt = 0x69545874,
    bKGD = 0x624B4744,
    caBX = 0x63614258,
    hIST = 0x68495354,
    pHYs = 0x70485973,
    sPLT = 0x73504C54,
    eXIf = 0x65584966,
    tIME = 0x74494D45,
    acTL = 0x6163544C,
    fcTL = 0x6663544C,
    fdAT = 0x66644154,
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
    if (!(PngSignature == try reader.peekInt(u64, .big))) return PngError.InvalidSignature;
    _ = try reader.takeInt(u64, .big);

    // TODO: Read chunks
    while (true) {
        const chunklen = reader.takeInt(u32, .big) catch |e| {
            switch (e) {
                error.EndOfStream => break,
                else => return e,
            }
        };

        const chunktype: ChunkType = @enumFromInt(try reader.takeInt(u32, .big));
        _ = chunktype;

        _ = try reader.discard(.limited(chunklen));

        const crc = try reader.takeInt(u32, .big);
        _ = crc;
    }

    return self;
}

pub fn deinit(self: *Self) void {
    self.gpa.destroy(self);
}
