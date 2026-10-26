const Matrix = struct { m: [16]f64 };
const Vec2 = struct { x: f32, y: f32 };
pub fn trace(mat: *const Matrix) f64 {
    return mat.m[0] + mat.m[5] + mat.m[10] + mat.m[15];
}
pub fn len2(v: Vec2) f32 {
    return v.x * v.x + v.y * v.y;
}
