# ATOMCI

**ATOMCI** is a non-relativistic Configuration Interaction (CI) program for
many-electron atoms. It computes atomic electronic structure in the
Russell–Saunders (LS) coupling scheme, building the CI Hamiltonian matrix from
the vacuum expectation values of tensor operators and their recoupling
transformation coefficients. Its capabilities include full use of atomic
symmetry, STF (l ≤ 9) or GTF (l ≤ 7) basis sets, SCF and MCSCF orbital
optimization, general CI or SD-CI, perturbative configuration selection, and
natural-orbital / first-order density-matrix analysis.

ATOMCI was developed at Hokkaido University by **F. Sasaki, M. Sekiya,
T. Noro, K. Ohtsuki, and Y. Osanai**. Its theoretical basis is described in
F. Sasaki, *Int. J. Quantum Chem.* **8**, 605 (1974), and in Sasaki, Sekiya,
Noro, Ohtsuki & Osanai, *"Non-Relativistic Configuration Interaction
Calculations for Many-Electron Atoms: ATOMCI"*, pp. 163–219 in *Methods and
Techniques in Computational Chemistry (METECC-94)* (ed. E. Clementi, 1993).

## Status

ATOMCI builds and runs with gfortran 9 or later and the system BLAS/LAPACK.
See [`INSTALL.md`](INSTALL.md) for details.

## License / attribution

Copyright © Fukashi Sasaki, Masahiro Sekiya, Takeshi Noro, Kazumasa Ohtsuki,
and You Osanai, 1990–2003.

Permission is granted to use, copy, modify, and redistribute this program and
its documentation, in source or binary form, for **non-commercial research and
educational purposes.** It may not be sold, licensed for a fee, included in a
commercial product, or otherwise commercially exploited, in whole or in part.

The methods and algorithms are free to study and to implement independently:
an independent implementation may use any license, including a commercial one,
and may resemble ATOMCI in structure, as long as it does not copy, translate, or
adapt ATOMCI's code. See Section 3(g) of [`LEGENDS.txt`](LEGENDS.txt).

Any publication based upon results obtained from this material must include the
attribution:

> This work is based, in part, on results from the ATOMCI package.

and cite the two papers listed above. See [`LEGENDS.txt`](LEGENDS.txt) for the
full terms, including the licensing of the archived `msekiya.jar` and the
system BLAS/LAPACK note; please read it, and use ATOMCI only if you agree to
them.

## Quick start

```sh
make
make install prefix=$HOME/atomci-local   # default prefix: ./local
export ATOMCI_HOME=$HOME/atomci-local    # `make install` prints this line

samples/native/run_native.sh             # runs nine examples, prints OK or FAIL
samples/inp/run_inp.sh                   # the same nine from the .inp form
```

[`docs/TUTORIAL.md`](docs/TUTORIAL.md) goes through this step by step and
shows how to run a calculation by hand and check the answer.

## Two input forms

ATOMCI accepts a calculation in either of two forms:

1. **NAMELIST deck** — the program's own input: an `OPEN` header, one
   NAMELIST group per step (`&CNTL`, `&AI`, `&MC`, `&WF`, `&TR`, `&PT`,
   `&EX`, `&CI`, `&RS`) and card data (basis, CSF list, orbitals). For an
   SD-CI the CSF list is written by `atgen` from a short `.atg` input.
   Every calculation ATOMCI can do can be written this way.
2. **`.inp` file** — a short, indented description (atom, basis file,
   core/active/correlating orbitals, references, steps to run) from which
   `atinpgen` writes the deck **and** its CSF list, checking the input
   first. It covers SCF/MCSCF and single- or multi-reference SD-CI, with
   or without perturbative selection, in Gaussian or Slater basis sets,
   over any number of passes (e.g. a second CI on natural orbitals).
   Anything else can still be written in an `.inp` as raw NAMELIST
   blocks.

Every example is shipped in both forms (`samples/native/` and `samples/inp/`,
each a closed set of inputs), with the same answers.

## Known boundaries

- **Four samples make up the regression suite** (`boron`, `boron_nsdim700`,
  `f`, `fpt`; see [INSTALL.md → "Verifying the build"](INSTALL.md#verifying-the-build)).
  `boron_nsdim700` has no historical reference: it exercises a code path
  (direct, non-Davidson diagonalization) the others do not reach, and its
  answer comes from this distribution's own run (gfortran 14).
- **52 Fortran `READ`/`WRITE` statements carry an `ERR=` handler with no
  matching `END=`**, across `src/*.f`. In Fortran, `ERR=` alone does not
  catch end-of-file, so any of these that reach end-of-file stop with a
  runtime error. One is known to do so (`RDCP`, reached via `&GET NIND=0`);
  the others have not been examined.
- **`&TR ITRNS≠2` is not usable.** It selects a one-electron transformation
  path (`TRNONA`/`TRNONE`) that reads a file nothing in the program writes;
  it stops with an end-of-file error in `TRMAIN`.

## Documentation

| Document | Contents |
|----------|----------|
| [docs/TUTORIAL.md](docs/TUTORIAL.md) | **Tutorial**: clone, build, install, run the examples in both input forms, check the answers |
| [docs/INPUT_MANUAL.md](docs/INPUT_MANUAL.md) | **Input manual**: the deck, every NAMELIST group a calculation needs, basis and CSF-list formats, `atgen` and `atinpgen` input, output, restarts, limits, worked examples |
| [INSTALL.md](INSTALL.md) | Requirements, build, installation, verifying the build, platform notes |
| [samples/README.md](samples/README.md) | The examples |
| [docs/ATINPUTS_PY.md](docs/ATINPUTS_PY.md) | The `scripts/atinputs` generator (`atinpgen`) in full: `.inp` format, keys, checks, raw blocks and payloads, several passes |
| [docs/ATINPUTS_MANUAL.md](docs/ATINPUTS_MANUAL.md) | The older XML generator it replaced, M. Sekiya's `msekiya.jar`, archived in `attic/msekiya-jar/` |
| [docs/FPL_LANGUAGE_SPEC.md](docs/FPL_LANGUAGE_SPEC.md) | Quick reference for FPL, the in-tree Fortran preprocessor language |

The original 1994 program manual (installation, NAMELIST reference, file
formats) is kept under `docs/` as the `*.002` / `*.doc` / `atomci.tex` files.
