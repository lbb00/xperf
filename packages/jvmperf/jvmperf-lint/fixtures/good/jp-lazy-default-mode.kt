class Screen {
    val adapter by lazy(LazyThreadSafetyMode.NONE) { ArrayList<String>(16) }
}
