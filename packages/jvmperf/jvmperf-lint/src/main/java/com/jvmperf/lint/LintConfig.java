package com.jvmperf.lint;

/** Process-wide lint switches set by Cli before a run. */
public final class LintConfig {
    public static final LintConfig CONFIG = new LintConfig();

    /** When false (default), files with source_group=test are not scanned. */
    public boolean includeTests = false;
    /** When false (default), System.out/err and Kotlin println/print in loops are not jp-log-hot. */
    public boolean strictStdioInLoop = false;
    /** When true (default), hot rules match outside loops too. --scope loop restores loop-only. */
    public boolean scopeAll = true;

    public void reset() {
        includeTests = false;
        strictStdioInLoop = false;
        scopeAll = true;
    }

    private LintConfig() {}
}
