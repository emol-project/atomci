# ATOMCI Tutorial: from `git clone` to checked answers

This tutorial takes you from an empty directory to a built and installed
ATOMCI, runs every shipped example in both input forms, and shows how to
check the answers. It assumes Debian or Ubuntu Linux and a bash shell;
for macOS and other details see [`../INSTALL.md`](../INSTALL.md). Each
step gives the commands and what you should see.

ATOMCI takes its input in two forms (see
[`INPUT_MANUAL.md`](INPUT_MANUAL.md)):

1. a **NAMELIST deck** (`*.stdin`), the program's own input, with an
   `atgen` input (`*.atg`) that writes the CSF list of an SD-CI;
2. an **`.inp` file**, a short description from which `atinpgen` writes
   the deck and the CSF list.

Every example is shipped in both forms, and both give the same energies.

## 1. Install the tools

You need git, make, gfortran 9 or later, gcc, pkg-config, BLAS/LAPACK and
Python 3 (standard library only):

```sh
sudo apt install git make gfortran gcc pkg-config libblas-dev liblapack-dev python3
```

## 2. Get the source

```sh
cd ~
git clone https://github.com/emol-project/atomci.git
cd atomci
```

The rest of the tutorial runs from this directory, `~/atomci`.

## 3. Build and install

```sh
make
make install prefix=$HOME/atomci-local
```

`make` builds the FPL preprocessor, the programs `atomci` and `atgen`,
and the table of coefficients of fractional parentage, `CFPTBL`. If
BLAS/LAPACK is missing it stops at once and names the packages to
install. `make install` copies the programs, the input generator
`atinpgen` and `CFPTBL` to the prefix, and ends with

```
Installed to /home/you/atomci-local
Add this to your shell (or your shell profile):
  export ATOMCI_HOME=/home/you/atomci-local
```

Run that line:

```sh
export ATOMCI_HOME=$HOME/atomci-local
ls $ATOMCI_HOME/bin $ATOMCI_HOME/CFPTBL
```

You should see `atgen  atinpgen  atomci  atomci.sh  fpl` and the path of
`CFPTBL`. Every later step needs `ATOMCI_HOME` set; put the `export` line
in `~/.bashrc` to keep it.

## 4. Run all examples as NAMELIST decks

`samples/native/` holds the nine examples as decks, and every file they
read. `samples/native/run_native.sh` runs them — the four of the
regression suite, the three transition-metal atoms and the two
multi-reference SD-CIs — each in its own work directory, and compares
the energy with the known answer:

```sh
NATIVE_WORK=$HOME/atomci-runs/native samples/native/run_native.sh
```

All nine take a few seconds. The output must be:

```
OK   boron: -24.6461953967
OK   boron_nsdim700: -24.6461953996
OK   f: -99.641223 -99.641037 -99.641037
OK   fpt: -99.640355
OK   sc: -759.776305
OK   ti: -848.458805
OK   cu: -1639.376374
OK   be: -14.618544
OK   c: -37.779409
```

| Name | Atom, term | Calculation |
|---|---|---|
| `boron` | B 2s²2p ²Pᵒ | general CI over a hand-written CSF list, Slater-type basis |
| `boron_nsdim700` | same | same, with the CI matrix diagonalized directly |
| `f` | F 2s²2p⁵ ²Pᵒ | SCF and SD-CI; SD-CI again on its natural orbitals; estimate by Bunge's method (three energies) |
| `fpt` | same | SD-CI with perturbative selection of the CSFs, on the natural orbitals of `f` |
| `sc`, `ti`, `cu` | Sc 3d4s² ²D, Ti 3d²4s² ³F, Cu 3d¹⁰4s ²S | cc-pVTZ basis, SCF, SD-CI of the 4s and 3d electrons |
| `be`, `c` | Be 2s² ¹S, C 2s²2p² ³P | cc-pVTZ basis, MCSCF of two configurations (2s² + 2p², 2s²2p² + 2p⁴), SD-CI from both references |

"OK" means three things: the energies printed by the program are exactly
the answers above, every step of the run ended with return code 0, and
nothing was written to standard error. Any other result is printed as
`FAIL` with what was found, and the script exits with a non-zero status.
The files of each run stay in `~/atomci-runs/native/<name>/`
(`<name>.output` is the listing).

## 5. Run the same examples as `.inp` files

`samples/inp/` holds the same nine calculations as `.inp` files, with
its own copies of the basis files; it uses nothing from `samples/native/`.
`samples/inp/run_inp.sh` writes each deck with `atinpgen`, runs it, and
checks the answer in the same way:

```sh
INP_WORK=$HOME/atomci-runs/inp samples/inp/run_inp.sh
```

The output must be the same nine `OK` lines as in step 4.

## 6. One calculation by hand, in both forms

The scripts do nothing more than the following. Take F, the SD-CI of
`f`.

**As a NAMELIST deck.** `atgen` reads `f.atg` and writes the CSF list
`f.csf` (the file name is in the `OPEN` line of `f.atg`, so do not
redirect its output), then `atomci` reads the deck `f.stdin` from
standard input:

```sh
mkdir -p ~/atomci-runs/f-deck && cd ~/atomci-runs/f-deck
ln -sf $ATOMCI_HOME/CFPTBL CFPTBL
cp ~/atomci/samples/native/f.bas .
$ATOMCI_HOME/bin/atgen  < ~/atomci/samples/native/f.atg
$ATOMCI_HOME/bin/atomci < ~/atomci/samples/native/f.stdin > f.output
```

**As an `.inp` file.** `atinpgen` writes both `f.deck` and `f.csf`; then
`atomci` reads the deck:

```sh
mkdir -p ~/atomci-runs/f-inp && cd ~/atomci-runs/f-inp
ln -sf $ATOMCI_HOME/CFPTBL CFPTBL
cp ~/atomci/samples/inp/f.bas .
$ATOMCI_HOME/bin/atinpgen ~/atomci/samples/inp/f.inp
$ATOMCI_HOME/bin/atomci < f.deck > f.output
```

Each calculation needs its own work directory: ATOMCI keeps its
intermediate files there as `fort.N`, and a later, unrelated run in the
same directory would append to them.

**Checking the answer.** In either directory:

```sh
grep -a -E 'Total Energy =|SD-CI ENERGY  |RETURN CODE IS' f.output | grep -v '====='
```

shows

```
 ****************************************    END OF  AIMAIN   == RETURN CODE IS    0
   Total Energy =       -99.40899077 a.u.
 ****************************************    END OF  MCMAIN  == RETURN CODE IS    0
 ****************************************    END OF  WFMAIN  == RETURN CODE IS    0
 ****************************************    END OF  TRMAIN == RETURN CODE IS    0
 ****************************************    END OF  CIMAIN   == RETURN CODE IS    0
           SD-CI ENERGY       =         -99.641223
 ****************************************    END OF  RSMAIN  == RETURN CODE IS    0
 ****************************************    END OF  TRMAIN == RETURN CODE IS    0
 ****************************************    END OF  CIMAIN   == RETURN CODE IS    0
           SD-CI ENERGY       =         -99.641037
 ****************************************    END OF  RSMAIN  == RETURN CODE IS    0
           SD-CI ENERGY       =         -99.641037
 ****************************************    END OF  RSMAIN  == RETURN CODE IS    0
```

- `Total Energy` is the SCF energy (MCMAIN).
- The first `SD-CI ENERGY` is the SD-CI on the SCF orbitals. The second
  is the SD-CI on the natural orbitals of the first (pass 2). The third
  repeats it with Bunge's estimate in RSMAIN (pass 3).
- Every step must end with `RETURN CODE IS    0`. A step that fails
  prints a non-zero code and the steps after it are skipped. **The exit
  status of `atomci` is 0 even then**, so always check these lines.

Energies are in hartree. Compare them with the answers at the value
level: the date, time and timing lines of the listing differ from run to
run.

`fpt` is run the same way in the same directory, after `f`, because it
reads the natural orbitals that `f` wrote to `f.NO`:

```sh
$ATOMCI_HOME/bin/atinpgen ~/atomci/samples/inp/fpt.inp
$ATOMCI_HOME/bin/atomci < fpt.deck > fpt.output
grep -a 'SD-CI ENERGY  ' fpt.output        # SD-CI ENERGY = -99.640355
```

(For the deck form, use `fpt.atg` and `fpt.stdin` in `~/atomci-runs/f-deck`.)

## 7. Where to go next

- Look at the deck that `atinpgen` wrote (`f.deck`) next to the
  hand-written one (`samples/native/f.stdin`): they describe the same
  calculation.
- To compute another atom or term, start from the `.inp` closest to it.
  For a 3d atom, copy `samples/inp/ti.inp` and change `atom` (Z, L, 2S+1),
  the reference occupation `occ`, and the basis file;
  `samples/native/make_basis.py` writes a cc-pVTZ basis in ATOMCI's format
  from the PySCF basis library. Check an input without writing anything
  with `atinpgen --lint-only file.inp`, run where the basis file is (it
  reads the basis to count the orbitals).
- For a multi-reference SD-CI, start from `samples/inp/c.inp`: list
  every reference under `reference:`, each with all the active shells
  (`2S*0` for an empty one). `samples/native/README.md` explains which CSFs
  ATOMCI's SD-CI keeps and how the two examples were checked.
- The input manual, [`INPUT_MANUAL.md`](INPUT_MANUAL.md), describes both
  forms in full: every NAMELIST group (§§3–15), the `.inp` keys (§16),
  the output (§17) and the limits (§18).

## If something goes wrong

| Symptom | Cause and remedy |
|---|---|
| `make` stops with a message about LAPACK | Install `libblas-dev liblapack-dev` (step 1) and run `make` again. |
| `set ATOMCI_HOME to the installed ATOMCI` | Run the `export ATOMCI_HOME=...` line of step 3 in this shell. |
| `FAIL` with an empty energy | The run stopped. Look at the listing (`<name>.output`) for a non-zero `RETURN CODE` and at `<name>.err`. |
| `FAIL fpt` | `fpt` needs the `f.NO` of an `f` run in the same work directory; run `f` first (the scripts do). |
| An extra vector set or energy in the listing | The work directory was not empty. Use a new one per calculation. |
| `atinpgen` prints `error:` lines and writes no deck | The input has an error that ATOMCI would reject or misread; the message names it. |
