# ATOMCI Input-Deck Generator (`msekiya.jar`) Manual

> **Manual of an archived tool.** The Java tool it documents, `msekiya.jar`
> (kept at [`attic/msekiya-jar/msekiya.jar`](../attic/msekiya-jar/)), was
> surpassed in capability by a pure-Python generator, `scripts/atinputs`
> (installed as `bin/atinpgen`; see [`docs/ATINPUTS_PY.md`](ATINPUTS_PY.md)
> for its `.inp` format, schema, lint rules, and its full port of native
> `atgen`'s CSF-list generation). It is not installed, and its run-time dependency
> `colt.jar` (CERN Colt 1.0.2) is not distributed: running it needs Colt 1.0.2
> obtained separately (§2). Use `atinpgen` for all new work.

> **Scope**: the XML inputs (`<atomciInput>`) under `samples/atinputs/`, and the
> Java tool `msekiya.jar` that converts them into a native NAMELIST deck
> plus a CSF list.
>
> **What this covers**: this document exhaustively scans **every
> Relaxer binding class** under `org/atomci/relaxer/atomci/*` with `javap -p`, and
> **item-by-item** cross-checks them against `docs/namelist.002` (the complete
> parameter table for every native NAMELIST), presenting "what gets simplified" and
> "what cannot be input" as verified facts.

---

## 1. Overview

`msekiya.jar` is a tool that describes ATOMCI's entire 8-step pipeline
(`&AI`–`&RS`) in high-level XML, and from that automatically generates **both the
native NAMELIST deck and the CSF list**.

- **When/who added**: added by M. Sekiya around 2005–2011. **It is not mentioned
  in the 1994 original program manual (`docs/*.002`)**. No primary source showing
  the intended operating procedure of that era has been confirmed to survive (see
  §7).
- **Positioning**: it is not a mere port of the native `atgen` (`src/atgen.f`,
  which generates **only** the CSF list from `.atg`). It subsumes the role of
  `atgen` while also being a higher-level tool that generates the **entire deck**
  (`&CNTL`, the per-step NAMELISTs, and the `OPEN` lines).
- **Dependencies**: `msekiya.jar` (the tool itself) + `colt.jar` (the CERN Colt
  numerical library, circa 2001, no longer developed but working on current JVMs;
  the Douglas–Kroll relativistic integral engine inside the jar uses it). Only
  `msekiya.jar` is kept, at `attic/msekiya-jar/msekiya.jar`; `colt.jar` is no
  longer distributed (removed 2026-11-02) and nothing is installed by
  `make install` — see §2 below.
- **Verification status** (at the time the tool was installed): confirmed on two fluorine cases (`f.xml` → SD-CI
  `-99.641223`, `fpt.xml` → PT selection `-99.640355`) that XML → generated
  deck+CSF → the real `atomci` → matches the golden energy. Boron is **not
  expressible** with this tool (§5.3).

The essence of the tool is to "**mechanically derive numerical tables from a basis
file and a reference configuration, and automatically set the execution flags**".
The user describes the physics, and leaves the mechanical parts — `NBF`/`NOB`/`MPOB`,
`CLOSED`/`CSFS`/`ITNEL`, the CSF list itself, the `NRNFG` flag row — to the tool
(§4 shows before/after).

---

## 2. Usage

The tool is archived: `make install` does not install it. `colt.jar` is not
distributed, so to run the jar you must first obtain CERN Colt 1.0.2
(`colt.jar`) yourself, then call Java directly with both jars on the
classpath (`<path>` = where you put `colt.jar`; `ATOMCI_HOME` is needed only
for `CFPTBL` and `atomci`):

```sh
repo=/path/to/atomci
CP="$repo/attic/msekiya-jar/msekiya.jar:<path>/colt.jar"
mkdir -p ~/atomci-runs/fx && cd ~/atomci-runs/fx
ln -sf "$ATOMCI_HOME/CFPTBL" ./CFPTBL
cp "$repo/samples/native/f.bas" .            # basis (shared by f and fpt)

# --- f: generate deck (f.deck) + CSF (f.csf) from XML, then run ---
java -cp "$CP" org.atomci.msekiya.atgen.Main "$repo/samples/atinputs/f.xml"
"$ATOMCI_HOME/bin/atomci" < f.deck > f.out   # -> SD-CI ENERGY = -99.641223
                                             #    also writes f.NO (unit 27)

# --- fpt: reuses f.NO from the f run above (run f first) ---
java -cp "$CP" org.atomci.msekiya.atgen.Main "$repo/samples/atinputs/fpt.xml"
"$ATOMCI_HOME/bin/atomci" < fpt.deck > fpt.out  # -> SD-CI ENERGY = -99.640355
```

`Main` writes the deck to the file pointed to by the XML `<info output>`, and the
CSF list to the file pointed to by `<info><csf file>`. For detailed examples, see
`samples/atinputs/README.md` and `f.xml`/`fpt.xml`.

---

## 3. Complete XML schema reference

This is **every element and every attribute of the schema**, obtained by scanning
all data-binding classes under `org/atomci/relaxer/atomci/*` with `javap -p`
(because they are Relaxer-generated, simple values become attributes and compound
values become child elements). In the "repetition" column, `0..N` indicates that
multiple elements of the same name are allowed (the binding has `addXxx()` and an
array getter).

### 3.1 Element hierarchy

```
<atomciInput>                                    root
├─ <info>                     (1)                files, atom, title
│   ├─ <atom>                 (1)   attrs: ang, spin, z
│   ├─ <cfptable>             (1)   attrs: file
│   ├─ <csf>                  (1)   attrs: file, status  (+content※)
│   ├─ <basis>                (1)   attrs: file, format, status  (+content※)
│   ├─ <mcp>                  (1)   attrs: file  (+content※)
│   └─ <open>                 (0..N) attrs: unit, file, format, status
├─ <orbital>                  (1)                orbital space
│   ├─ <frozen_core>          (0..N) attrs: n, l
│   ├─ <active>               (0..N) attrs: id  (+ang, point, spin※)
│   └─ <outer>                (0..N) attrs: n, l
├─ <reference>                (1)                reference configuration
│   └─ <conf>                 (0..N) attrs: scf
│       └─ <orb>              (0..N) attrs: id, occ
└─ <ctrl>                     (0..N)※ pipeline stage; repeatable (§3.4)
    ├─ <ai>                   (0..1) attrs: type, idprnt, ifdk3, ifnucl  (+content※)
    ├─ <mc>                   (0..1) attrs: itmax, out_record
    │   └─ <ind>              (0..N) attrs: record, l, first, last
    ├─ <wf>                   (0..1) attrs: rule, npflg  (+content※)
    ├─ <tr>                   (0..1) attrs: input_unit, record
    │   └─ <ind>              (0..N) attrs: record, l, first, last
    ├─ <pt>                   (0..1) attrs: cthr, ethr, how, nstate
    ├─ <ex>                   (0..1) attrs: retry
    ├─ <ci>                   (0..1) attrs: ips, maxit, nsdim, nstate, out, record
    └─ <rs>                   (0..1) attrs: print
```

The `content` items marked ※ (an element's text content) **exist in the binding
but are not used in the deck-generation path** (§5.4). Each element also has a
`title` attribute, but it is not reflected in deck generation (§6.4).

### 3.2 Attribute types (as measured by `javap`)

| Element | Attribute | Type | Meaning |
|------|------|----|------|
| `<atom>` | `ang` | String | Spatial-symmetry symbol (`S`/`P`/`D`…) → `IORB` |
| | `spin` | int | Spin multiplicity 2S+1 → `ISPIN` |
| | `z` | **int** | Nuclear charge → `Z`. **Integer only** (§5.5) |
| `<cfptable>` | `file` | String | Path to CFPTBL (usually `./CFPTBL`) |
| `<csf>` | `file` | String | Output destination for the generated CSF list |
| | `status` | String | `OPEN` status |
| `<basis>` | `file` | String | Basis file (**must be read**; §5.4) |
| | `format` | String | Basis format (`atomci` etc.) |
| | `status` | String | `OPEN` status |
| `<mcp>` | `file` | String | Model-core-potential file |
| `<open>` | `unit` | int | Additional unit number to open |
| | `file`/`format`/`status` | String | File / `BINARY` / `OLD` etc. |
| `<frozen_core>` | `n`,`l` | int | Principal/azimuthal quantum numbers of the frozen-core shell |
| `<active>` | `id` | String | Active-shell label (`2S`/`2P`…) |
| | `ang`/`point`/`spin` | String | ※fragile; omit recommended (§6.2) |
| `<outer>` | `n`,`l` | int | Correlating (outer) shell |
| `<conf>` | `scf` | boolean | Whether to make this configuration the SCF reference |
| `<orb>` | `id` | String | Orbital label |
| | `occ` | int | Occupation number |
| `<ai>` | `type` | int | Basis kind → `NTYPE` (1=STO, 2=GTO) |
| | `idprnt` | int | → `IDPRNT` |
| | `ifdk3`/`ifnucl` | boolean | Relativistic DK3 / finite nucleus (§4.4; **outside the manual**) |
| `<mc>` | `itmax` | int | MCSCF macro-iteration limit → `ITMAX` |
| | `out_record` | int | Orbital-save record |
| `<wf>` | `rule` | int | → `RULE` (0/1/2) |
| | `npflg` | int | → `NPFLG` |
| `<ind>` | `record`,`l`,`first`,`last` | int | The `IND` four-tuple for `&GET`/`&MC` |
| `<pt>` | `cthr`,`ethr` | double | → `CTHR`,`ETHR` |
| | `how` | int | → `HOW` |
| | `nstate` | int | → `NSOLVE` |
| `<ex>` | `retry` | boolean | → `RETRY` |
| `<ci>` | `ips`,`maxit`,`nsdim`,`nstate` | int | → CI parameters of the same names |
| | `out`,`record` | int | Purpose undetermined (§7) |
| `<rs>` | `print` | double | → `PTHR` |

### 3.3 Correspondence between the `<ctrl>` steps and `NRNFG`

The **presence or absence** of the child elements included in `<ctrl>` determines
`&CNTL NRNFG(1..8)` (in native, you line up the 8 flags by hand).

| `<ctrl>` child element | Pipeline step | `NRNFG` slot |
|-----------------|----------------|------------------|
| `<ai>` | AIMAIN (atomic integrals) | (1) |
| `<mc>` | MCMAIN (MCSCF) | (2) |
| `<wf>` | WFMAIN (CSF+EE) | (3) |
| `<tr>` | TRMAIN (integral transformation) | (4) |
| `<pt>` | PTMAIN (perturbative selection) | (5) |
| `<ex>` | EXMAIN (EE tape) | (6) |
| `<ci>` | CIMAIN (diagonalization) | (7) |
| `<rs>` | RSMAIN (summary; prints SD-CI ENERGY) | (8) |

Write an element and that slot is 1; omit it and it is 0. For example, omitting
`<mc>` gives `NRNFG(2)=0` (skip MCSCF), while including `<rs>` gives `NRNFG(8)=1`
(**required, because this step prints the final SD-CI ENERGY**; §6.3).

### 3.4 Multiple `<ctrl>` blocks

The binding permits **repetition** of `<ctrl>` (`AtomciInput.addCtrl`,
`getCtrl():Ctrl[]`), and the generator `Main` scans the array (the bytecode shows
a `getCtrl():[]` + `arraylength` loop). Thus a **multi-block pipeline** such as a
natural-orbital restart (corresponding to the 3-block structure of the native
`f.stdin`) can in principle be expressed. However, each block's `&CI IOFLG`
(save directive) is hard-coded and cannot be changed, so there is a limit to
restart fidelity (§5.2). The bundled `f.xml`/`fpt.xml` use only a single `<ctrl>`,
and multi-block generation is unverified.

---

## 4. What gets simplified

The quantities that a user would otherwise have to compute and write by hand when
hand-writing a native deck are automatically derived by the tool from the
high-level description.

### 4.1 Quantities derived from the basis file (`NSYM`/`NBF`/`NOB`/`MPOB`)

It reads the basis in `<basis file>` and automatically computes the number of
basis functions, the number of orbitals, and the mapping table for each symmetry.
In the fluorine example, hand-writing would require you to count and line up the
following yourself:

```
 &TR NSYM=4, NBF=13,11,6,5, NOB=13,11,6,5,
     MPOB=13,12,11,10,9,8,7,6,5,4,3,2,1,
          11,10,9,8,7,6,5,4,3,2,1,
          6,5,4,3,2,1,
          5,4,3,2,1,  ITVCI=1, /
```

The XML side just points at the basis file:

```xml
<basis file="f.bas" format="atomci" status="old"/>
<tr record="1"> … </tr>
```

(The generator computes and fills in `nsym`/`nbf`/`nob`/`mpob`. It prints
"`nbf (reading from basis file) = 13 11 6 5`" at run time.)

### 4.2 Quantities derived from the reference configuration (`CLOSED`/`CSFS`/`ITNEL` and the CSF list itself)

From `<orbital>`'s `<frozen_core>` it derives `CLOSED`, and from `<reference>`'s
`<conf>`/`<orb>` it derives `CSFS` and the electron count `ITNEL`, and furthermore
it **generates the SD-CI CSF list itself** (equivalent to `atgen`). By hand you
would have to prepare the orbital list, closed shells, coupling order, and
reference configuration of CARDs 1–6, and expand the excitations.

```xml
<orbital>
  <frozen_core n="1" l="0"/>          <!-- → CLOSED = ' 1S )' -->
  <active id="2S"/><active id="2P"/>
  <outer n="11" l="0"/><outer n="10" l="1"/>
  <outer n="6" l="2"/><outer n="5" l="3"/>
</orbital>
<reference>
  <conf scf="true"><orb id="2S" occ="2"/><orb id="2P" occ="5"/></conf>
</reference>                          <!-- → CSFS=' 2S*2) 2P*5 ))', ITNEL=9 -->
```

From `<atom spin ang>` come `ISPIN` (=`spin`) and `IORB` (=`ang`), and the parity
`IPAR` is also automatically derived from the orbital occupations of the reference
configuration.

### 4.3 Automation of the `NRNFG` execution flags

As in §3.3, it assembles `&CNTL NRNFG(1..8)` from the child-element composition of
`<ctrl>`. There is no need to line up by hand the standard flag row corresponding
to `&WF RULE` (0/1/2) (documented in `namelist.002`).

### 4.4 Automatic filling-in of smart defaults

Although `f.xml`/`fpt.xml` write none of the detailed `&CI` flags, the generated
deck contains the following (the bytecode shows hard-coded values such as
`iconst_m1` (= −1)):

```
 &ci  nrnfg=1,1,1,0,1,1,  ioflg=0,-1,-1,0,0,  … /
```

That is, `NRNFG(6)` (the CI 6 sections) and `IOFLG` (save directive) are
**schema-driven fixed defaults**, not accidental. In addition, `nfaii=18` (the
default `&AI` output unit) and `&get ivcs=27` are also filled in automatically.
This is a convenience but also a constraint — you **cannot change** these (§5.2).

### 4.5 Extensions outside the manual (relativistic flags)

`<ai ifdk3 ifnucl>` are boolean flags for the Douglas–Kroll third-order correction
and the finite-nucleus model that are **not** in the 1994 `&AI` manual; they are
emitted as `&AI IFDK3=`/`IFNUCL=`. In this respect the XML has expressive power
that **exceeds** the documented native `&AI`, corroborating that the tool is newer
than the 1994 version.

---

## 5. What cannot be input (exhaustive and honest)

The result of matching every native group in `docs/namelist.002` item-by-item
against the presence or absence of a corresponding XML binding. **Parameters with
no binding are fixed at their defaults and cannot be changed from XML.**

Legend: ✅ = settable from XML / 🔄 = automatically derived from the high-level
description (not written directly) / ❌ = no corresponding binding, fixed at
default / ⚙ = hard-coded default

### 5.1 Per-group parameter matching table

**`&CNTL`**

| Native | Possible? | XML | Notes |
|-----------|------|-----|------|
| `NRNFG(8)` | 🔄 | presence/absence of `<ctrl>` child elements | Direct numeric specification not possible |
| `TITLE` | ✅ | `<info title>` | |

**`&AI`**

| Native | Possible? | XML | Notes |
|-----------|------|-----|------|
| `Z` | ✅ | `<atom z>` | **Integer only** (§5.5) |
| `NTYPE` | ✅ | `<ai type>` | |
| `IDPRNT` | ✅ | `<ai idprnt>` | |
| `NWT` | 🔄 | (from basis) | Omitted in the generated deck (optional item; warning only) |
| `IUNIT` | 🔄 | (from basis open) | |
| `NPFLG` | ❌ | — | |
| `LOEI` | ❌ | — | Write-buffer length |
| (`IFDK3`/`IFNUCL`) | ✅ | `<ai ifdk3/ifnucl>` | §4.5; outside the manual |

**`&MC`**

| Native | Possible? | XML | Notes |
|-----------|------|-----|------|
| `ITNEL`/`ISPIN`/`IORB`/`IPAR` | 🔄 | `<atom>`+`<reference>` | |
| `CLOSED`/`CSFS` | 🔄 | `<orbital>`+`<reference>` | |
| `IND(4,100)` | ✅ | `<mc><ind>` | Initial-orbital selection |
| `ITMAX`※ | ✅ | `<mc itmax>` | ※Not in `namelist.002` but present in the code |
| (orbital-save record) | ✅ | `<mc out_record>` | |
| `NSET` | ❌ | — | Controls saving of the converged SCF orbitals |
| `IVCS` | ❌ | — | Fixed at default 27 |
| `RULE`/`NPFLG` | ❌ | — | |

**`&WF`**

| Native | Possible? | XML | Notes |
|-----------|------|-----|------|
| `RULE` | ✅ | `<wf rule>` | |
| `NPFLG` | ✅ | `<wf npflg>` | |
| `ITNEL`/`ISPIN`/`IORB`/`IPAR` | 🔄 | `<atom>`+`<reference>` | |
| `IUNIT` | 🔄 | from `<csf>` | |
| `ISMAX` | ❌ | — | Max spin-multiplicity limit for intermediate coupling |
| `IRMAX` | ❌ | — | Max spatial-multiplicity limit for intermediate coupling |
| `LRPS`/`LTRI`/`LWFL`/`LCFC`/`LISL`/`LIJB` | ❌ | — | Buffer lengths |

**CSF list (CARDs 1–6)**

| Native feature | Possible? | Notes |
|---------------|------|------|
| Standard SD-CI CSF generation | 🔄 | Auto-generated from `<orbital>`+`<reference>` |
| CARD 4 symbolic occupations (`A=2,B=1`) | ❌ | **Hand-written macros cannot be passed through** (§5.3) |
| CARD 5 LS-range intermediate-coupling restriction | ❌ | No corresponding attribute in `<orbital>`/`<reference>` |
| `DISPLAY` shell-state listing | ❌ | |

**`&TR`**

| Native | Possible? | XML | Notes |
|-----------|------|-----|------|
| `NSYM`/`NOB`/`NBF`/`MPOB` | 🔄 | (computed from basis) | §4.1 |
| `ITVCI` | ✅ | `<tr record>` | |
| `IUNIT`/`NFAII` | 🔄 | automatic | Beware the collision in §6.1 |
| `NPFLG` | ❌ | — | |

**`&BASVC` (user-supplied transformation coefficients)**

| Native | Possible? | Notes |
|-----------|------|------|
| Entire group | ❌ | **No binding class exists.** The `ITVCI=0` path of "giving the transformation-coefficient matrix inline" is completely inexpressible (§5.3; boron blocker #1) |

**`&GET` (extract coefficients from a saved file)**

| Native | Possible? | XML | Notes |
|-----------|------|-----|------|
| `NIND` | 🔄 | number of `<ind>` | |
| `IND(4,100)` | ✅ | `<tr><ind>` | `record`/`l`/`first`/`last` |
| `IVCS` | ⚙ | — | Fixed at 27 |

**`&PT`**

| Native | Possible? | XML | Notes |
|-----------|------|-----|------|
| `CTHR`/`ETHR`/`HOW` | ✅ | `<pt cthr/ethr/how>` | |
| `NSOLVE` | ✅ | `<pt nstate>` | → `nsolve` output |
| `NRNFG(3)` | ❌ | — | PT 3-section control (default 1,1,1) |
| `ISTATE` | ❌ | — | Target root when HOW=0. Fixed at default 1 |
| `IPS` | ❌ | — | PT diagonalization threshold (default 5) |
| `PTHR`/`NPFLG(3)`/`LTRI` | ❌ | — | |

**`&EX`**

| Native | Possible? | XML | Notes |
|-----------|------|-----|------|
| `RETRY` | ✅ | `<ex retry>` | |
| `NFEXE`/`NFEXW`/`NPFLG`/buffers | ❌ | — | Restart units etc. |

**`&CI`**

| Native | Possible? | XML | Notes |
|-----------|------|-----|------|
| `NSTATE`/`MAXIT`/`NSDIM`/`IPS` | ✅ | `<ci …>` | |
| `NRNFG(6)` | ⚙ | — | `1,1,1,0,1,1` hard-coded |
| `IOFLG(6)` | ⚙ | — | `0,-1,-1,0,0` hard-coded (§5.2) |
| `NFIV` | ❌ | — | Restart from a CI vector |
| `NFTE`/`NPFLG(6)` | ❌ | — | |

**`&RS`**

| Native | Possible? | XML | Notes |
|-----------|------|-----|------|
| `PTHR` | ✅ | `<rs print>` | |
| `RULE` | ⚙ | — | `2` (Brown) hard-coded |
| `NRNFG` | ❌ | — | **The fidelity gap of §5.2** (PT rejected-CSF correction estimate) |
| `NPFLG` | ❌ | — | |

### 5.2 Missing items and fidelity gaps within partially-supported groups

- **`&CI IOFLG`/`NRNFG(6)` fixed**: the CI save directive and section control
  cannot be changed. The default `IOFLG=0,-1,-1,0,0` appends-and-saves the NO
  (`f.NO` is actually written), but writing to a specific record or disabling the
  save is not possible. This limits the fidelity of multi-block restarts (§3.4).
- **`&RS NRNFG` fixed**: the generated `&rs` does not emit `NRNFG` (default 0).
  The native `fpt.stdin` uses `&RS NRNFG=1` (computes the energy-correction
  estimate for the rejected CSFs), but the generated deck **omits** this estimate.
  The SD-CI ENERGY itself matches (the selection was already completed in PTMAIN),
  so the golden value of `fpt.xml` is reproduced, but we note honestly that it is
  not an exact match with the native `fpt.stdin`.
- **PT `ISTATE`/`IPS` missing**: even with `HOW=0` (select by single-root
  contribution), the target root cannot be chosen with `ISTATE` and is fixed at
  root 1. The PT diagonalization threshold `IPS` is also fixed at default.

### 5.3 Completely inexpressible features (including the boron blockers)

1. **`&BASVC` inline transformation coefficients** (no binding at all). The mode
   of **directly giving externally-precomputed SCF orbital vectors** without
   running MCSCF (`NRNFG(2)=0`) is impossible. `samples/native/boron.stdin` carries about
   180 lines of `&BASVC` vectors inline, but there is no XML element corresponding
   to this and no code path that emits `&BASVC`. → **Boron blocker #1**.
2. **Hand-written CSF macro list** (CARD 4's `A=2,B=1` symbols + CARD 5's LS-range
   intermediate-coupling restriction). The generator only **derives** the CSF from
   `<orbital>`/`<reference>`; it does not pass a hand-written list through. The
   `content` attribute of `<csf>` is not used in the deck-generation path (§5.4).
   `ISMAX`/`IRMAX` also have no binding, so the intermediate-coupling restriction
   cannot be expressed either. Boron's `&WF` is a hand-written macro CSF and thus
   cannot be reproduced. → **Boron blocker #2**.

Because of these two points, `samples/native/boron.stdin` cannot be expressed with this
tool. Boron is run by feeding the native deck (`samples/native/boron.stdin`) directly to
`atomci`.

### 5.4 The `content` attribute is not an "escape hatch"

`<basis>`/`<csf>`/`<mcp>`/`<ai>`/`<wf>` have a `content` (element text) getter,
but **the deck generator does not read it**. The bytecode scan shows that only
`org/atomci/msekiya/rel_input/OrbitalXmlMaker` calls `getContent()` — and that is
a separate line (the relativistic / Koga-format input `rel_input` package), which
is unrelated to the deck-generation path of `atgen.Main`. In fact the basis is
read by `namelist.BasisReader` opening a `java.io.File` (a real file is required to
compute `NBF` etc.). Therefore **inline basis and inline CSF do not work in the
generation path**.

### 5.5 Other XML-side constraints

- **`<atom z>` is an integer** (`javap` shows `int getZ()`). A fractional nuclear
  charge (screening models etc.) is inexpressible.
- **Order- and name-dependent** (a Relaxer specification). §6.2.
- The per-step `NAME` (step-specific title) is bound but not reflected in the
  generated deck. §6.4.

---

## 6. Known quirks and pitfalls

### 6.1 `nfaii`/`ivcs` unit collision → SIGFPE

`<tr input_unit="27">` generates `&TR NFAII=27`, which **collides on the same unit**
with `&GET IVCS=27` (natural orbitals) and causes a SIGFPE (exit 136) in TRMAIN.
**Workaround**: **omit** `input_unit` — `nfaii` becomes the native default `18`,
and `ivcs=27` is preserved. For this reason `fpt.xml` does not write `input_unit`
on `<tr>`, and carries only `record="1"` (= `ITVCI=1`).

### 6.2 Relaxer order- and name-dependence

The binding is strict about the **order of appearance** and the **names** of child
elements. Line them up exactly in the order of §3.1. Examples of mistakes:

- `<frozenCore>` (camelCase) → the child element is not parsed. Correct:
  **`<frozen_core>`** (underscore).
- Adding `point`/`spin`/`ang` to `<active>` makes `spliter` expect a delimiter
  format and throw `StringIndexOutOfBounds`. → **Omit** these and use only `id`.
- Making `<title>`/`<output>` child elements nulls out the sibling `<atom>`
  attributes. → These are **attributes** of `<info>` (`<info title="…" output="…">`).
- An empty `<tr/>` → `ArrayIndexOutOfBounds` in `Get.<init>`. → An `<ind>` child
  element is required.

### 6.3 Omitting `<rs>` means no energy is printed

The final `SD-CI ENERGY` line is printed by the RSMAIN step (`NRNFG(8)`). Omitting
`<rs>` gives `NRNFG(8)=0`; the run completes but **no energy summary is printed**.
Always include `<rs>`.

### 6.4 Per-step titles are not reflected

The `title` attribute corresponding to the `NAME` (per-step title) of `&AI`/`&MC`/…
exists in the binding, but is not emitted in the generated deck; each step relies
on a copy of `&CNTL TITLE` (the native default).

---

## References

- `samples/atinputs/README.md` — how to run `f.xml`/`fpt.xml` (the practical
  companion to this document)
- `samples/atinputs/f.xml`, `samples/atinputs/fpt.xml` — verified working examples
- `docs/namelist.002` — the complete parameter table for every native NAMELIST
  (the source of the §5 matching)
