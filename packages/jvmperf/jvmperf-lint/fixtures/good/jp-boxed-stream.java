import java.util.List;
class JpBoxedStream {
    int total(List<String> xs) { return xs.stream().mapToInt(String::length).sum(); }
    double avg(int[] xs) { return java.util.Arrays.stream(xs).average().orElse(0); }
}
