package com.jvmperf.lint;

/** Process-wide lint switches set by Cli before a run. */
public final class LintConfig {
    public static final LintConfig CONFIG = new LintConfig();

    /** When false (default), files with source_group=test are not scanned. */
    public boolean includeTests = false;
    /** When false (default), System.out/err and Kotlin println/print in loops are not jp-log-in-loop. */
    public boolean strictStdioInLoop = false;

    public void reset() {
        includeTests = false;
        strictStdioInLoop = false;
    }

    private LintConfig() {}
}
