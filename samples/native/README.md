# samples/native/ — every example as a NAMELIST deck

> ← Back to [`../README.md`](../README.md).

The input that `atomci` itself reads: a deck (`*.stdin`), an `atgen` input
(`*.atg`) that writes the CSF list of an SD-CI, and a basis file (`*.bas`).
This directory is a closed set: everything these nine calculations read is
here, and nothing is taken from another directory. The same calculations as
`.inp` files are in [`../inp/`](../inp/README.md), which has its own copies
of the basis files.

| Files | Atom, term | Calculation | Answer (hartree) |
|---|---|---|---|
| `boron.stdin` | B 2s²2p ²Pᵒ | general CI over a hand-written CSF list, STF basis and orbitals in the deck | `ET = -24.6461953967` |
| `boron_nsdim700.stdin` | same | same, with the CI matrix diagonalized directly | `ET = -24.6461953996` |
| `f.{atg,bas,stdin}` | F 2s²2p⁵ ²Pᵒ | SCF, SD-CI; SD-CI on its natural orbitals; RS with Bunge's estimate | SD-CI −99.641223, −99.641037, −99.641037 |
| `fpt.{atg,stdin}` | same | SD-CI with perturbative selection on the natural orbitals of `f` (uses `f.bas`) | SD-CI −99.640355 |
| `sc.{atg,bas,stdin,output}` | Sc 3d 4s² ²D | cc-pVTZ, MCSCF, SD-CI of the 4s and 3d electrons | MCSCF −759.73544953, SD-CI −759.776305 |
| `ti.{atg,bas,stdin,output}` | Ti 3d² 4s² ³F | same | MCSCF −848.40561072, SD-CI −848.458805 |
| `cu.{atg,bas,stdin,output}` | Cu 3d¹⁰ 4s ²S | same | MCSCF −1638.96192568, SD-CI −1639.376374 |
| `be.{atg,bas,stdin,output}` | Be 2s² ¹S | cc-pVTZ, MCSCF of 2s² + 2p², SD-CI from both references | MCSCF −14.61643826, SD-CI −14.618544 |
| `c.{atg,bas,stdin,output}` | C 2s²2p² ³P | cc-pVTZ, MCSCF of 2s²2p² + 2p⁴, SD-CI from both references | MCSCF −37.70402270, SD-CI −37.779409 |

The first four form the regression suite of the build; see
[`../README.md`](../README.md). The shipped outputs were made with gfortran
14.2.0 on Debian 13. Each of the five cc-pVTZ runs takes 1 to 2 seconds.

## Running

```sh
export ATOMCI_HOME=...     # after `make install` at the top of the repository
./run_native.sh            # all nine, or name some: ./run_native.sh be c
```

For each calculation, `run_native.sh` makes a work directory (`work/<name>/`,
or `$NATIVE_WORK/<name>/`), links `CFPTBL`, copies the basis file, runs
`atgen` and `atomci`, and compares the energy with the answer above. `fpt`
runs in the work directory of `f`, whose natural orbitals (`f.NO`) it reads,
so run `f` first. By hand, for Sc:

```sh
mkdir -p ~/atomci-runs/sc && cd ~/atomci-runs/sc
ln -sf "$ATOMCI_HOME/CFPTBL" CFPTBL
cp "$repo/samples/native/sc.bas" .
"$ATOMCI_HOME/bin/atgen"  < "$repo/samples/native/sc.atg"            # writes sc.csf
"$ATOMCI_HOME/bin/atomci" < "$repo/samples/native/sc.stdin" > sc.output
```

## Transition-metal atoms: `sc`, `ti`, `cu`

Each deck does AI → MCSCF → WF → TR → CI → RS:

1. Integrals in a cc-pVTZ GTO basis.
2. MCSCF orbitals for one CSF of the ground term.
3. SD-CI of the 4s and 3d electrons, with 1s 2s 2p 3s 3p frozen (329, 988
   and 345 configurations).

For comparison, the numerical Hartree–Fock energies of the same terms
(ATSP's hf) are −759.73572, −848.40600 and −1638.96374. The cc-pVTZ MCSCF
lies within 2 mEh of them.

### What to change for another atom or term

The decks follow `f.stdin` and `f.atg`. For a 3d atom:

- `&AI Z`; `&MC` and `&WF` `ITNEL` (electrons), `ISPIN` (2S+1), `IORB`
  (2L+1) and `IPAR`.
- `&MC CLOSED` (the core) and `CSFS`, the occupied open shells.
  **Write the shells in ATOMCI's coupling sequence: by l, then by n** (4s
  before 3d, as the MCSCF prints "coupling sequence of shells"). Until
  2026-11-03, `' 3D*1) 4S*2 ))'` made the MCSCF read no configuration and
  run on the closed shells alone, without an error. It now stops with
  `=== shell  4S follows a D shell: ...` (MCMAIN return code 99).
- `&TR NBF`, `NOB`, `MPOB` and `&GET IND`: the number of contracted
  functions per l of the basis (here 7 s, 6 p, 4 d, 2 f, 1 g).
- The `.atg` (input of `atgen`): the number of correlating orbitals per l
  (the basis functions of that l minus the occupied and core orbitals),
  the occupied shells, the reference, the coupling order (again 4S before
  3D), and the core shells.

## Multi-reference SD-CI: `be`, `c`

Two light atoms whose ground term needs two configurations from the start.
Each deck does AI → MCSCF → WF → TR → CI → RS:

1. Integrals in a cc-pVTZ GTO basis (4s 3p 2d 1f contracted functions).
2. MCSCF orbitals for the two reference configurations together.
3. SD-CI from both references, with 1s frozen (16 and 92 CSFs).

### What differs from a single-reference deck

- `&MC CSFS` has one element per reference, each with every open shell
  of the references (`2S*0` where a shell is empty):
  `CSFS=' 2S*2) 2P*2 ))', ' 2S*0) 2P*4 ))', ' )))'`.
- CARD 3 of the `.atg` lists the same references, one per line.
- `ITNEL` is the number of electrons of one reference, not of all of
  them.

### How the answers were checked

On the same basis, PySCF 2.14.0 was run independently of ATOMCI:

- **MCSCF.** CASSCF over 2s and 2p with 1s doubly occupied gives the
  same energies to all ten decimals: for Be the lowest ¹S root, for C
  the average of the three ³P components.
- **Be SD-CI.** A determinant CI in the SD space of the two references
  on those orbitals gives −14.6185438678. With two electrons outside the
  core, every CSF of that space interacts with a reference.
- **C SD-CI.** A determinant CI over all SD configurations gives
  −37.7801598881. ATOMCI's SD-CI keeps 92 of the 147 CSFs of those
  configurations: those with a non-zero matrix element with the
  references (WFMAIN, routine `WFETAP`; see
  [`../../docs/INPUT_MANUAL.md`](../../docs/INPUT_MANUAL.md) §1), and
  gives −37.779409. A general CI over all 147 CSFs, run with ATOMCI
  itself (the list from `atgen` with CARD 6 = `0`, `&WF RULE=0`, an
  `&EX` group), gives −37.78015986, the determinant value.

## The basis files

`make_basis.py` writes the cc-pVTZ basis of an element from PySCF's basis
library, in the format of `cinewx.f` `GINPUT`: one block per contracted
function, `<l> <nterm> <scale>`, then the exponents and the coefficients.
Note the format's limits:

- Numbers must be fixed point, since the free-format reader `readfa` has
  no exponent field (a number like `8.147221E-06` stops the run with
  `BASORB FORMAT ERROR`). `make_basis.py` rewrites such numbers as
  `0.000008147221` with Python's `Decimal`, which keeps every digit, and
  `readfa` reads any number of digits into `real*8`.
- Lines are at most 80 columns. The reader takes 80 characters per line
  and drops the rest without an error, so keep generated lines short.
- The file ends with `))`.

The shipped `sc`, `ti`, `cu`, `be` and `c` files were written with PySCF
2.14.0:

```sh
python make_basis.py Sc sc.bas
```

The basis of Sc, Ti and Cu: N. B. Balabanov and K. A. Peterson, J. Chem.
Phys. 123, 064107 (2005), as distributed by the Basis Set Exchange. Those of
Be and C: PySCF's copy of the cc-pVTZ basis of the Basis Set Exchange.
