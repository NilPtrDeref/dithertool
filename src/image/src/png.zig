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
    try process_scanlines(gpa, &header, &decompressor.reader, &image.data);

    return image;
}

fn valid_crc(chunktype: ChunkType, data: []const u8, crc: u32) bool {
    var ecrc = std.hash.crc.Crc32.init();
    ecrc.update(std.mem.asBytes(&std.mem.nativeToBig(u32, @intFromEnum(chunktype))));
    ecrc.update(data);
    return crc == ecrc.final();
}

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
            if (!valid_crc(.PLTE, chunk, try reader.takeInt(u32, .big))) return PngError.InvalidCrc;
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

fn process_scanlines(gpa: Allocator, header: *Header, sreader: *Io.Reader, output: *[]u8) !void {
    if (header.interlace == .Adam7) return PngError.UnsupportedInterlaceMethod; // FIXME: Add support for Adam7 interlacing

    // Bytes Per Pixel
    const bpp = switch (header.colortype) {
        .Greyscale => switch (header.bitdepth) {
            1, 2, 4 => 1,
            8, 16 => header.bitdepth / 8,
            else => return PngError.InvalidBitDepth,
        },
        .Truecolor => 3 * header.bitdepth / 8,
        .Indexed => 1,
        .GreyscaleAlpha => 2 * header.bitdepth / 8,
        .TruecolorAlpha => 4 * header.bitdepth / 8,
        else => return PngError.InvalidBitDepth,
    };

    var current = try gpa.alloc(u8, header.width * bpp);
    defer gpa.free(current);
    var previous = try gpa.alloc(u8, header.width * bpp);
    defer gpa.free(previous);
    @memset(previous, 0);

    for (0..header.height) |y| {
        // Read filter and current
        const filter: FilterType = @enumFromInt(try sreader.takeByte());
        try sreader.readSliceAll(current);

        // Transform current based on filter
        switch (filter) {
            .None => {},
            .Sub => {
                for (current, 0..) |byte, index| {
                    const a: u16 = if (index < bpp) 0 else current[index - bpp];
                    const value: u16 = byte + a;
                    current[index] = @truncate(value % 256);
                }
            },
            .Up => {
                for (current, 0..) |byte, index| {
                    const b: u16 = if (y == 0) 0 else previous[index];
                    const value: u16 = byte + b;
                    current[index] = @truncate(value % 256);
                }
            },
            .Average => {
                for (current, 0..) |byte, index| {
                    const a: f32 = if (index < bpp) 0 else current[index - bpp];
                    const b: f32 = if (y == 0) 0 else previous[index];
                    const value: u16 = byte + @as(u16, @intFromFloat(@floor((a + b) / 2.0)));
                    current[index] = @truncate(value % 256);
                }
            },
            .Paeth => {
                for (current, 0..) |byte, index| {
                    const a: u15 = if (index < bpp) 0 else current[index - bpp];
                    const b: u15 = if (y == 0) 0 else previous[index];
                    const c: u15 = if (y == 0 or index < bpp) 0 else previous[index - bpp];
                    const p: i16 = a + b -| c;
                    const pa = @abs(p - a);
                    const pb = @abs(p - b);
                    const pc = @abs(p - c);
                    var value: u16 = 0;
                    if (pa <= pb and pa <= pc) {
                        value = byte + a;
                    } else if (pb <= pc) {
                        value = byte + b;
                    } else {
                        value = byte + c;
                    }
                    current[index] = @truncate(value % 256);
                }
            },
            _ => return PngError.InvalidFilterMethod,
        }

        // Read current into image output buffer
        switch (header.colortype) {
            .Greyscale => {
                for (0..header.width) |x| {
                    const index = (y * header.width + x) * 4;
                    if (header.bitdepth <= 8) {
                        const shift: u3 = @intCast(8 -| header.bitdepth);
                        output.*[index] = current[x] >> shift;
                        output.*[index + 1] = current[x] >> shift;
                        output.*[index + 2] = current[x] >> shift;
                        output.*[index + 3] = 255;
                    } else if (header.bitdepth == 16) {
                        const reinterp: []u16 = @ptrCast(@alignCast(current));
                        const w = reinterp[x] % 256;
                        output.*[index] = @truncate(w);
                        output.*[index + 1] = @truncate(w);
                        output.*[index + 2] = @truncate(w);
                        output.*[index + 3] = 255;
                    }
                }
            },
            .Truecolor => {
                for (0..header.width) |x| {
                    const index = (y * header.width + x) * 4;
                    const cindex = x * 3;
                    if (header.bitdepth == 8) {
                        output.*[index] = current[cindex];
                        output.*[index + 1] = current[cindex + 1];
                        output.*[index + 2] = current[cindex + 2];
                        output.*[index + 3] = 255;
                    } else {
                        const reinterp: []u16 = @ptrCast(@alignCast(current));
                        const r = reinterp[cindex] % 256;
                        const g = reinterp[cindex + 1] % 256;
                        const b = reinterp[cindex + 2] % 256;
                        output.*[index] = @truncate(r);
                        output.*[index + 1] = @truncate(g);
                        output.*[index + 2] = @truncate(b);
                        output.*[index + 3] = 255;
                    }
                }
            },
            .Indexed => {
                const palette = header.palette orelse return PngError.MissingPalette;
                for (0..header.width) |x| {
                    const index = (y * header.width + x) * 4;
                    const shift: u3 = @intCast(8 -| header.bitdepth);
                    const pindex = current[x] >> shift;
                    if (pindex >= palette.items.len) return error.OutOfPaletteBounds;
                    const color = palette.items[pindex];
                    output.*[index] = color.r;
                    output.*[index + 1] = color.g;
                    output.*[index + 2] = color.b;
                    output.*[index + 3] = 255;
                }
            },
            .GreyscaleAlpha => {
                for (0..header.width) |x| {
                    const index = (y * header.width + x) * 4;
                    const cindex = x * 2;
                    if (header.bitdepth == 8) {
                        output.*[index] = current[cindex];
                        output.*[index + 1] = current[cindex];
                        output.*[index + 2] = current[cindex];
                        output.*[index + 3] = current[cindex + 1];
                    } else {
                        const reinterp: []u16 = @ptrCast(@alignCast(current));
                        const w = reinterp[cindex] % 256;
                        const a = reinterp[cindex + 1] % 256;
                        output.*[index] = @truncate(w);
                        output.*[index + 1] = @truncate(w);
                        output.*[index + 2] = @truncate(w);
                        output.*[index + 3] = @truncate(a);
                    }
                }
            },
            .TruecolorAlpha => {
                for (0..header.width) |x| {
                    const index = (y * header.width + x) * 4;
                    const cindex = x * 4;
                    if (header.bitdepth == 8) {
                        output.*[index] = current[cindex];
                        output.*[index + 1] = current[cindex + 1];
                        output.*[index + 2] = current[cindex + 2];
                        output.*[index + 3] = current[cindex + 3];
                    } else {
                        const reinterp: []u16 = @ptrCast(@alignCast(current));
                        const r = reinterp[cindex] % 256;
                        const g = reinterp[cindex + 1] % 256;
                        const b = reinterp[cindex + 2] % 256;
                        const a = reinterp[cindex + 3] % 256;
                        output.*[index] = @truncate(r);
                        output.*[index + 1] = @truncate(g);
                        output.*[index + 2] = @truncate(b);
                        output.*[index + 3] = @truncate(a);
                    }
                }
            },
            else => return PngError.InvalidColorType,
        }

        // Save current to previous
        @memcpy(previous, current);
    }

    _ = try sreader.discardRemaining();
}
