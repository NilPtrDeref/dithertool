pub const png = @import("png.zig");

const Self = @This();
width: u32,
height: u32,
/// Stride represents the size of the pixel values, there are only a few supported values:
/// 1: Greyscale
/// 2: Greyscale w/ Alpha
/// 3: RGB
/// 4: RGBA
stride: u8,
data: []u8,
