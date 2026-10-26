## 5. Flag layout

Several on/off properties of one record, such as which power sources a vehicle has, do not each need a full integer when many copies of that record share a tight RAM budget. A mix (electric and gasoline together) is a combination of bits, not one exclusive enum value.

`sizeof` is the size that matters, and it includes alignment padding. Four `int` flags occupy four `int`s. Where `int` is 16 bits that is 8 bytes; where `int` is 32 bits it is 16. A bit-field width is not that size. `unsigned` bit-fields are commonly stored in an `unsigned int`, so four 1-bit fields can still occupy 4 bytes. `unsigned char` bit-fields can share one byte. A single `unsigned` mask is the other compact form. Check `sizeof` on the ABI you ship.

Turning alignment off, or a packing pragma, is a target choice. Some CPUs fault or slow down on unaligned loads. This hint does not ask for that.

**cp-wide-bool-flags** fires when one struct has four or more full-width `bool` or `_Bool` members, or four or more `int` / `unsigned` members named `is_`, `has_`, or `can_`, and the struct has no bit-field. It is a **hint**. JSONL is present. The rule stays hint, and the 2026-10-22 corpus verdict does not cover it. A handful of records on a desktop can ignore it. A similar object-header rule on the JVM was removed after measurement showed no footprint win; this C hint is not that measurement.

A fixture hit is not a measured saving. See [evidence-policy.md](evidence-policy.md).
