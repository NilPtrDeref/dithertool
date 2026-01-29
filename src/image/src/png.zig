/// Implementation derived from the following specification:
/// https://w3c.github.io/png/
///
const Image = @import("Image.zig");
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

pub const PngSignature: u64 = 0x89504E470D0A1A0A;

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

const FilterType = enum(u8) {
    None = 0,
    Sub = 1,
    Up = 2,
    Average = 3,
    Paeth = 4,
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

const Header = struct {
    width: u32 = 0,
    height: u32 = 0,
    bitdepth: u8 = 0,
    colortype: ColorType = undefined,
    interlace: InterlaceMethod = undefined,
    palette: ?Palette = null,
};

pub fn parse(gpa: Allocator, reader: *Io.Reader) !*Image {
    // Check PNG signature
    if (PngSignature != try reader.peekInt(u64, .big)) return PngError.InvalidSignature;
    _ = try reader.takeInt(u64, .big);

    var previous: ?ChunkType = null;
    var header: Header = .{};
    defer if (header.palette) |*palette| {
        palette.deinit(gpa);
    };
    var scanlines: std.ArrayList(u8) = .empty;
    defer scanlines.deinit(gpa);
    while (true) {
        previous = parse_chunk(gpa, reader, previous, &header, &scanlines) catch |e| {
            switch (e) {
                error.EndOfStream => break,
                else => return e,
            }
        };
    }
    if (header.colortype == .Indexed and header.palette == null) return PngError.MissingPalette;

    var image = try gpa.create(Image);
    errdefer gpa.destroy(image);
    image.width = header.width;
    image.height = header.height;
    image.stride = 4; // RGBA
    image.data = try gpa.alloc(u8, header.width * header.height * 4);
    errdefer gpa.free(image.data);

    var sreader: Io.Reader = .fixed(scanlines.items);
    var buffer: [std.compress.flate.max_window_len]u8 = undefined;
    var decompressor = std.compress.flate.Decompress.init(&sreader, .zlib, &buffer);
    try process_scanlines(&header, &decompressor.reader, &image.data);

    return image;
}

fn valid_crc(chunktype: ChunkType, data: []const u8, crc: u32) bool {
    var ecrc = std.hash.crc.Crc32.init();
    ecrc.update(std.mem.asBytes(&std.mem.nativeToBig(u32, @intFromEnum(chunktype))));
    ecrc.update(data);
    return crc == ecrc.final();
}

// TODO: Clean up this function:
// 1. Too many params, feels chunky.
// 2. Reader for header/palette could easily be confused for input reader.
fn parse_chunk(gpa: Allocator, reader: *Io.Reader, previous: ?ChunkType, header: *Header, data: *std.ArrayList(u8)) !ChunkType {
    const chunklen = try reader.takeInt(u32, .big);
    const chunktype: ChunkType = @enumFromInt(try reader.takeInt(u32, .big));

    switch (chunktype) {
        _ => return PngError.InvalidChunkType,
        .IHDR => {
            if (previous != null) return PngError.DuplicateHeader;
            if (chunklen != 13) return PngError.InvalidHeaderLength;

            var chunk: [13]u8 = undefined;
            try reader.readSliceAll(&chunk);
            if (!valid_crc(.IHDR, &chunk, try reader.takeInt(u32, .big))) return PngError.InvalidCrc;
            var hreader: Io.Reader = .fixed(&chunk);

            header.width = try hreader.takeInt(u32, .big);
            header.height = try hreader.takeInt(u32, .big);

            header.bitdepth = try hreader.takeByte();
            header.colortype = @enumFromInt(try hreader.takeByte());
            switch (header.colortype) {
                .Greyscale => switch (header.bitdepth) {
                    1, 2, 4, 8, 16 => {},
                    else => return PngError.InvalidBitDepth,
                },
                .Truecolor => switch (header.bitdepth) {
                    8, 16 => {},
                    else => return PngError.InvalidBitDepth,
                },
                .Indexed => switch (header.bitdepth) {
                    1, 2, 4, 8 => {},
                    else => return PngError.InvalidBitDepth,
                },
                .GreyscaleAlpha => switch (header.bitdepth) {
                    8, 16 => {},
                    else => return PngError.InvalidBitDepth,
                },
                .TruecolorAlpha => switch (header.bitdepth) {
                    8, 16 => {},
                    else => return PngError.InvalidBitDepth,
                },
                _ => return PngError.InvalidColorType,
            }

            if (try hreader.takeByte() != 0) return PngError.InvalidCompressionMethod;
            if (try hreader.takeByte() != 0) return PngError.InvalidFilterMethod;
            header.interlace = @enumFromInt(try hreader.takeByte());
            switch (header.interlace) {
                _ => return PngError.InvalidInterlaceMethod,
                else => {},
            }
        },
        .IEND => {
            if (!valid_crc(.IEND, &.{}, try reader.takeInt(u32, .big))) return PngError.InvalidCrc;
        },
        .PLTE => {
            if (header.palette != null) return PngError.DuplicatePalettes;
            const palettesize = chunklen / 3;
            switch (header.colortype) {
                .Indexed => {
                    if (palettesize > std.math.pow(u32, 2, header.bitdepth)) return PngError.InvalidPaletteSize;
                },
                .Truecolor, .TruecolorAlpha => {
                    if (palettesize > 256) return PngError.InvalidPaletteSize;
                },
                else => return PngError.DuplicatePalettes,
            }
            if (chunklen == 0 or @mod(chunklen, 3) != 0) return PngError.InvalidPaletteSize;

            const chunk = try reader.readAlloc(gpa, chunklen);
            defer gpa.free(chunk);
            if (!valid_crc(.PLTE, &.{}, try reader.takeInt(u32, .big))) return PngError.InvalidCrc;
            var preader: Io.Reader = .fixed(chunk);

            header.palette = try .initCapacity(gpa, palettesize);
            for (0..palettesize) |_| {
                header.palette.?.appendAssumeCapacity(.{
                    .r = try preader.takeByte(),
                    .g = try preader.takeByte(),
                    .b = try preader.takeByte(),
                });
            }
        },
        .IDAT => {
            const prelen = data.items.len;
            if (prelen > 0 and previous != .IDAT) return PngError.InvalidChunkSequence;

            reader.appendRemaining(gpa, data, .limited(chunklen)) catch |e| {
                switch (e) {
                    error.StreamTooLong => {},
                    else => return e,
                }
            };
            if (!valid_crc(.IDAT, data.items[prelen..], try reader.takeInt(u32, .big))) return PngError.InvalidCrc;
        },
        else => {
            _ = try reader.discard(.limited(chunklen));
            _ = try reader.takeInt(u32, .big);
        },
    }

    return chunktype;
}

fn process_scanlines(header: *Header, sreader: *Io.Reader, output: *[]u8) !void {
    if (header.interlace == .Adam7) return PngError.UnsupportedInterlaceMethod; // FIXME: Add support for Adam7 interlacing

    // TODO: Process the colortype properly. Currently hardcoded for truecolor
    for (0..header.height) |y| {
        const filter: FilterType = @enumFromInt(try sreader.takeByte());
        for (0..header.width) |x| {
            switch (filter) {
                .None => {
                    const index = (y * header.width + x) * 4;
                    try sreader.readSliceAll(output.*[index .. index + 3]);
                    output.*[index + 3] = 255;
                },
                .Sub => {
                    const index = (y * header.width + x) * 4;
                    try sreader.readSliceAll(output.*[index .. index + 3]);
                    output.*[index + 3] = 255;
                    if (x != 0) {
                        const previous = (y * header.width + x - 1) * 4;
                        output.*[index] = output.*[index] -| output.*[previous];
                        output.*[index] = output.*[index + 1] -| output.*[previous + 1];
                        output.*[index] = output.*[index + 2] -| output.*[previous + 2];
                    }
                },
                .Up => {
                    const index = (y * header.width + x) * 4;
                    try sreader.readSliceAll(output.*[index .. index + 3]);
                    output.*[index + 3] = 255;
                    if (y != 0) {
                        const previous = ((y - 1) * header.width + x) * 4;
                        output.*[index] = output.*[index] -| output.*[previous];
                        output.*[index] = output.*[index + 1] -| output.*[previous + 1];
                        output.*[index] = output.*[index + 2] -| output.*[previous + 2];
                    }
                },
                .Average => {
                    // FIXME: Actually implement
                    const index = (y * header.width + x) * 4;
                    try sreader.readSliceAll(output.*[index .. index + 3]);
                    output.*[index + 3] = 255;
                },
                .Paeth => {
                    // FIXME: Actually implement
                    const index = (y * header.width + x) * 4;
                    try sreader.readSliceAll(output.*[index .. index + 3]);
                    output.*[index + 3] = 255;
                },
                _ => return PngError.InvalidFilterMethod,
            }
        }
    }

    _ = try sreader.discardRemaining();
}
