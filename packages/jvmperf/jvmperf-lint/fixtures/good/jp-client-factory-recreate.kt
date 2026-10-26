class OkHttpClient
class JpClientFactoryRecreate {
    private val shared = OkHttpClient()
    fun client(): OkHttpClient = shared
}
