# Third-party notices for `msekiya.jar` and `colt.jar`

> **Status as of 2026-11-02:** `colt.jar` is no longer distributed with ATOMCI (removed from this
> directory). The `colt.jar` sections below are kept as a record of what the jar that used to be
> shipped here contained. `msekiya.jar` is distributed as an archive only: it is not installed and
> not run by anything in this tree (see `docs/ATINPUTS_MANUAL.md`).

Formerly, `bin/atinput` (installed by `make install`,
`docs/ATINPUTS_MANUAL.md`) needed both jars at runtime, sourced from this directory unmodified.
Neither jar carries a licence file inside it, so this file exists to disclose what each one
actually contains.

## `colt.jar`

The manifest identifies this jar as the Colt Project's own upstream build:

```
Specification-Title: Colt Distribution
Specification-Vendor: The Colt Project
Implementation-Vendor: wolfgang.hoschek@cern.ch or http://nicewww.cern.ch/~hoschek/colt/index.htm
Implementation-Version: 1.0.2.133 (Thu Nov  8 15:45:10 CET 2001)
```

All 944 classes in the jar carry that same 2001-11-08 build timestamp, consistent with this being
a single upstream release rather than something assembled or added to locally.

### Colt's own licence text

The text below is the Colt License Agreement as published by the Colt Project, copied from two
independent mirrors that agree with each other verbatim —
`wordhoard.northwestern.edu/userman/thirdparty/colt.html` and
`fachwerk.sourceforge.net/data/library-colt-licence.html`. The original,
`dst.lbl.gov/ACSSoftware/colt/license.html`, refuses automated access; these are mirrors of it, not
the original page itself.

```
                         Colt License Agreement

    Packages cern.colt* , cern.jet*, cern.clhep

      Copyright (c) 1999 CERN - European Organization for Nuclear Research.
      Permission to use, copy, modify, distribute and sell this software and
      its documentation for any purpose is hereby granted without fee, provided
      that the above copyright notice appear in all copies and that both that
      copyright notice and this permission notice appear in supporting
      documentation. CERN makes no representations about the suitability of
      this software for any purpose. It is provided "as is" without expressed
      or implied warranty.

    Packages hep.aida.*

      Written by Pavel Binko, Dino Ferrero Merlino, Wolfgang Hoschek, Tony
      Johnson, Andreas Pfeiffer, and others. Check the FreeHEP home page for
      more info. Permission to use and/or redistribute this work is granted
      under the terms of the LGPL License, with the exception that any usage
      related to military applications is expressly forbidden. The software and
      documentation made available under the terms of this license are provided
      with no warranty.
```

**The scope line matters.** An earlier version of this notice reconstructed this text from memory
and dropped the `Packages cern.colt* , cern.jet*, cern.clhep` line — without it, the notice read as
though the whole jar were covered by the Colt licence. It is not: the CERN grant above covers only
those three package families; `hep.aida.*` is separately LGPL, per its own paragraph; and the other
six namespaces in the contents table below (`edu/oswego/cs`, `jal/*`, `edu/cornell/lassp`,
`corejava`, `ViolinStrings`, `com/imsl/math`) are covered by neither.

### What is actually inside the jar (disclosure, not just "Colt")

Colt's own upstream distribution bundles more than the `cern.colt`/`cern.jet` packages the jar is
named for. Enumerated directly from the jar (`unzip -l`, 944 `.class` files total):

| Namespace | Classes | What it is |
|---|---|---|
| `cern/colt`, `cern/jet`, `cern/clhep` | ~444 | CERN Colt proper — covered by the licence above |
| `edu/oswego/cs` | 215 | Doug Lea's `util.concurrent` |
| `jal/*` (BYTE/CHAR/DOUBLE/FLOAT/INT/LONG/OBJECT/SHORT/String) | 132 | Elliotte Rusty Harold's JAL, a generic-algorithms library |
| `hep/aida` (`bin`, `ref`, bare) | 38 | AIDA (Abstract Interfaces for Data Analysis, CERN) — covered by the LGPL block above |
| `edu/cornell/lassp` | 8 | Cornell LASSP utilities (RngPack — see below) |
| `corejava` | 3 | companion code from Cay Horstmann's *Core Java* |
| `ViolinStrings` | 2 | a small string-parsing utility |
| `com/imsl/math` | 2 | `Complex.class` (11547 bytes), `Sfun.class` (8372 bytes) |

All of the above, including `com/imsl/math`, share the jar's single 2001-11-08 build timestamp —
this is how the upstream Colt 1.0.2 distribution itself was assembled, not something added during
this project's use of it. This project's position is limited to that fact: `colt.jar` was
redistributed (until 2026-11-02) exactly as the Colt Project built and published it, and the table
above records what is in it. No per-namespace licensing conclusion is drawn for the six rows outside the two licensed
package families above — that determination is for whoever publishes this tree, not something a
source-tree audit settles.

One further observation, recorded without being pursued: the Ptolemy II project's own Colt notice
states that Colt 1.0.3 shipped a GPL-licensed RngPack and that later versions moved to a
BSD-licensed RngPack 1.1a. `edu/cornell/lassp` is RngPack; this jar is version 1.0.2, one release
before that documented switch, so its `edu/cornell/lassp` classes may be the GPL-licensed RngPack
rather than the later BSD one. Not investigated further here.

`com/imsl/math`'s status is otherwise as already stated: IMSL was, at the time this jar was built,
a commercial/proprietary numerical library (now owned by Rogue Wave / Perforce), not an open one,
and no licence text for this specific package is bundled here or found elsewhere in this
repository. Whether Colt's upstream redistribution of these two compiled classes was ever properly
licensed remains unestablished. Confirmed directly, not merely inferred: `msekiya.jar` itself
contains code that references `com.imsl.math` (below), and that code is not on `bin/atinput`'s own
call path — see "Reachability from `bin/atinput`" under `msekiya.jar`.

## `msekiya.jar`

Built locally (`Ant-Version: Apache Ant 1.8.2`, classes dated 2005–2011), not an upstream
distribution. `unzip -l` reports 375 entries; 340 of them are `.class` files (`unzip -l ... | grep
-c '\.class$'`), the other 35 are directory entries plus `META-INF/MANIFEST.MF` — the two counts
measure different things, not a discrepancy. Of the 340 classes, 337 are this project's own
(`org/atomci/msekiya/**`, `org/atomci/relaxer/**`, `org/atomci/tashi/**`, `com/mac/msekiya/**`) —
authorship is credited in `LEGENDS.txt` and in source comments; this is attribution, not
third-party inclusion.

The remaining 3 classes are third-party: `jp/gr/java_conf/torutk/coding/timer/{TestTask,Time,
UtilTimerTest}.class`, a small Japanese open-source Java timing utility ("torutk"), dated
2006-01-19. No licence file for this utility is bundled in the jar, and none was found to attach
here. Low apparent risk (a handful of timing-helper classes, no proprietary provenance indicators
of the kind `com/imsl/math` has), but the gap — no licence text accompanies the inclusion — is
disclosed rather than papered over, for the same reason as the `colt.jar` item above.

### Six of this project's own classes depend on IMSL

Six classes, all within the 337 counted as this project's own above, reference `com.imsl.math`
directly (confirmed by scanning every class's constant pool for the string, not assumed from
package location):

- `com/mac/msekiya/util/{SimpleGraph,MakeImage,IFunction1D,CsFactory}.class`
- `org/atomci/tashi/gtf/{Orbitals,KnotVec}.class`

These classes need an `IMSL` implementation on the classpath at runtime to function — satisfied, if
at all, by `colt.jar`'s own bundled `com/imsl/math/{Complex,Sfun}.class` (above), which is a
narrower surface than full IMSL and may not cover everything these six classes actually call; that
was not checked, since it doesn't change the question this section answers.

### Reachability from `bin/atinput`

`bin/atinput` (the wrapper formerly installed) ran the entry point
`org/atomci/msekiya/atgen/Main.class`, which is still the entry point for running the archived jar
by hand. None of the six classes above
is on its call path, checked directly rather than assumed:

- Every class in `org/atomci/msekiya/atgen/` (52 total) was scanned for references to
  `com/mac/msekiya/util/`; ten reference exactly three helpers —
  `PairInt`, `PutGetBuffer`, `BoundedBuffer` — and no others.
- Those three helpers were themselves scanned and reference neither `com/imsl` nor
  `org/atomci/tashi`.
- `Main.class`'s own direct references outside its own package are
  `org/atomci/msekiya/util/Tool` and `org/atomci/relaxer/atomci/{Atom,Info}`. `Tool.class` and
  every class under `org/atomci/relaxer/` (all of it, not just `Atom`/`Info`) were scanned and
  reference neither `com/imsl` nor `org/atomci/tashi`.
- One class under `org/atomci/msekiya/` *does* reference `org/atomci/tashi`:
  `org/atomci/msekiya/rel_input/KogaInputMaker.class`, which references
  `org/atomci/tashi/gtf/{CGtf,CGtfFactory,Print}` — none of which is among the two IMSL-referencing
  `tashi` classes above. `KogaInputMaker` is itself referenced by nothing else anywhere in the jar
  (confirmed by scanning every class for the string `KogaInputMaker`) — dead code, not reachable
  from `Main` by any path.

**Bound on this check, stated rather than left implicit**: this traces every direct reference from
`Main` and from the `atgen/` package as a whole, one hop further through each thing they touch
(`Tool`, all of `relaxer/`, and the three util helpers). It is not a full transitive closure of the
entire jar's call graph — a reference three or more hops from `Main` through an as-yet-unchecked
class would not be caught by this method. Given how narrowly `atgen/`'s own dependencies turned out
to be (three small helper classes, no further branching), a hidden multi-hop path is considered
unlikely but is not excluded by what was actually checked.
