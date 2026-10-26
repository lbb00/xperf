// for<'a> lifetime binder is not a loop (G3 FP class).
pub trait Tr {
    fn go(&self);
}
pub fn call(x: &dyn for<'a> Tr) {
    let _ = x;
}
