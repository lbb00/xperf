const Matrix = struct { m: [16]f64 };
pub fn trace(mat: Matrix) f64 {
    return mat.m[0] + mat.m[5] + mat.m[10] + mat.m[15];
}
