const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const PngError = error{
    InvalidSignature,
    InvalidChunkType,
    InvalidHeaderLength,
    InvalidColorType,
    InvalidBitDepth,
    InvalidCompressionMethod,
    InvalidFilterMethod,
    InvalidInterlaceMethod,
    InvalidPaletteSize,
    TooManyPalettes,
    MissingPalette,
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
    _,
};

const ColorType = enum(u8) {
    Greyscale = 0,
    Truecolor = 2,
    Indexed = 3,
    GreyscaleAlpha = 4,
    TruecolorAlpha = 6,
    _,
};

const InterlaceMethod = enum(u8) {
    None = 0,
    Adam7 = 1,
    _,
};

const RGB = struct {
    r: u8,
    g: u8,
    b: u8,
};

const Palette = std.ArrayList(RGB);

const Self = @This();
io: Io,
gpa: Allocator,
reader: *Io.Reader,
width: u32,
height: u32,
bitdepth: u8,
colortype: ColorType,
interlace: InterlaceMethod,
palette: ?Palette,

pub fn parse(io: Io, gpa: Allocator, reader: *Io.Reader) !*Self {
    var self = try gpa.create(Self);
    errdefer gpa.destroy(self);
    self.io = io;
    self.gpa = gpa;
    self.reader = reader;
    self.width = 0;
    self.height = 0;

    // Check PNG signature
    if (PngSignature != try reader.peekInt(u64, .big)) return PngError.InvalidSignature;
    _ = try reader.takeInt(u64, .big);

    while (true) {
        self.parse_chunk() catch |e| {
            switch (e) {
                error.EndOfStream => break,
                else => return e,
            }
        };
    }

    return self;
}

fn parse_chunk(self: *Self) !void {
    const chunklen = try self.reader.takeInt(u32, .big);
    const chunktype: ChunkType = @enumFromInt(try self.reader.takeInt(u32, .big));

    std.log.info("{any}", .{chunktype});
    switch (chunktype) {
        _ => return PngError.InvalidChunkType,
        .IHDR => {
            if (chunklen != 13) return PngError.InvalidHeaderLength;
            self.width = try self.reader.takeInt(u32, .big);
            self.height = try self.reader.takeInt(u32, .big);

            self.bitdepth = try self.reader.takeByte();
            self.colortype = @enumFromInt(try self.reader.takeByte());
            switch (self.colortype) {
                .Greyscale => switch (self.bitdepth) {
                    1, 2, 4, 8, 16 => {},
                    else => return PngError.InvalidBitDepth,
                },
                .Truecolor => switch (self.bitdepth) {
                    8, 16 => {},
                    else => return PngError.InvalidBitDepth,
                },
                .Indexed => switch (self.bitdepth) {
                    1, 2, 4, 8 => {},
                    else => return PngError.InvalidBitDepth,
                },
                .GreyscaleAlpha => switch (self.bitdepth) {
                    8, 16 => {},
                    else => return PngError.InvalidBitDepth,
                },
                .TruecolorAlpha => switch (self.bitdepth) {
                    8, 16 => {},
                    else => return PngError.InvalidBitDepth,
                },
                _ => return PngError.InvalidColorType,
            }

            if (try self.reader.takeByte() != 0) return PngError.InvalidCompressionMethod;
            if (try self.reader.takeByte() != 0) return PngError.InvalidFilterMethod;
            self.interlace = @enumFromInt(try self.reader.takeByte());
            switch (self.interlace) {
                _ => return PngError.InvalidInterlaceMethod,
                else => {},
            }

            _ = try self.reader.takeInt(u32, .big); // Discard CRC
        },
        .IEND => {
            _ = try self.reader.takeInt(u32, .big); // Discard CRC
        },
        .PLTE => {
            if (self.palette != null) return PngError.TooManyPalettes;
            const palettesize = chunklen / 3;
            switch (self.colortype) {
                .Indexed => {
                    if (palettesize > std.math.pow(u32, 2, self.bitdepth)) return PngError.InvalidPaletteSize;
                },
                .Truecolor, .TruecolorAlpha => {
                    if (palettesize > 256) return PngError.InvalidPaletteSize;
                },
                else => return PngError.TooManyPalettes,
            }
            if (chunklen == 0 or @mod(chunklen, 3) != 0) return PngError.InvalidPaletteSize;

            self.palette = try .initCapacity(self.gpa, palettesize);
            for (0..palettesize) |_| {
                self.palette.?.appendAssumeCapacity(.{
                    .r = try self.reader.takeByte(),
                    .g = try self.reader.takeByte(),
                    .b = try self.reader.takeByte(),
                });
            }
            _ = try self.reader.takeInt(u32, .big); // Discard CRC
        },
        .IDAT => {
            // TODO: Interpret data and create color buffer. Convert data to rgba buffer?
            unreachable;
        },
        else => {
            _ = try self.reader.discard(.limited(chunklen));
            _ = try self.reader.takeInt(u32, .big);
        },
    }

    if (self.colortype == .Indexed and self.palette == null) return PngError.MissingPalette;
}

pub fn deinit(self: *Self) void {
    self.gpa.destroy(self);
}
