import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Stream;

/** Concatenate docs/guide-src/{lang}/*.md and expand @@path@@ includes. */
public final class BuildGuide {
    static final Path ROOT = Path.of(System.getProperty("guide.root", ".")).toAbsolutePath().normalize();
    static final Map<String, String> LANG = Map.of(
            ".java", "java", ".kt", "kotlin", ".kts", "kotlin",
            ".pro", "proguard", ".txt", "text", ".sh", "sh");
    static final Pattern INCLUDE = Pattern.compile("^@@(.+?)@@$");

    public static void main(String[] args) throws Exception {
        String language = args.length > 0 ? args[0] : "en";
        if (!language.equals("en") && !language.equals("zh-CN")) {
            System.err.println("language must be en or zh-CN");
            System.exit(2);
        }
        Path dest = build(language);
        System.out.println("Generated " + ROOT.relativize(dest) + " (" + Files.size(dest) + " bytes)");
    }

    static Path build(String language) throws IOException {
        Path source = ROOT.resolve("docs/guide-src").resolve(language);
        Path destinationDir = ROOT.resolve("docs").resolve("zh-CN".equals(language) ? "zh-CN" : language);
        Path destination = destinationDir.resolve("performance-guide.md");
        List<String> output = new ArrayList<>();
        try (Stream<Path> chapters = Files.list(source)) {
            List<Path> sorted = chapters.filter(p -> p.toString().endsWith(".md"))
                    .sorted(Comparator.comparing(p -> p.getFileName().toString())).toList();
            for (Path chapter : sorted) {
                for (String line : Files.readAllLines(chapter, StandardCharsets.UTF_8)) {
                    Matcher m = INCLUDE.matcher(line.strip());
                    if (m.matches()) {
                        String relative = m.group(1);
                        Path included = ROOT.resolve(relative);
                        if (!Files.exists(included)) throw new IOException("missing include: " + relative);
                        String suffix = "";
                        int dot = included.getFileName().toString().lastIndexOf('.');
                        if (dot >= 0) suffix = included.getFileName().toString().substring(dot);
                        output.add("`" + relative + "`\n");
                        output.add("```" + LANG.getOrDefault(suffix, "") + "\n"
                                + Files.readString(included, StandardCharsets.UTF_8).stripTrailing() + "\n```");
                    } else {
                        output.add(line);
                    }
                }
                output.add("");
            }
        }
        Files.createDirectories(destinationDir);
        String body = String.join("\n", output).stripTrailing() + "\n";
        Files.writeString(destination, body, StandardCharsets.UTF_8);
        return destination;
    }
}
