## 3. Regex, flush, and the clock

Constructing `std::regex` inside a loop compiles every iteration. On a short haystack that was about 7.7× versus constructing it once. `std::endl` on an external stream flushes every insertion (about 23× versus a newline and one flush). The same manipulator on a string stream was about 0.87×, so that shape is not the finding. Sampling `steady_clock::now` every pass was about 147× versus sampling once; a loop that needs a fresh timestamp has nothing to hoist. Building a string stream every iteration was about 1.2× at `-O2` and that rule was removed. These lints stay **hint**. They are not part of the 2026-10-22 corpus verdict.

`ifstream` of one path was about 2025× versus opening once. A path that changes every iteration cannot be hoisted. This does not revive the removed CX003 id.

Companion lint: **cx-regex-ctor-hot**, **cx-endl-hot**, **cx-clock-hot**, **cx-ifstream-hot**.
