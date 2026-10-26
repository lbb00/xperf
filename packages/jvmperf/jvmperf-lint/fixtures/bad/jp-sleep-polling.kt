@Volatile var ready = false
fun await() {
    while (!ready) {
        Thread.sleep(10)
    }
}
