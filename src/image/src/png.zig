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
    UnsupportedInterlaceMethod,
    InvalidInterlaceMethod,
    InvalidPaletteSize,
    InvalidCrc,
    InvalidChunkSequence,
    DuplicateHeader,
    DuplicatePalettes,
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

    var previous: ?ChunkType = null;
    var data: std.ArrayList(u8) = .empty;
    defer data.deinit(self.gpa);
    while (true) {
        previous = self.parse_chunk(previous, &data) catch |e| {
            switch (e) {
                error.EndOfStream => break,
                else => return e,
            }
        };
    }

    // TODO: Read data into pixel information and then store.
    var dreader: Io.Reader = .fixed(data.items);
    var buffer: [std.compress.flate.max_window_len]u8 = undefined;
    var decompressor = std.compress.flate.Decompress.init(&dreader, .zlib, &buffer);
    _ = try decompressor.reader.discardRemaining();

    if (self.colortype == .Indexed and self.palette == null) return PngError.MissingPalette;
    return self;
}

fn valid_crc(chunktype: ChunkType, data: []const u8, crc: u32) bool {
    var ecrc = std.hash.crc.Crc32.init();
    ecrc.update(std.mem.asBytes(&std.mem.nativeToBig(u32, @intFromEnum(chunktype))));
    ecrc.update(data);
    return crc == ecrc.final();
}

fn parse_chunk(self: *Self, previous: ?ChunkType, data: *std.ArrayList(u8)) !ChunkType {
    const chunklen = try self.reader.takeInt(u32, .big);
    const chunktype: ChunkType = @enumFromInt(try self.reader.takeInt(u32, .big));

    switch (chunktype) {
        _ => return PngError.InvalidChunkType,
        .IHDR => {
            if (previous != null) return PngError.DuplicateHeader;
            if (chunklen != 13) return PngError.InvalidHeaderLength;

            const chunk = try self.reader.readAlloc(self.gpa, chunklen);
            defer self.gpa.free(chunk);
            if (!valid_crc(.IHDR, chunk, try self.reader.takeInt(u32, .big))) return PngError.InvalidCrc;
            var reader: Io.Reader = .fixed(chunk);

            self.width = try reader.takeInt(u32, .big);
            self.height = try reader.takeInt(u32, .big);

            self.bitdepth = try reader.takeByte();
            self.colortype = @enumFromInt(try reader.takeByte());
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

            if (try reader.takeByte() != 0) return PngError.InvalidCompressionMethod;
            if (try reader.takeByte() != 0) return PngError.InvalidFilterMethod;
            self.interlace = @enumFromInt(try reader.takeByte());
            switch (self.interlace) {
                .Adam7 => return PngError.UnsupportedInterlaceMethod, // FIXME: Add support for this interlace method
                _ => return PngError.InvalidInterlaceMethod,
                else => {},
            }
        },
        .IEND => {
            if (!valid_crc(.IEND, &.{}, try self.reader.takeInt(u32, .big))) return PngError.InvalidCrc;
        },
        .PLTE => {
            if (self.palette != null) return PngError.DuplicatePalettes;
            const palettesize = chunklen / 3;
            switch (self.colortype) {
                .Indexed => {
                    if (palettesize > std.math.pow(u32, 2, self.bitdepth)) return PngError.InvalidPaletteSize;
                },
                .Truecolor, .TruecolorAlpha => {
                    if (palettesize > 256) return PngError.InvalidPaletteSize;
                },
                else => return PngError.DuplicatePalettes,
            }
            if (chunklen == 0 or @mod(chunklen, 3) != 0) return PngError.InvalidPaletteSize;

            const chunk = try self.reader.readAlloc(self.gpa, chunklen);
            defer self.gpa.free(chunk);
            if (!valid_crc(.PLTE, &.{}, try self.reader.takeInt(u32, .big))) return PngError.InvalidCrc;
            var reader: Io.Reader = .fixed(chunk);

            self.palette = try .initCapacity(self.gpa, palettesize);
            for (0..palettesize) |_| {
                self.palette.?.appendAssumeCapacity(.{
                    .r = try reader.takeByte(),
                    .g = try reader.takeByte(),
                    .b = try reader.takeByte(),
                });
            }
        },
        .IDAT => {
            const prelen = data.items.len;
            if (prelen > 0 and previous != .IDAT) return PngError.InvalidChunkSequence;

            self.reader.appendRemaining(self.gpa, data, .limited(chunklen)) catch |e| {
                switch (e) {
                    error.StreamTooLong => {},
                    else => return e,
                }
            };
            if (!valid_crc(.IDAT, data.items[prelen..], try self.reader.takeInt(u32, .big))) return PngError.InvalidCrc;
        },
        else => {
            _ = try self.reader.discard(.limited(chunklen));
            _ = try self.reader.takeInt(u32, .big);
        },
    }

    return chunktype;
}

pub fn deinit(self: *Self) void {
    self.gpa.destroy(self);
}
