async fn good(n: i32) {
    for _ in 0..n {
        let _t = std::time::Instant::now();
        let _v = ready.await;
    }
}
