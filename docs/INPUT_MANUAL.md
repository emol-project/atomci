# ATOMCI Input Manual

This manual describes the input of ATOMCI, the non-relativistic
configuration interaction (CI) program for atoms in LS coupling, and of
its two input generators `atgen` and `atinpgen`. It is a user's guide:
it covers every input that a normal calculation needs, explains how the
pieces fit together, and walks through the shipped examples.

- The complete parameter-by-parameter reference, including the rarely
  used buffer sizes, unit numbers and debug flags, is the original 1994
  manual, kept and corrected in [`namelist.002`](namelist.002) (with
  [`atomci.002`](atomci.002), [`file.002`](file.002) and
  [`appendix.002`](appendix.002), the error codes).
- The `.inp` format of `atinpgen` is specified in full in
  [`ATINPUTS_PY.md`](ATINPUTS_PY.md).
- Building, installing and checking the build: [`../INSTALL.md`](../INSTALL.md).
- The theory: F. Sasaki, Int. J. Quantum Chem. 8, 605 (1974), and
  F. Sasaki, M. Sekiya, T. Noro, K. Ohtsuki and Y. Osanai, in *Methods and
  Techniques in Computational Chemistry: METECC-94*, E. Clementi ed.
  (Cagliari, 1993), pp. 163–219.

This manual covers the spin-free Hamiltonian only, which is all that
ATOMCI computes. Spin-dependent operators (fine structure, hyperfine
structure, g factors) are not part of this program.

**Two input forms.** A calculation is given either as a **NAMELIST deck**,
the program's own input (§§3–15), or as an **`.inp` file**, from which
`atinpgen` writes the deck and its CSF list (§16). The deck can express
everything; the `.inp` form covers SCF/MCSCF and single- or
multi-reference SD-CI, with or without perturbative selection, in GTF or
STF basis sets, over any number of passes, and takes raw NAMELIST
blocks for the rest. Every shipped example exists in both forms
(`samples/native/` and `samples/inp/`, each a closed set of inputs). A walk-through
from `git clone` to checking the answers is [`TUTORIAL.md`](TUTORIAL.md).

## Contents

1. [What a calculation consists of](#1-what-a-calculation-consists-of)
2. [Running the programs](#2-running-the-programs)
3. [The input deck](#3-the-input-deck)
4. [The file header (`OPEN` … `END`)](#4-the-file-header-open--end)
5. [`&CNTL` — the run](#5-cntl--the-run)
6. [`&AI` and the basis set](#6-ai-and-the-basis-set)
7. [`&MC` — SCF and MCSCF orbitals](#7-mc--scf-and-mcscf-orbitals)
8. [`&WF` and the CSF list](#8-wf-and-the-csf-list)
9. [`&TR`, `&BASVC`, `&GET` — the orbitals of the CI](#9-tr-basvc-get--the-orbitals-of-the-ci)
10. [`&PT` — perturbative selection](#10-pt--perturbative-selection)
11. [`&EX` — the energy expression](#11-ex--the-energy-expression)
12. [`&CI` — diagonalization, density, natural orbitals](#12-ci--diagonalization-density-natural-orbitals)
13. [`&RS` — analysis and summary](#13-rs--analysis-and-summary)
14. [Several passes in one deck, and restarts](#14-several-passes-in-one-deck-and-restarts)
15. [`atgen` — the SD-CI CSF list](#15-atgen--the-sd-ci-csf-list)
16. [`atinpgen` — decks from a short description](#16-atinpgen--decks-from-a-short-description)
17. [Reading the output](#17-reading-the-output)
18. [Limits and pitfalls](#18-limits-and-pitfalls)
19. [Worked examples](#19-worked-examples)
- [Appendix A. Files and unit numbers](#appendix-a-files-and-unit-numbers)
- [Appendix B. Quick reference](#appendix-b-quick-reference)

---

## 1. What a calculation consists of

ATOMCI works with configuration state functions (CSFs) of definite
total L, S and parity, built from shells *nl^w* coupled one after
another in LS coupling. The Hamiltonian matrix elements between CSFs are
obtained from the vacuum expectation values of tensor operators and
recoupling coefficients (Sasaki 1974; METECC-94), with a formula-tape
("energy expression") approach: the angular part of every matrix element
is written once to a file as a list of coefficients and integral labels,
and the matrix is assembled from that file and the transformed integrals.

A run is divided into eight steps. Each step is switched on or off in
`&CNTL` and reads its own NAMELIST group:

| # | Step | NAMELIST | What it does |
|---|---|---|---|
| 1 | AIMAIN | `&AI` | Integrals over the basis functions (STF or GTF). |
| 2 | MCMAIN | `&MC` | SCF or MCSCF orbitals; saves them to the orbital file. |
| 3 | WFMAIN | `&WF` | Reads the CSF list, generates the CSFs, writes the energy expression (SD-CI) or the CSF file. |
| 4 | TRMAIN | `&TR` (+ `&BASVC` or `&GET`) | Transforms the integrals to the orbitals of the CI. |
| 5 | PTMAIN | `&PT` | Perturbative selection of CSFs (optional). |
| 6 | EXMAIN | `&EX` | Energy expression for a general CI or for the selected CSFs. |
| 7 | CIMAIN | `&CI` | Hamiltonian matrix, diagonalization, density matrix, natural orbitals. |
| 8 | RSMAIN | `&RS` | Analysis of the CI vector, energy estimates, summary. |

The steps exchange data through files (Fortran units). Any sequence of
steps can therefore be run, stopped and continued, as long as the files
of the earlier steps are present (§14).

Three kinds of CI are available, chosen by `&WF RULE`:

| `RULE` | Calculation | Steps (`&CNTL NRNFG`) |
|---|---|---|
| 0 | General CI over a CSF list given by the user | `1,1,1,1,0,1,1,1` |
| 1 | SD-CI: single and double excitations from one or several references (the CSFs that interact with a reference, see below) | `1,1,1,1,0,0,1,1` |
| 2 | SD-CI with perturbative selection of the CSFs | `1,1,1,1,1,1,1,1` |

These are the settings for a calculation from scratch. Set `NRNFG(2)=0`
if no SCF/MCSCF is wanted (orbitals given in the deck or taken from an
earlier run), and `NRNFG(1)=0` if the integral file exists already.

**Which CSFs an SD-CI keeps.** For `RULE` 1 and 2, WFMAIN generates every
CSF of the configurations in the list and then keeps only the CSFs with
a non-zero Hamiltonian matrix element with the reference CSFs (routine
`WFETAP`); the others are dropped before the CI. With two or more open
shells outside the references this is a smaller space than all CSFs of
the SD configurations. For `samples/native/c` (C ³P, two references) it
keeps 92 of the 147 CSFs and gives −37.779409 hartree. A general CI
(`RULE=0`) over all 147 CSFs of the same configurations gives
−37.780160, the value of a determinant SD-CI over the same
configurations on the same orbitals. To keep every CSF, write the list
with `atgen` CARD 6 set to `0` and run it with `RULE=0` and an `&EX`
group.

## 2. Running the programs

After `make && make install` (see [`../INSTALL.md`](../INSTALL.md)),
`$ATOMCI_HOME/bin` contains

| Program | Purpose |
|---|---|
| `atomci` | The CI program. Reads the deck from standard input, writes the listing to standard output. |
| `atgen` | Writes the CSF list of an SD-CI from a short description (§15). |
| `atinpgen` | Writes a complete deck and its CSF list from an `.inp` file (§16). |
| `fpl` | The Fortran preprocessor used by the build (not needed to run). |

and `$ATOMCI_HOME/CFPTBL` is the table of coefficients of fractional
parentage, read by every run.

Run each calculation in its own, empty work directory. ATOMCI opens
the files named in the deck relative to the current directory and keeps
its intermediate files there as `fort.N`:

```sh
export ATOMCI_HOME=/path/to/install       # the line `make install` prints
mkdir -p ~/runs/f && cd ~/runs/f
ln -sf "$ATOMCI_HOME/CFPTBL" CFPTBL
cp "$repo/samples/native/f.bas" .
"$ATOMCI_HOME/bin/atgen"  < "$repo/samples/native/f.atg"      # writes f.csf
"$ATOMCI_HOME/bin/atomci" < "$repo/samples/native/f.stdin" > f.output
```

A second, unrelated run in the same directory finds the old `fort.*`
files and appends to some of them (an extra vector set in the output,
for example). Use a fresh directory unless the second run is meant to
continue the first (§14).

## 3. The input deck

A deck consists of

1. an optional file header, `OPEN` lines ending with `END` (§4);
2. `&CNTL`, which says which steps run;
3. one NAMELIST group for each step that runs, **in the order of the
   steps**: `&AI`, `&MC`, `&WF`, `&TR`, `&PT`, `&EX`, `&CI`, `&RS`.
   `&TR` is followed by `&BASVC` or `&GET`;
4. data cards directly after a group when that group reads them from
   standard input (`IUNIT=5`): the basis after `&AI`, the CSF list after
   `&WF`, the orbital coefficients after `&BASVC`;
5. optionally a further `&CNTL` and its groups, for a second pass in the
   same run (§14).

A group must be present for every step that `&CNTL NRNFG` switches on
(a missing group stops the run). A step that is switched off reads
nothing; leave its group out.

**NAMELIST syntax.** The groups are standard Fortran NAMELIST input.
A group starts with `&NAME` and ends with `/` (or `&END`, as in the 1994
manual). Values are separated by commas; arrays are given as
comma-separated lists (`NBF=13,11,6,5`) and may continue over several
lines; character values are quoted (`TITLE=' F DOUBLET P '`). Names are
not case-sensitive. Reals may be written `9.0D0` or `9.0`.

**Comments.** A line beginning with `"` is a comment. Text that is not
part of a group and stands before the next `&` is skipped by the
NAMELIST reader; the samples use this for a line of notes before
`&CNTL`. Do not put such text between a group and its data cards.

**Angular momenta and spin** are given as multiplicities throughout:
`ISPIN` = 2S+1 and `IORB` = 2L+1 (1 for S, 3 for P, 5 for D, …).
Parity `IPAR` is 0 (even) or 1 (odd).

A minimal deck for an SD-CI on SCF orbitals (from `samples/native/f.stdin`):

```
OPEN UNIT=10 FILE=./CFPTBL BINARY STATUS=OLD
OPEN UNIT=27 FILE=f.NO BINARY
OPEN UNIT=2 FILE=f.csf STATUS=OLD
OPEN UNIT=3 FILE=f.bas STATUS=OLD
END
 &CNTL NRNFG=1,1,1,1,0,0,1,1, TITLE=' F DOUBLET P ', /
 &AI IUNIT=3, Z=9.0D0, NTYPE=2, /
 &MC ITNEL=9, ISPIN=2, IORB=3, IPAR=1, NSET=1,
     CLOSED='  1S )',
     CSFS=' 2S*2) 2P*5 ))',
          ' )))', /
 &WF ITNEL=9, ISPIN=2, IORB=3, IPAR=1, RULE=1, IUNIT=2, /
 &TR NSYM=4, NBF=13,11,6,5, NOB=13,11,6,5,
     MPOB=13,12,11,10,9,8,7,6,5,4,3,2,1,
          11,10,9,8,7,6,5,4,3,2,1,
          6,5,4,3,2,1,
          5,4,3,2,1,  ITVCI=1, /
 &GET IVCS=27, NIND=4,
      IND= 1,0,1,13, 1,1,1,11, 1,2,1,6, 1,3,1,5, /
 &CI NSTATE=1, NSDIM=100, IPS=7, NRNFG=1,1,1,0,1,1,
     MAXIT=100, IOFLG=0,-1,-1,0,0, /
 &RS RULE=2, PTHR=-0.001, /
```

Sections 5–13 describe the groups in this order.

## 4. The file header (`OPEN` … `END`)

The first lines of the deck may assign files to Fortran units. Each line
is one command; keywords are upper case:

| Keyword | Meaning |
|---|---|
| `OPEN UNIT=n FILE=name` | Open file `name` on unit `n`. |
| `STATUS=OLD` / `NEW` / `UNKNOWN` | As in Fortran `OPEN` (default `UNKNOWN`). |
| `BINARY` | Unformatted file (the CFP table, orbital files, energy expressions). |
| `SCRATCH` | Unformatted scratch file, deleted at the end. |
| `END` | End of the header; the ATOMCI input follows. |

A line whose first non-blank character is `"`, `#` or `/` is a comment.
`OPEN UNIT=5 FILE=name` switches standard input to `name`: the rest of
the current input is then ignored and no `END` is needed.

Units not named in the header are opened by Fortran as `fort.N` in the
work directory. In practice the header names only the files that the
user supplies or wants to keep:

| Unit | Usual file | Needed when |
|---|---|---|
| 10 | `CFPTBL` (`BINARY STATUS=OLD`) | always |
| 3 | basis set (`STATUS=OLD`) | `&AI IUNIT=3` |
| 2 | CSF list (`STATUS=OLD`) | `&WF IUNIT=2` |
| 27 | orbital file (`BINARY`) | to keep the SCF/MCSCF orbitals and the natural orbitals, or to read them in a later run (`&GET IVCS=27`) |
| 7 | step log (return codes and times) | optional |

`atgen` reads the same header; there it is usually a single line
`OPEN UNIT=7 FILE=name.csf` that sends the CSF list to a file.

## 5. `&CNTL` — the run

| Parameter | Default | Meaning |
|---|---|---|
| `NRNFG(8)` | `0,0,0,0,0,0,0,0` | Run flags of the eight steps AI, MC, WF, TR, PT, EX, CI, RS (1 = run, 0 = skip). See the table in §1. |
| `TITLE` | blank | Title of the run, up to 72 characters. Copied to the title of every step. |

`&CNTL` also accepts the unit numbers of all intermediate files
(`NFAII`, `NFTRI`, `NFEXE`, …; Appendix A). They are needed only to
redirect files in a restart. Leave them at their defaults otherwise.

```
 &CNTL NRNFG=1,0,1,1,0,1,1,1, TITLE=' B (DOUBLET P ODD) ', /
```

runs all steps except MCSCF and PT (general CI on orbitals given in the
deck).

## 6. `&AI` and the basis set

### 6.1 `&AI`

| Parameter | Default | Meaning |
|---|---|---|
| `Z` | — | Nuclear charge (real). |
| `NTYPE` | 1 | Basis type: 1 Slater-type functions (STF), 2 Gaussian-type functions (GTF). |
| `IUNIT` | 5 | Unit from which the basis is read: 5 = directly after `&AI` in the deck; otherwise a file opened in the header (the samples use 3). |
| `NWT` | — | Number of basis functions. Only checked against the maximum (150); a different actual count gives a warning. May be omitted. |
| `IDPRNT` | 0 | 1 = echo the basis input. |

`NTYPE=3` (model-core-potential basis, library on unit `NFMCP`=44) and
`NTYPE=4` (Douglas–Kroll basis, DK3 or DK2 by `IFDK3`, finite or point
nucleus by `IFNUCL`) exist in the code but are not used by any shipped
example; see [`namelist.002`](namelist.002).

### 6.2 STF basis (`NTYPE=1`)

Pairs of *orbital type* and *exponent*, in free format, ending with `))`.
The orbital type is the principal quantum number and l of the Slater
function r^(n−1) e^(−ζr):

```
 1S  7.33800  1S  3.99600
 2S  1.72400  2S  1.11000
 2P  5.50900  2P  2.15500  2P  1.24300
 3D 24.8776   3D 17.5938
 ))
```

Functions of the same l form one symmetry block. l ≤ 9.

### 6.3 GTF basis (`NTYPE=2`)

One block per contracted function: the l symbol, the number of
primitives *k*, a scale factor, then *k* exponents and *k* contraction
coefficients. Line breaks are free. The list ends with `))`.

```
  S  5  1.0
    103109.464234  15281.006720   3441.539198   967.094830   314.035338
         0.001279      0.010054      0.053329     0.223868     0.781481
  S    1  1.0  113.442296  1.000000
  P  2  1.0
  245.330287        56.919005
    0.101258         0.941620
  P  1  1.0     17.604568  1.000000
 ))
```

l ≤ 7. The contracted functions of one l, in the order given, are the
basis of that symmetry; their number per l is what `&TR NBF` must
contain (§9).

Two restrictions of the reader (it is the original free-format card
reader):

- **Numbers must be in fixed-point form.** An exponent field
  (`8.147221E-06`) stops the run with `BASORB FORMAT ERROR`. Write
  `0.000008147221`; any number of digits is read into double precision,
  so nothing is lost.
- **Lines are read up to column 80.** Characters beyond column 80 are
  dropped without a message. Keep the lines short.

A line beginning with `"` is a comment (the `f.bas` sample uses this to
switch functions off). `samples/native/make_basis.py` writes a basis in this
format from the PySCF basis library.

## 7. `&MC` — SCF and MCSCF orbitals

`&MC` defines the configurations of an SCF or a small MCSCF and saves
the converged orbitals to the orbital file (unit `IVCS`, default 27).
The CI then takes its orbitals from that file with `&GET` (§9).

| Parameter | Default | Meaning |
|---|---|---|
| `ITNEL` | — | Number of electrons. |
| `ISPIN` | — | 2S+1. |
| `IORB` | — | 2L+1. |
| `IPAR` | — | Parity: 0 even, 1 odd. |
| `CLOSED` | — | The closed shells, ending with `)`: `'  1S 2S 2P )'`. |
| `CSFS(20)` | — | The configurations of the open shells, one per array element, the last element `' )))'`. Syntax below. |
| `NSET` | 0 | Where the converged orbitals are written in file `IVCS`: −1 not at all, 0 appended after the last record, *n* to record *n* (records after *n* are lost). The samples use `NSET=1`. |
| `IVCS` | 27 | Unit of the orbital file. |
| `ITMAX` | 99 | Maximum number of MCSCF macro-iterations. |
| `ETHR` | 1.0D-7 | Convergence threshold on the energy change. |
| `C2THR` | 1.0D-6 | Convergence threshold on the change of the CI coefficients. Both must be met. |
| `NSOL` | 1 | Number of roots solved together. |
| `NIND`, `IND(4,100)` | 0 | Starting orbitals from the orbital file, as in `&GET` (§9.3). If absent, the program generates starting orbitals itself. |
| `NOPT(150)` | all 1 | Orbitals to optimize: `NOPT(i) ≤ 0` keeps orbital *i* fixed. |

**The configurations.** Each array element of `CSFS` holds one
configuration of the open shells:

1. The shells must be written **in the coupling sequence: by l (S, P, D,
   …), and by n within the same l.** So `4S` comes before `3D`:
   `' 4S*2) 3D*1 ))'`, not `' 3D*1) 4S*2 ))'`. A shell out of this order
   stops MCMAIN with `=== shell  4S follows a D shell: ...` (return code
   99).
2. `*n` after a shell gives its occupation.
3. `)` closes a shell; `))` closes the configuration.
4. One configuration per array element.
5. The element `' )))'` ends the list.

The MCSCF is restricted: the configurations should differ from each
other by an even number of electrons in each shell (as in a 2s² ↔ 2p²
pair). For one configuration it is an open-shell SCF for the given term.

```
 &MC ITNEL=21, ISPIN=2, IORB=5, IPAR=0, NSET=1, ITMAX=30,
     CLOSED='  1S 2S 2P 3S 3P )',
     CSFS=' 4S*2) 3D*1 ))',
          ' )))', /
```

is the SCF of Sc 3d 4s² ²D (`samples/native/sc.stdin`). The converged energy
is printed as `Total Energy = … a.u.`.

## 8. `&WF` and the CSF list

### 8.1 `&WF`

| Parameter | Default | Meaning |
|---|---|---|
| `RULE` | 1 | 0 general CI, 1 SD-CI, 2 SD-CI with perturbative selection (§1). |
| `ITNEL`, `ISPIN`, `IORB`, `IPAR` | — | Electrons and the target term, as in `&MC`. |
| `IUNIT` | 5 | Unit of the CSF list: 5 = directly after `&WF`; otherwise a file opened in the header (usually 2, the output of `atgen`). |
| `ISMAX` | 21 | Largest intermediate 2S+1 kept while coupling the shells. |
| `IRMAX` | 31 | Largest intermediate 2L+1 kept while coupling the shells. |
| `NPFLG` | 0 | Print level: 0 the references only, 1 the configuration types, 2 every CSF and the input. Larger values are for debugging. |

If WFMAIN stops because a buffer is too small, it names the parameter
to enlarge (`LRPS`, `LTRI`, `LWFL`, `LCFC`, `LISL`, `LIJB`; see
[`namelist.002`](namelist.002)).

### 8.2 The CSF list

The list is a sequence of cards in free format. Lines beginning with
`"` are comments. For an SD-CI it is written by `atgen` (§15); it has to
be typed only for a general CI or to restrict intermediate couplings.

**CARD 1 — the orbitals.** All orbitals that occur in the configurations,
frozen core included, ending with `)`. The usual order is: virtual
orbitals (by l), valence orbitals (by l), closed shells. Commas may
separate the labels. The principal quantum numbers of virtual orbitals
are labels only; they need not be related to the radial functions.

```
 3S,4S,5S,6S,7S,8S,
 3P,4P,5P,6P,7P,8P,
 3D,4D,5D,6D,7D,8D,
 1S,2S,2P)
```

**CARD 2 — closed shells.** Shells doubly occupied in every CSF, which
are therefore not written in the configurations, ending with `)`. At
least one closed shell must be given. An open shell must appear in every
configuration, even if no electron is excited from it.

```
 1S)
```

**CARD 3 — coupling order.** The order in which the shells are coupled.
`))` means the order of CARD 1.

**CARD 4 — symbolic occupations (optional).** Definitions such as
`A=2, B=1`. A configuration may then use `2S*A`, `2P*B-1`, … This lets
the same list serve atoms with different numbers of valence electrons.

**CARD 5 — the configurations.** Each configuration is a sequence of
shells; each shell is

```
<orbital list>*<occupation>[, <S range>, <L range>] )
```

and the configuration ends with `))`. The whole list ends with `)))`.

- `<orbital list>` is one orbital or several orbitals of the same l:
  `3 4 5P*1` (or `3,4,5P*1`) means one electron in 3p **or** 4p **or**
  5p, and generates all three.
- `<occupation>` is a number, or a symbol of CARD 4 with an optional
  `+n` / `-n`.
- The optional ranges restrict the intermediate state after this shell
  is coupled: the S range as multiplicities (`1-3`: singlets and
  triplets), the L range as letters (`S-P`: S and P), lower limit first,
  S range before L range. Either may be omitted (`2S*A-1,1-1)` restricts
  the spin only). `samples/native/boron.stdin` also uses the short form `,1S`
  for an intermediate ¹S. Only intermediate states inside the ranges and
  allowed by the Pauli principle are kept.
- Blanks inside a shell are ignored; shells are separated by `)` and at
  least one blank.

For `RULE > 0` the reference configurations come first and are
separated from the rest by one extra `)` line:

```
 2S*2) 2P*4))
 2S*2) 2P*3) 3P*1))
 )
 2S*2) 2P*2) 3P*2))
 ...
 )))
```

Examples of shells:

| Shell | Meaning |
|---|---|
| `1S*2` | 1s² |
| `3 4 5P*1` | one electron in 3p, 4p or 5p |
| `2S*0` | 2s empty |
| `3 4 5 6D*A` | A electrons in 3d…6d (A defined in CARD 4) |
| `3 4 5D*1, 1-1,S-S` | one d electron, coupled with the preceding shells to ¹S only |

The restriction `3S*1) 3S*1, 1-1,S-S)` in place of `3S*2)` is not
allowed (a shell is not split).

A few rules:

- One line of CARD 5 generates at most 800 CSFs.
- Duplicate CSFs are not detected here; they make the run stop later in
  WFMAIN or EXMAIN.
- Writing `DISPLAY` at the start of the list prints the shell states
  available in the LSQ (orbital, spin, quasispin) scheme.
- Ranges also save time when they only exclude intermediate states that
  could not couple to the target term anyway.

The general-CI list of `samples/native/boron.stdin` (B ²Pᵒ, `RULE=0`) shows
every feature: comma-separated orbital lists, `A`/`B` symbols, ranges on
the intermediate couplings, and lines with an empty first column for the
configurations without a virtual electron.

## 9. `&TR`, `&BASVC`, `&GET` — the orbitals of the CI

### 9.1 `&TR`

TRMAIN transforms the integrals to the orbitals used in the CI. The
orbitals are given per symmetry (l = 0, 1, 2, …) as coefficients over the
basis functions of that l.

| Parameter | Default | Meaning |
|---|---|---|
| `NSYM` | — | Number of symmetries (s, p, d, … up to the highest l in the basis). |
| `NBF(NSYM)` | — | Number of basis functions per symmetry. |
| `NOB(NSYM)` | — | Number of orbitals per symmetry. |
| `MPOB(ΣNOB)` | — | For each orbital of CARD 1 of the CSF list, symmetry by symmetry in the order of CARD 1, its position among the orbitals of that symmetry in the coefficient set. **Give it in every pass**: if it is missing the program uses the identity ordering and prints a `*WARNING*`. |
| `ITVCI` | — | Where the coefficients come from: 0 from the deck (`&BASVC` follows), 1 from the orbital file of an earlier step or run (`&GET` follows). |

`MPOB` connects the labels of the CSF list with the coefficient vectors.
The s orbitals of CARD 1 are taken in the order in which they appear
there, then the p orbitals, and so on. With the CARD 1 order
`12S 11S … 2S … 1S` and `MPOB=4,3,2,1, …`, `12S` is the 4th s vector of
the coefficient set, `11S` the 3rd, `2S` the 2nd and `1S` the 1st. A
CSF list written by `atgen` puts the correlating orbitals first, highest
label first, then the occupied and the core orbitals; the coefficient
sets hold the core and occupied orbitals first. Hence the descending
`MPOB` sequences of the samples: in `f.stdin` the s block is
`MPOB=13,12,…,1`.

The remaining parameters of `&TR` (buffer lengths and units) are not
needed in normal use. Leave `ITRNS` at its default 2 and `NPFLG` at 0:
other values need a file that no step writes (§18).

### 9.2 `&BASVC` — coefficients in the deck (`ITVCI=0`)

| Parameter | Default | Meaning |
|---|---|---|
| `IUNIT` | 5 | Unit of the coefficients; 5 = directly after `&BASVC`. |
| `IDPRNT` | 0 | Print flag of the input echo. |

The coefficients follow in free format: for each symmetry, for each
orbital, the `NBF` coefficients over the basis functions; each symmetry
block ends with `)`. The block of symmetry *i* thus has `NOB(i)·NBF(i)`
numbers. Extra `)` after the last block are ignored.

```
 &BASVC IUNIT=5, /
 1, 0, 0, 0,
 0, 1, 0, 0,
 0, 0, 1, 0,
 0, 0, 0, 1,  )
 1, 0,
 0, 1,  )
```

(Here `NBF=NOB=4,2`: unit coefficients for an s and a p block.)

### 9.3 `&GET` — coefficients from the orbital file (`ITVCI=1`)

The orbital file (unit 27 by default) is a sequence of records, each a
complete set of orbitals: the SCF/MCSCF orbitals written by `&MC NSET`,
the natural orbitals written by `&CI IOFLG(5)`, or the coefficients read
from `&BASVC` in an earlier run. `&GET` picks orbitals from these records.

| Parameter | Default | Meaning |
|---|---|---|
| `IVCS` | 27 | Unit of the orbital file. |
| `NIND` | — | Number of quartets in `IND`. |
| `IND(4,NIND)` | — | Quartets `a, l, c, d`: orbitals `c` to `d` of symmetry `l` (0 = s, 1 = p, …) are taken from record `a`. Together the quartets must cover all `NOB` orbitals of every symmetry. |
| `NBASE` | 0 | Added to every record number `a` (to reuse an `IND` table on another file). |

```
 &GET IVCS=27, NIND=6,
      IND= 2,0,1,2,  2,0,3,13, 2,1,1,1, 2,1,2,11,
           2,2,1,6,  2,3,1,5, /
```

takes all orbitals from record 2 (the natural orbitals of the first
pass of `f.stdin`). Orbitals of one symmetry may come from different
records: `IND=1,0,1,2, 2,0,3,4, …` takes s orbitals 1–2 from record 1 and
3–4 from record 2.

## 10. `&PT` — perturbative selection

With `&WF RULE=2` and `NRNFG(5)=NRNFG(6)=1`, PTMAIN estimates the
contribution of every CSF of the SD space to the energy, by second-order
perturbation theory on an effective Hamiltonian of the references, and
keeps only the important ones. EXMAIN and CIMAIN then work on the
selected CSFs, and RSMAIN (`&RS NRNFG>0`) estimates the energy of the
rejected ones.

| Parameter | Default | Meaning |
|---|---|---|
| `NSOLVE` | 1 | Number of roots of the effective Hamiltonian. |
| `ISTATE` | 1 | The root used for the selection when `HOW=0` (≤ `NSOLVE`). |
| `HOW` | 0 | Selection by the contribution to root `ISTATE` (0), by the average over the `NSOLVE` roots (1), or by the maximum (2). |
| `ETHR` | 1.0D-4 | Energy threshold (hartree). Contributions are summed from the smallest upwards; the CSFs whose cumulative sum stays below `ETHR` are rejected, the rest selected. Single excitations from the references are always kept. |
| `CTHR` | 1.0D-3 | A CSF whose contribution exceeds `CTHR` is always kept. Use a value at most ten times `ETHR`. |
| `IPS` | 6 | Convergence of the Davidson diagonalization: 10^(−IPS). |
| `PTHR` | −1.0 | −1 prints the list of selected CSFs, 1 suppresses it. |
| `NRNFG(3)` | `1,1,1` | Run flags of the three sections: effective Hamiltonian, diagonalization, energy analysis. |

```
 &PT NSOLVE=1, ISTATE=1, ETHR=0.001, CTHR=0.01, HOW=0, /
```

(`samples/native/fpt.stdin`).

## 11. `&EX` — the energy expression

EXMAIN writes the energy expression of a general CI (`RULE=0`) or of
the CSFs selected by PTMAIN (`RULE=2`). For `RULE=1` the expression is
written in WFMAIN and EXMAIN is not run.

| Parameter | Default | Meaning |
|---|---|---|
| `RETRY` | 0 | 1 = restart after a run stopped inside EXMAIN; the incomplete expression is on unit `NFEXW`. |
| `NFEXW` | 0 | Unit of the incomplete expression (for `RETRY=1`; the documented example uses 14). |
| `NFEXE` | 15 | Unit of the complete expression. |

A normal deck has `&EX RETRY=0, /`. A restart:

```
 &EX RETRY=1, NFEXW=14, NFEXE=15, /
```

The energy expression is the most expensive part of a large CI; this is
the step that `RETRY` exists for.

## 12. `&CI` — diagonalization, density, natural orbitals

| Parameter | Default | Meaning |
|---|---|---|
| `NRNFG(6)` | `1,1,1,0,1,1` | Sections: 1 Hamiltonian matrix, 2 diagonalization, 3 density matrix, 4 unused (keep 0), 5 natural orbitals, 6 summary file for RSMAIN. |
| `NSTATE` | 1 | Number of roots. |
| `MAXIT` | 1000 | Maximum number of Davidson iterations. |
| `IPS` | 6 | Convergence threshold 10^(−IPS) on the norm of the correction vector. |
| `NSDIM` | 400 | Initial vectors from the diagonalization of the leading `NSDIM`×`NSDIM` block (0 = unit vector). If `NSDIM` is not smaller than the dimension of the CI, the full matrix is diagonalized directly. |
| `NFIV` | 0 | Unit of a CI vector from an earlier run used as the initial vector (usually 37). Overrides `NSDIM`. For a restart after a run that did not converge. |
| `IOFLG(6)` | `0,-1,-1,0,0,0` | Saving: element 2 the CI vectors and element 3 the density matrices (both on unit `NFCIW`=28), element 5 the natural orbitals (on unit `NFCIC`=27, the orbital file). −1 = do not save, 0 = append after the last record, *n* = write to record *n* (later records are lost). |
| `XREF(20)` | 0 | Reference energy of each state, printed beside the CI energy as `E (REFERENCE)`. |
| `THRCSF` | 0.001 | Coefficients larger than this are listed after the diagonalization. |

`IOFLG(2)` and `IOFLG(3)` write to the same file: when both are saved,
both must be 0 (append). `n,n`, `n,0` and `0,n` with a record number *n*
are invalid. With the default, the natural orbitals are appended to
the orbital file after every CI, so a later pass can start from them
with `&GET` (§14).

Keep `IDTYP` at its default `0,0`: the CSF selection it would switch on
was never implemented and stops the run.

```
 &CI NSTATE=1, NSDIM=100, IPS=7, NRNFG=1,1,1,0,1,1,
     MAXIT=100, IOFLG=0,-1,-1,0,0, /
```

## 13. `&RS` — analysis and summary

RSMAIN reads the summary file of CIMAIN (unit 71), analyses the CI
vector and prints the summary of the run.

| Parameter | Default | Meaning |
|---|---|---|
| `NRNFG` | 0 | 0 for `RULE` 0 or 1. >0 for `RULE=2`: also estimate the energy of the CSFs rejected by PTMAIN. |
| `RULE` | 2 | Estimate of the energy contributions: 1 Bunge's method, 2 Brown's formula. Bunge's method needs references; without them the program uses 2. |
| `PTHR` | 0.001 | Print threshold of the contributions: >0 prints all, <0 prints only those larger than \|PTHR\|. |

```
 &RS RULE=2, PTHR=-0.001, /
```

Without `&RS` the run ends without the `SD-CI ENERGY` lines of the
summary.

## 14. Several passes in one deck, and restarts

After `&RS` (or after the last group of the pass), a new `&CNTL` starts
a further pass in the same run, with its own run flags and groups. The
files of the earlier passes stay available. `samples/native/f.stdin` has three
passes:

1. `NRNFG=1,1,1,1,0,0,1,1`: integrals, SCF (orbitals to record 1 of
   `f.NO`), SD-CI on the SCF orbitals (`&GET` from record 1), natural
   orbitals appended as record 2.
2. `NRNFG=0,0,0,1,0,0,1,1`: transformation to the natural orbitals
   (`&GET` from record 2) and the same SD-CI again. The integrals and
   the energy expression of pass 1 are reused.
3. `NRNFG=0,0,0,0,0,0,0,1`: RSMAIN only, now with `RULE=1` (Bunge).

**Restate every parameter in each pass.** Some values carry over from
the previous pass, others do not (`&TR MPOB` in particular is reset
before every `&TR`). Write each group of a pass completely.

**Restarts.** Because the steps communicate through files, a run can be
continued from any step by switching off the steps already done and
keeping the work directory:

| Continue from | Files that must exist (default units) |
|---|---|
| AIMAIN, MCMAIN, WFMAIN | none — start from the beginning |
| TRMAIN | AO integrals (18) |
| PTMAIN | energy expression for PT (14), transformed integrals (16) |
| EXMAIN | CSF list (11, from WFMAIN or PTMAIN); after a stop inside EXMAIN use `&EX RETRY=1` |
| CIMAIN | transformed integrals (16), coefficients (27), energy expression (15); for later sections also the CI vector (37) and the matrix (38, 39) |
| RSMAIN | CI summary (71); for `RULE=2` also 11, 32, 33 |

With `RULE=1`, a run that stopped inside WFMAIN can be continued from
EXMAIN: `NRNFG(3)=0`, `NRNFG(6)=1`, `&EX RETRY=1`.

A CI that did not converge in `MAXIT` iterations can be continued from
its last vector with `&CI NFIV=37`.

## 15. `atgen` — the SD-CI CSF list

`atgen` generates all single and double excitations from the
references into a set of correlating orbitals and writes them as a CSF
list for `&WF` (`RULE` 1 or 2; or `RULE` 0 for a further step). It checks
the parity of each configuration but not its L and S: configurations
that cannot give the target term are dropped later by WFMAIN, which also
drops the CSFs without a matrix element with the references (§1).

The input is a series of free-format cards. Each of CARDs 1–4 ends with
`)))`. A line with `"` in column 1 is a comment. A typical input
(`samples/native/f.atg`):

```
OPEN UNIT=7 FILE=f.csf
END
" INPUT DATA OF ATGEN.  # OF CORRELATING ORBITALS.
  11S 10P 6D 5F )))
" SHELL ( OCCUPIED ORBITALS )
   2S    2P  )))
" REF.
   2S*2)  2P*5))
   )))
" ORDER OF COUPLING
  2S 2P  )))
   1S
   -1
```

| Card | Contents |
|---|---|
| 1 | **Correlating orbitals:** their *number* per l, in order s, p, d, …: `11S 10P 6D 5F` means 11 s, 10 p, 6 d and 5 f correlating orbitals. Every l below the highest must have at least one. Fewer than 40 per l. |
| 2 | **Occupied orbitals** of the references, by n and l, without the frozen core. Orbitals with l > 3 cannot be occupied. |
| 3 | **References**, with the conventions of `&MC CSFS`: `2S*2) 2P*5))` per reference, the list ending with `)))`. |
| 4 | **Coupling order** of the shells of CARD 2 (any order may be chosen; `)` alone = the order of CARD 2). The same order must be used in the ATOMCI run. |
| 5 | **Frozen core:** the shells with no excitation, e.g. `1S`, or `1S 2S 2P 3S 3P`. No terminator. |
| 6 | `-1`: put a `)` between the references and the excitations (required for `RULE > 0`). `0`: no separator (for a general CI or a further `atgen` run). |

The correlating orbitals are numbered from 11 upwards in the output
(`12S 11S …`). The number of correlating orbitals of an l is normally the
number of basis functions of that l minus the occupied and core orbitals
of that l; `&TR NOB`, `MPOB` and `&GET IND` must then cover all of them.

`atgen` writes the CSF list to unit 7. With `OPEN UNIT=7 FILE=f.csf` in
the header it goes to `f.csf`; do not redirect standard output to that
file as well.

## 16. `atinpgen` — decks from a short description

`atinpgen` writes a complete deck **and** its CSF list from a short
`.inp` file. It reads the basis file to derive `NSYM`, `NBF`, `NOB`,
`MPOB`, derives `ITNEL`, `IPAR`, `CLOSED`, `CSFS` from the reference,
sets `NRNFG` from the groups present, and generates the CSF list with a
Python port of `atgen`. It checks the input before writing anything.

```
# Sc 3d 4s2 2D (samples/inp/sc.inp)
title:  " SC DOUBLET D "
deck:   sc.deck
csf:    sc.csf

atom:
  z:     21
  ang:   D
  spin:  2

files:
  cfptable:  ./CFPTBL
  basis:     sc.bas
  format:    atomci
  open:
    - unit: 27, file: sc.NO, format: binary, status: unknown

orbital:
  frozen_core:  1S, 2S, 2P, 3S, 3P
  active:       4S, 3D
  outer:        3S, 4P, 3D, 2F, 1G

reference:
  - scf: true, occ: 4S*2 3D*1

ctrl:
  ai:  type: 2, idprnt: 0
  mc:  itmax: 30
  wf:  rule: 1, npflg: 0
  tr:
    ind:
      - record: 1, l: 0, first: 1, last: 7
      - record: 1, l: 1, first: 1, last: 6
      - record: 1, l: 2, first: 1, last: 4
      - record: 1, l: 3, first: 1, last: 2
      - record: 1, l: 4, first: 1, last: 1
  ci:  ips: 7, maxit: 100, nsdim: 100, nstate: 1
  rs:  print: -0.001
```

```sh
cp "$repo/samples/inp/sc.inp" "$repo/samples/native/sc.bas" .
ln -sf "$ATOMCI_HOME/CFPTBL" CFPTBL
"$ATOMCI_HOME/bin/atinpgen" sc.inp            # writes sc.deck and sc.csf
"$ATOMCI_HOME/bin/atomci" < sc.deck > sc.output
```

Syntax: indentation by two spaces (no tabs), `key: value`, `- ` for
list items, `k: v, k: v` for a record on one line, `#` comments, quotes
where leading blanks matter.

| Key | Meaning |
|---|---|
| `title`, `deck`, `csf` | Title; names of the deck and CSF files to write. |
| `atom.z`, `atom.ang`, `atom.spin` | Z; L as a letter; 2S+1. |
| `files.cfptable`, `files.basis`, `files.open[]` | The CFP table, the basis file (unit 3), further `OPEN` lines. |
| `orbital.frozen_core` | Core shells (→ `&MC CLOSED`, `atgen` CARD 5). |
| `orbital.active` | Occupied shells of the references (CARD 2). |
| `orbital.outer` | Number of correlating orbitals per l (CARD 1): `3S` means *three* s orbitals, not the 3s shell. |
| `reference[]` | `occ:` the references in `CSFS` notation; `scf: true` marks those used in the MCSCF. |
| `ctrl.ai/mc/wf/tr/pt/ex/ci/rs` | The steps to run and their parameters (table below). A step is run when its key is present. |
| `passes[]` | Several passes, each with its own `title` and `ctrl` (§16.2). |

### 16.1 The step keys

A key that is not given is not written to the deck, so the default of
ATOMCI applies (the defaults are those of §§5–13). Only `ai.type` and
`wf.rule` must be given when their step is present. Lists are written
with blanks (`ioflg: 0 -1 -1 0 0`); inside a one-line record a comma
would end the field.

| Key | NAMELIST member | Notes |
|---|---|---|
| `ai.type` | `&AI NTYPE` | 1 STF, 2 GTF; also selects how the basis file is read |
| `ai.idprnt` | `&AI IDPRNT` | |
| `mc.itmax`, `mc.ethr`, `mc.c2thr`, `mc.nsol` | `&MC ITMAX`, `ETHR`, `C2THR`, `NSOL` | |
| `mc.nset` | `&MC NSET` | default 1 (record 1 of the orbital file) |
| `mc.nopt` | `&MC NOPT` | list |
| `mc.ind[]` | `&MC IND`, `NIND` | starting orbitals, rows as in `tr.ind` |
| `wf.rule`, `wf.npflg`, `wf.ismax`, `wf.irmax` | `&WF RULE`, `NPFLG`, `ISMAX`, `IRMAX` | |
| `tr.ind[]` | `&GET IND`, `NIND` | rows `record, l, first, last` |
| `tr.from_record` | `&GET IND`, `NIND` | instead of `ind`: orbitals 1…`NOB` of every symmetry from this record |
| `tr.nbase` | `&GET NBASE` | |
| `tr.record` | `&TR ITVCI` | default 1 |
| `pt.cthr`, `pt.ethr`, `pt.how`, `pt.istate`, `pt.ips`, `pt.pthr` | `&PT` members of the same name | |
| `pt.nstate` | `&PT NSOLVE` | |
| `pt.nrnfg` | `&PT NRNFG` | list of 3 |
| `ex.retry` | `&EX RETRY` | `true`/`false` |
| `ex.nfexw`, `ex.nfexe` | `&EX NFEXW`, `NFEXE` | |
| `ci.ips`, `ci.maxit`, `ci.nsdim`, `ci.nstate`, `ci.nfiv`, `ci.thrcsf` | `&CI` members of the same name | |
| `ci.ioflg` | `&CI IOFLG` | list; default `0 -1 -1 0 0` (natural orbitals appended to the orbital file) |
| `ci.inflg`, `ci.xref` | `&CI INFLG`, `XREF` | lists |
| `rs.print` | `&RS PTHR` | |
| `rs.rule` | `&RS RULE` | default 2 (Brown); 1 Bunge |
| `rs.nrnfg` | `&RS NRNFG` | |

**The orbitals of the CI.** `NSYM`, `NBF` come from the basis file (the
GTF format of §6.3 for `ai.type: 2`, the STF format of §6.2 for
`ai.type: 1`). `NOB` of each l is the number of core and active shells
of that l plus the count that `orbital.outer` gives for it, so an
`outer` count smaller than the basis allows leaves the highest vectors
of each symmetry of the coefficient set out of the CI (`NOB < NBF`).
Every symmetry of the basis needs at least one orbital: a symmetry with
`NOB = 0` stops CIMAIN, and `atinpgen` refuses it.

### 16.2 Several passes

`passes:` replaces the top-level `ctrl:`. Each pass has its own `title`
and `ctrl`; nothing carries over from one pass to the next, so each pass
states all its parameters. `samples/inp/f.inp` is the three-pass deck
`samples/native/f.stdin` in short form (SD-CI, SD-CI on its natural
orbitals, RS with Bunge's estimate). Abridged:

```
passes:
  -
    title: " F DOUBLET P "
    ctrl:
      ai:  type: 2, idprnt: 0
      mc:  itmax: 20
      wf:  rule: 1, npflg: 0
      tr:  from_record: 1       # the SCF orbitals (&MC NSET=1)
      ci:  ips: 7, maxit: 100, nsdim: 100, nstate: 1
      rs:  print: -0.001
  -
    title: " F DOUBLET P (NO 1) "
    ctrl:
      tr:  from_record: 2       # the natural orbitals of pass 1
      ci:  ips: 7, maxit: 100, nsdim: 100, nstate: 1
      rs:  print: -0.001
  -
    title: " F DOUBLET P (NO 1) "
    ctrl:
      rs:  print: -0.001, rule: 1
```

It gives the energies of `f.stdin`: −99.641223, then −99.641037 twice.
With the default `ci.ioflg`, the CI of each pass appends its natural
orbitals to the orbital file: record 2 after pass 1, record 3 after
pass 2, and so on. A pass that leaves out steps (for example only `tr`,
`ci`, `rs`) continues from the files of the earlier steps, as a restart
does (§14).

### 16.3 What the short form covers

The keys above describe: a basis file (GTF or STF); SCF or MCSCF
orbitals of the references marked `scf: true`; an SD-CI from one or
several references of the same parity (`RULE=1`) or an SD-CI with
perturbative selection (`RULE=2`), with frozen core, all occupied
shells active and a number of correlating orbitals per l; any number of
passes. `sc`, `ti`, `cu`, `be`, `c`, `f` and `fpt` are of this kind. With several references, the electron count and the
parity are taken from the first (lint checks that all agree), and the
MCSCF uses the references marked `scf: true`, or all of them when none
is marked.

The following has no key. It can still be written in an `.inp` with
`raw:` blocks and payload files (any deck can, §16.4), but the NAMELIST
is then written by hand:

| Calculation or setting | Why |
|---|---|
| A basis written in the deck (`&AI IUNIT=5`) | the basis is a file |
| Orbitals given as coefficients in the deck (`&BASVC`, `ITVCI=0`) | not derived |
| General CI (`RULE=0`) with a hand-written CSF list | the CSF list is always the SD list of `atgen` |
| Restricted intermediate couplings (`1-3,P-P`), symbolic occupations, excitations beyond doubles, excitations restricted to groups of orbitals | same |
| A coupling order other than the order of `orbital.active` | fixed |
| The unit numbers of the intermediate files | fixed at their defaults |

### 16.4 Raw blocks and payload files

A `raw:` entry gives a NAMELIST group and its parameters directly, with
nothing derived. It replaces the block of the same group that the short
form built, or is added after the others if there is none. Each entry
uses the bare `-` form, with its fields indented below it:

```
raw:
  -
    group: TR
    params:
      nsym: 7
      nbf: 10,9,8,8,6,4,2
      nob: 8,7,6,5,4,3,2
      mpob: 3,4,5,6,7,8,1,2,2,3,4,5,6,7,1,1,2,3,4,5,6,1,2,3,4,5,1,2,3,4,1,2,3,1,2
      itvci: 0
      iordr: 0
      itrns: 2
```

Values in `params` are taken as written: `5.0D0` stays `5.0D0`, a comma
makes a list, and a value in `"…"` is a character string.

Card data that follows a group (a basis, a CSF list, orbital
coefficients) is a `payload:` of its raw entry. The file is copied into
the deck unchanged, right after the group; it is looked for in the
current directory and then next to the `.inp`:

```
    payload:
      kind:   basis           # basis, csf or vectors
      path:   boron.basis.txt
```

`samples/inp/boron.inp` writes a whole deck this way, with three payload
files. `atinpgen` checks that:

- a `basis` or `csf` payload ends in a line of `)` only, and a `vectors`
  payload has one such line per non-empty symmetry;
- the number of coefficients of a `vectors` payload is the sum of
  `NOB(i)*NBF(i)` of `&TR`;
- `&TR ITVCI=0` comes with a `&BASVC` block and `ITVCI=1` with `&GET`;
- `IUNIT=5` and a payload go together;
- a raw `&TR` gives `MPOB` (without it the program silently uses the
  identity ordering).

### 16.5 Checks and options

`atinpgen` checks every input before it writes anything, and an error
stops it. The messages name the line and the key:

```
f.inp:12: unknown key 'itmx' in $.ctrl.mc (did you mean 'itmax'?)
f.inp:20: $.ctrl.tr.ind[0].last expects an integer (cannot parse '13x')
```

Beyond the syntax, the checks cover the orbital counts against the basis
file, the electron count and parity of the references, the capacity of
each shell, shells of a reference missing from `orbital.active`, and the
size limit of the CSF list. A missing `ctrl.rs` is a warning, because the
run then prints no `SD-CI ENERGY` line.

| Option | Effect |
|---|---|
| `--lint-only` | Check only; exit status 0 if there is no error, 1 otherwise |
| `--dump-atg` | Print the equivalent `atgen` input; write nothing |
| `--dump-ir` | Print the deck's internal form as JSON; write nothing |
| `--csf-source python` | CSF list from the Python port of `atgen` (default) |
| `--csf-source atgen` | CSF list from the `atgen` binary |
| `--csf-source file` | Use the CSF file that already exists |
| `--style jar` | Lower-case group and parameter names, `Z` as an integer (default) |
| `--style native` | Upper-case names and `Z=9.0D0`, like the hand-written decks |

A hand-written deck can be turned into an `.inp` with raw blocks and
payload files:

```sh
PYTHONPATH="$ATOMCI_HOME/lib" python3 -m atinputs.reverse deck.stdin -o outdir
```

[`ATINPUTS_PY.md`](ATINPUTS_PY.md) describes all of this in full, and the
`.inp` files in [`../samples/atinputs/`](../samples/atinputs/README.md) show
more uses.

## 17. Reading the output

The listing goes to standard output. Each step ends with a line

```
 ===============    END OF  MCMAIN    == RETURN CODE IS    0 ====     USED TIME IS ...
```

A non-zero return code means the step failed; the following steps are
skipped. **The process exit status of `atomci` stays 0 even then**, so
scripts must look at `RETURN CODE IS` in the listing. The codes are
listed in [`appendix.002`](appendix.002).

The main results:

| Step | Line | Contents |
|---|---|---|
| MCMAIN | `Total Energy =  -759.73544953 a.u.` | SCF/MCSCF energy (the last such line is the converged one). |
| WFMAIN | `ENERGY EXPRESSION SUMMARY` | Number of configurations and CSFs. |
| CIMAIN | `* WELL CONVERGED *` | Davidson convergence. |
| CIMAIN | `E (TOTAL)  E (REFERENCE)  E (H MATRIX) …` | CI energy of each state, followed by the CSFs with the largest coefficients. |
| CIMAIN | `SYM=  n` blocks (section 5) | Natural orbitals of each symmetry: occupation numbers in the first row, coefficients below; then the `VECTOR SET` records of the orbital file. |
| RSMAIN | `REFERENCE ENERGY (WEIGHT)`, `SD-CI ENERGY (CORRELATION)`, `ESTIMATE SD ENERGY (THROWN)` | Reference energy and its weight in the CI vector, CI energy and correlation energy, estimate including rejected CSFs. |
| RSMAIN | `SD-CI ENERGY  = …` | Final summary. |

For a general CI (`samples/native/boron.stdin`) the energy appears as `ET =`
in the CI section. Energies are in hartree.

Files kept after the run: the orbital file (unit 27, e.g. `f.NO`) with
the SCF/MCSCF orbitals and the natural orbitals; the step log (unit 7);
and the intermediate files `fort.N` (Appendix A), which are needed only
for a restart and can be deleted afterwards.

## 18. Limits and pitfalls

**Limits of the program**

- At most 150 basis functions. STF up to l = 9, GTF up to l = 7.
- The CFP table extends up to the m shell, but shells with l > 3 may
  hold at most two electrons (5g³ is not allowed). Several such shells
  are allowed as long as the configuration has at most 10 open shells.
- At most 800 CSFs from one configuration line of the CSF list.
- `atgen`: fewer than 40 correlating orbitals per l.
- MCSCF: only configurations that differ by even numbers of electrons
  in each shell.

**Pitfalls**

- `&MC CSFS` and the coupling order: write the shells by l, then by n
  (`4S` before `3D`). The program now stops otherwise (§7).
- Basis numbers in fixed-point form only, lines of at most 80 columns
  (§6.3).
- Give `&TR MPOB` in every pass (§9.1).
- Leave `&TR ITRNS=2` and `&TR NPFLG=0`; leave `&CI IDTYP=0,0` (the
  alternatives stop with an end-of-file error or an abort).
- `&GET` with `NIND=0` (no quartets) stops with an end-of-file error.
- Run independent calculations in separate directories (§2).
- Check `RETURN CODE IS` in the listing; the exit status is always 0
  (§17).
- Do not redirect the standard output of `atgen` onto the CSF file it
  writes through unit 7 (§15).

## 19. Worked examples

Each as a NAMELIST deck in
[`../samples/native/`](../samples/native/README.md) and as an `.inp` file
of [`../samples/inp/`](../samples/inp/README.md) with the same name. Each
directory holds all the files its calculations read. `samples/native/run_native.sh` and `samples/inp/run_inp.sh` run them
and check the answers; [`TUTORIAL.md`](TUTORIAL.md) walks through both.

| Example | Atom, term | What it shows | Energy (hartree) |
|---|---|---|---|
| `boron.stdin` | B 2s²2p ²Pᵒ | STF basis in the deck, orbitals in the deck (`&BASVC`), general CI (`RULE=0`) with a hand-written CSF list using symbols and coupling ranges | `ET = -24.6461953967` |
| `boron_nsdim700.stdin` | same | the same with `NSDIM=700`, larger than the CI dimension: direct diagonalization | `ET = -24.6461953996` |
| `f.atg`, `f.bas`, `f.stdin` | F 2s²2p⁵ ²Pᵒ | GTF basis file, SCF, SD-CI with `atgen`, three passes (natural orbitals, RS with Bunge's method) | `SD-CI = -99.641223`, then −99.641037 twice |
| `fpt.atg`, `fpt.stdin` | same | SD-CI with perturbative selection on the natural orbitals of the `f` run (run `f` first, same directory) | `SD-CI = -99.640355` |
| `../atinputs/f_no.inp` | F ²Pᵒ | `f.stdin` (three passes) written for `atinpgen` | −99.641223, then −99.641037 |
| `../atinputs/b_stf.inp` | B ²Pᵒ | `atinpgen` with an STF basis file and fewer correlating orbitals than the basis allows (`NOB < NBF`) | `SD-CI = -24.599517` |
| `sc.*`, `ti.*`, `cu.*` | Sc 3d4s² ²D, Ti 3d²4s² ³F, Cu 3d¹⁰4s ²S | cc-pVTZ basis, MCSCF with a 3d/4s core of 18 electrons, SD-CI of the 4s and 3d electrons | Sc −759.776305, Ti −848.458805, Cu −1639.376374 |
| `be.*`, `c.*` | Be 2s² ¹S, C 2s²2p² ³P | cc-pVTZ basis, two-configuration MCSCF (2s² + 2p², 2s²2p² + 2p⁴), multi-reference SD-CI from both references, 1s frozen | Be −14.618544, C −37.779409 |

To adapt `sc.stdin` to another 3d atom or term, change `&AI Z`;
`ITNEL`, `ISPIN`, `IORB`, `IPAR` in `&MC` and `&WF`; `&MC CLOSED` and
`CSFS`; the basis counts in `&TR NBF`, `NOB`, `MPOB` and `&GET IND`; and,
in the `.atg`, the correlating orbitals, the occupied shells, the
reference, the coupling order and the core. Or write an `.inp` and let
`atinpgen` derive these.

---

## Appendix A. Files and unit numbers

The default units of the intermediate files. They can be changed in
`&CNTL` (and some in the step's own group), which is useful only in
restarts.

| `&CNTL` name | Unit | Contents | Written by → read by |
|---|---|---|---|
| `FILES` | 7 | Step log: return codes and times | all steps |
| `NFTF` | 10 | CFP table (`CFPTBL`) | — → WF, PT, EX, CI, RS |
| `NFWFB0` | 11 | CSF list of a general CI | WF → EX |
| `NFPTB` | 11 | Selected CSFs | PT → EX, RS |
| `NFWFB1` | 12 | CSF list of an SD-CI | WF |
| `NFWFP` | 14 | Energy expression for the perturbative selection | WF → PT |
| `NFWFE` / `NFEXE` | 15 | Energy expression of the CI | WF or EX → CI |
| `NFTRI` | 16 | Transformed integrals | TR → PT, CI |
| `NFAII` | 18 | AO integrals | AI → MC, TR |
| `NFTD` | 20 | Direct-access work file (only if the transformation does not fit in memory) | TR |
| `NFTRC2` | 21 | Orthonormalized coefficients (copy) | TR → CI |
| `NFCIH` | 22 | Density matrices (temporary) | CI |
| `NFCID` | 24 | One-electron expression | CI |
| `NFTRC1` / `NFCIC` | 27 | Orbital file: SCF/MCSCF orbitals, natural orbitals | MC, CI → TR (`&GET`) |
| `NFCIW` | 28 | CI vectors and density matrices (if saved) | CI |
| `NFPTV` | 31 | CI vectors of the perturbative selection | PT |
| `NFPTH1`, `NFPTH2` | 32, 33 | Effective Hamiltonian | PT → RS |
| `NFPTL` | 35 | Work file | PT |
| `NFCIV` | 37 | CI vectors | CI |
| `NFCIH1`, `NFCIH2` | 38, 39 | Diagonal and off-diagonal Hamiltonian matrix | CI |
| `NFCIS` | 71 | CI summary | CI → RS |
| `NFTBL` | 88 | CFP work file | WF, EX |
| `NFWFW` | 9 | Work file | WF |

## Appendix B. Quick reference

```
OPEN UNIT=10 FILE=./CFPTBL BINARY STATUS=OLD     CFP table (always)
OPEN UNIT=3  FILE=x.bas STATUS=OLD               basis      (&AI IUNIT=3)
OPEN UNIT=2  FILE=x.csf STATUS=OLD               CSF list   (&WF IUNIT=2)
OPEN UNIT=27 FILE=x.NO BINARY                    orbitals   (&MC NSET, &GET IVCS)
END
 &CNTL  NRNFG=ai,mc,wf,tr,pt,ex,ci,rs  TITLE='...'
 &AI    Z  NTYPE(1 STF, 2 GTF)  IUNIT
 &MC    ITNEL ISPIN(2S+1) IORB(2L+1) IPAR(0/1)  CLOSED  CSFS  NSET  ITMAX
 &WF    RULE(0 CI, 1 SD-CI, 2 PT-CI)  ITNEL ISPIN IORB IPAR  IUNIT
 &TR    NSYM NBF() NOB() MPOB()  ITVCI(0 &BASVC, 1 &GET)
 &BASVC IUNIT          coefficients follow, ')' after each symmetry
 &GET   IVCS NIND IND(record, l, first, last)...
 &PT    NSOLVE ISTATE HOW ETHR CTHR
 &EX    RETRY
 &CI    NSTATE MAXIT IPS NSDIM NFIV IOFLG(-,vec,dens,-,NO,-)
 &RS    NRNFG(0; >0 for RULE=2)  RULE(1 Bunge, 2 Brown)  PTHR
```

| `RULE` | `&CNTL NRNFG` | groups |
|---|---|---|
| 0 general CI | `1,1,1,1,0,1,1,1` | AI MC WF TR (BASVC/GET) EX CI RS |
| 1 SD-CI | `1,1,1,1,0,0,1,1` | AI MC WF TR (BASVC/GET) CI RS |
| 2 PT-CI | `1,1,1,1,1,1,1,1` | AI MC WF TR (BASVC/GET) PT EX CI RS |
