# Installing ATOMCI

This is the build and installation reference for ATOMCI. For an overview, see
[README.md](README.md); for a step-by-step walk-through, see
[docs/TUTORIAL.md](docs/TUTORIAL.md).

The source tree lives under `src/`. A top-level `make` builds everything there
(the artifacts stay in `src/`); `make install` then assembles a clean, runnable
layout under `$(prefix)` (default `./local`). The pieces you get:

- **`atomci`** — the main CI program
- **`atgen`** — the CSF (configuration state function) list generator
- **`fpl`** — the FPL preprocessor (used during the build, and installed because
  it is what regenerates Fortran from any edited `*.fpl`)
- **`atinpgen`** — the input-deck and CSF-list generator; the `.inp` format is
  described in [docs/INPUT_MANUAL.md](docs/INPUT_MANUAL.md) §16, and in full in
  [docs/ATINPUTS_PY.md](docs/ATINPUTS_PY.md)
- **`CFPTBL`** — the table of coefficients of fractional parentage (generated
  once from `cfpa` → `cfpb`)

The `cfpa`/`cfpb` table-builders and the `tfpl` bootstrap preprocessor are
build-internal and are not installed; they stay under `src/`.

The older Java/XML generator (M. Sekiya's `msekiya.jar`) is archived, not
installed: the jar is in `attic/msekiya-jar/`, its manual is
[docs/ATINPUTS_MANUAL.md](docs/ATINPUTS_MANUAL.md). It needs CERN Colt 1.0.2
(`colt.jar`) at run time, which this distribution does not ship.

## Requirements

- **gfortran 9 or later.** No manual action is needed for any supported
  version: the Makefile applies two version-gated adjustments (see
  [Platform notes](#platform-notes)).
- **gcc** — for the small C timing helper (`iqtime.c`).
- **make**.
- **Python 3** — for `atinpgen` (standard library only).
- **BLAS/LAPACK** — required. Install `libblas-dev`/`liblapack-dev` (or an
  OpenBLAS package); `make` detects it via `pkg-config` and stops at once,
  naming the packages to install, if it is missing.

## Build

```sh
make
```

The top-level `make` is a thin delegator: it builds the tree under `src/`
(invoking the freshly built `fpl`/`cfpa`/`cfpb` tools by absolute path, so no
`PATH` setup is needed) and leaves the artifacts there.

### LAPACK

Detection is via `pkg-config --libs lapack blas` (then `openblas`). On macOS it
also adds Homebrew's keg-only `openblas`/`lapack` pkgconfig directories to
`PKG_CONFIG_PATH`, found at build time via `brew --prefix`, so it works with
either Homebrew location and with Apple's stock `make` (GNU Make 3.81).

If nothing is found, `make` stops before any compile or link with the packages
to install:

```sh
$ make
System BLAS/LAPACK not found (pkg-config lapack+blas, then openblas).
Install it, then re-run make:
  Debian/Ubuntu : sudo apt-get install liblapack-dev libblas-dev   (or libopenblas-dev)
  Fedora/RHEL   : sudo dnf install lapack-devel blas-devel          (or openblas-devel)
  macOS (brew)  : brew install openblas lapack
...
```

> **Installed but not detected?** pkg-config only sees `.pc` files that are on its
> search path. If your BLAS/LAPACK lives somewhere off that path, point
> pkg-config at it and re-run, e.g.:
>
> ```sh
> export PKG_CONFIG_PATH="$(brew --prefix openblas)/lib/pkgconfig:$(brew --prefix lapack)/lib/pkgconfig:$PKG_CONFIG_PATH"
> make
> ```

### Installing and running

`make install` builds (via the default target), then assembles the layout under
`$(prefix)`:

```
local/
├── bin/     atomci  atgen  fpl  atinpgen   (+ atomci.sh helper)
├── lib/     atinputs/
└── CFPTBL
```

`CFPTBL` sits at the `$(prefix)` root so it is easy to symlink into a work
directory. `make install` replaces `$(prefix)/bin` and `$(prefix)/lib` on every
run.

The install location is separate from where you run calculations. Set the
**`ATOMCI_HOME`** environment variable to the install prefix. `make install`
prints the exact line for your prefix as its final output:

```sh
make install                              # -> ./local (default)
make install prefix=$HOME/local           # -> $HOME/local (your choice)
export ATOMCI_HOME="$PWD/local"           # (paste what `make install` printed)
# optional, for repeated use:  export PATH="$ATOMCI_HOME/bin:$PATH"
```

The `atomci.sh` wrapper requires `ATOMCI_HOME` and exits with an error if it is
not set. `atinpgen` does not: it finds its own package relative to its installed
location.

**Running a calculation.** Work in your own directory, anywhere. Symlink the
`CFPTBL` table in (the decks open it as `OPEN UNIT=10 FILE=./CFPTBL`, relative
to the current directory), then run the installed binary by path, with `$repo`
your checkout:

```sh
repo=/path/to/atomci
mkdir -p ~/atomci-runs/boron && cd ~/atomci-runs/boron
ln -sf "$ATOMCI_HOME/CFPTBL" ./CFPTBL
"$ATOMCI_HOME/bin/atomci" < "$repo/samples/native/boron.stdin" > boron.output
```

A symlink keeps one source of truth: a rebuild and reinstall regenerates
`$ATOMCI_HOME/CFPTBL`, and every work directory's link points at the new table.

**Generating a deck with `atinpgen`:**

```sh
cp "$repo/samples/inp/f.bas" .
"$ATOMCI_HOME/bin/atinpgen" "$repo/samples/inp/f.inp"   # writes f.deck, f.csf
```

From a source tree without `make install`, run the module with `scripts/` on
`PYTHONPATH`:

```sh
PYTHONPATH="$repo/scripts" python3 -m atinputs "$repo/samples/inp/f.inp"
```

## Known build quirks

- **`-fno-automatic` (`src/Makefile`) is required, not a legacy default.** It
  makes at least one routine's uninitialized local reliably zero, and it is the
  only reason a multi-pass deck's restated `&TR`/`&CI`/`&RS` parameters behave
  consistently across passes (those routines neither `SAVE` them nor hold them
  in COMMON). Without it the failure is silently wrong energies, not a build
  error.
- **Edit the `.fpl`, not the generated `.f`.** The 49 FPL-generated `.f` files
  are gitignored, so an edit to `src/cipt.f` instead of `src/cipt.fpl` leaves no
  signal in `git status` and is discarded when the `.fpl` is next touched. `make`
  prints a reminder when this might apply.
- **A clean clone depends on the FPL bootstrap.** Those `.f` files do not exist
  until the chain `tfpl90.f`/`tfpl90lib.f` → `tfpl` →
  `fpl90.f`/`fpl90lib.f`/`fplnews.f`/`wt9x.f` → `fpl` → every other `.f` has run.
  A plain `make` does this.

## Known runtime limits

**`BUFFER IS TOO SMALL !! NEED MORE CORE`, or `NEED MORE DISK SPACE`, from
TRMAIN/CIMAIN on a larger calculation is a real capacity limit.** The
two-electron integral file (`NFTRI`) is read back by one subroutine,
`cinewx.f:PRDINT`, in one pass into one in-core buffer sized from the available
`/WORK/` heap and `LTRI` (see the `LTRI` entries of `&CI`, `&PT`, `&WF` in
`docs/namelist.002`). So the whole transformed two-electron integral set of a
run must fit in one buffer, or CIMAIN stops with `NEED MORE CORE`. The remedies
are the ones the message names: raise `LTRI` in the NAMELIST and/or the `/WORK/`
heap size (`%%WORKCORE` in `include/PARAM`, about 430M `INTEGER*4` words by
default), then rebuild. Similarly, the disk-overflow path of the transformation
(`&TR` `NFTRD`/`LDSK`) has a fixed number of blocks; exceeding `LDSK` stops with
`NEED MORE DISK SPACE`, and the remedy is to raise `LDSK`.

## Verifying the build

`samples/native/run_native.sh` runs all nine examples and checks each against
its answer, every step's return code, and an empty standard error:

```sh
export ATOMCI_HOME=...      # after `make install`
samples/native/run_native.sh
samples/inp/run_inp.sh      # the same nine from the .inp form
```

The first four are the regression suite of the build:

| Sample | Reads | Answer |
|--------|-------|-----------|
| `boron` | `CFPTBL` (basis in the deck) | `ET = -24.6461953967` |
| `f` (F atom, SD-CI) | `CFPTBL`, `f.bas`, `f.csf` (writes `f.NO`) | `SD-CI = -99.641223` |
| `fpt` (F atom, PT) | `CFPTBL`, `f.bas`, `fpt.csf`, `f.NO` | `SD-CI = -99.640355` |
| `boron_nsdim700` | `CFPTBL` (basis in the deck) | `ET = -24.6461953996` |

> **Run each independent sample in its own clean work directory.** A run leaves
> `fort.*` scratch files behind, and a later run in the same directory *appends*
> its vector set to them instead of starting fresh. The one exception is
> `f` → `fpt`: `fpt` reuses `f.NO` from the `f` run, so run those two in the same
> work directory, `f` first.

### Reading the differences

Compare at the **value level**: the energy your build prints against the answer.
The last digits of a listing can differ between toolchains in formatting, and
timing and date fields (`USED TIME`, `USED CPU`, `GUESS CONSTRUCTION TIME`,
page-header timestamps) vary from run to run. `samples/native/*.output` are
listings to read, not files to diff against.

`boron` and `boron_nsdim700` agree to 8 decimals: they are the Davidson and the
direct diagonalization of the same state.

### Testing `atinpgen`

`scripts/atinputs/tests/` is the test suite of the generator; its inputs and
frozen reference decks are in `samples/atinputs/`. It needs pytest and
hypothesis (`scripts/atinputs/requirements-test.txt`). Run it after `make`: two
tests read the generated `src/*.f`. With `ATOMCI_HOME` set, the tests that run
the programs run too; without it they are skipped:

```sh
pip install -r scripts/atinputs/requirements-test.txt
cd scripts && python3 -m pytest atinputs/tests -q
```

A few tests run only against a sanitizer build of `atgen`. To build it (after a
normal `make`) and run them, from the top of the tree:

```sh
scripts/build_san.sh san0
ATOMCI_SANITIZED_ATGEN="$PWD/build_san_san0/atgen" \
  python3 -m pytest scripts/atinputs/tests/test_differential_sweep.py -k sanitizer -v
```

## Platform notes

Built and run on Debian with gfortran 14.2.0; on Linux with gfortran 9.5.0 and
16.2.0 (`gcc:9`, `gcc:16` containers, reference LAPACK 3.9.0 and 3.12.1); and on
macOS 14.8 (Intel), Homebrew GCC 16.1.0, Apple's `/usr/bin/make`. The four
regression samples reproduced their answers on macOS. Versions 10–15 were built
earlier on Debian. Apple Silicon has not been tried.

The Makefile applies two automatic, version-gated adjustments:

- **`-fallow-argument-mismatch` on gfortran ≥ 10.** At gcc 10 an argument
  type/rank mismatch became an error by default; the flag downgrades it to a
  warning and does not change the code generated. What it still covers are
  deliberate cases: `cici.f`'s `EMDEL` stub and the `/work/` heap convention in
  `mcfock.f`/`mcdriv.f`.
- **`wt9x.f` at `-O0` on gcc-8 only.** gcc-8 miscompiles `FUNCTION WT9X`
  (Wigner-9j) at `-O1` and above, giving a wrong CI energy (boron: `-28.57`
  instead of `-24.6462`). gcc-8 is below the supported floor, but the gate stays
  because the failure would be a silently wrong answer.
