class OkHttpClient {
    OkHttpClient() {}
}
class JpClientFactoryRecreate {
    final OkHttpClient shared = new OkHttpClient();
    OkHttpClient client() { return shared; }
}
