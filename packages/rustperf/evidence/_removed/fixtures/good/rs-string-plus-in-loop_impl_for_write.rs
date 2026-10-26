// impl Trait for Type must not be treated as a for-loop (G3 FP class).
pub struct Buf(String);
impl std::fmt::Write for Buf {
    fn write_str(&mut self, s: &str) -> Result<(), std::fmt::Error> {
        self.0.push_str(s);
        Ok(())
    }
}
