import java.util.List;
import java.util.stream.Collectors;
class JpBoxedStream {
    int total(List<Integer> xs) { return xs.stream().map(x -> x * 2).reduce(0, Integer::sum); }
    long sum2(List<String> s) { return s.stream().collect(Collectors.summingLong(String::length)); }
}
