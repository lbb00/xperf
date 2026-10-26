#[cfg(test)]
mod tests {
    #[test]
    fn builds_vec() {
        let mut arr = Vec::new();
        for b in 0..16 {
            arr.push(b);
        }
        assert_eq!(arr.len(), 16);
    }
}
