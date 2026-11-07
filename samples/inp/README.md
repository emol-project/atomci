# samples/inp/ — every example as an `.inp` file

> ← Back to [`../README.md`](../README.md).

ATOMCI reads its input as a NAMELIST deck (the `*.stdin` files of
[`../native/`](../native/README.md)). The same
calculations can be written in the shorter `.inp` form, from which the
generator `atinpgen` writes the deck and its CSF list. This directory
holds one `.inp` for each of those calculations; the deck it generates
gives the same energies as the hand-written one.

This directory is a closed set: everything these nine calculations read
is here (the `.inp` files, the basis files `*.bas` and the `.txt` files
of `boron`), and nothing is taken from `../native/`.

| File | Same as | Atom, term | Calculation | Answer (hartree) |
|---|---|---|---|---|
| `boron.inp` (+ `boron.basis.txt`, `boron.csf.txt`, `boron.basvc.txt`) | `../native/boron.stdin` | B 2s²2p ²Pᵒ | general CI, STF basis and orbitals in the deck | `ET = -24.6461953967` |
| `boron_nsdim700.inp` (+ the same three files) | `../native/boron_nsdim700.stdin` | same | same, direct diagonalization | `ET = -24.6461953996` |
| `f.inp` (+ `f.bas`) | `../native/f.stdin` | F 2s²2p⁵ ²Pᵒ | SCF, SD-CI; SD-CI on its natural orbitals; RS with Bunge's estimate | SD-CI −99.641223, −99.641037, −99.641037 |
| `fpt.inp` (+ `f.bas`) | `../native/fpt.stdin` | same | SD-CI with perturbative selection on the natural orbitals of `f` | SD-CI −99.640355 |
| `sc.inp` (+ `sc.bas`) | `../native/sc.stdin` | Sc 3d4s² ²D | cc-pVTZ, SCF, SD-CI of the 4s and 3d electrons | SD-CI −759.776305 |
| `ti.inp` (+ `ti.bas`) | `../native/ti.stdin` | Ti 3d²4s² ³F | same | SD-CI −848.458805 |
| `cu.inp` (+ `cu.bas`) | `../native/cu.stdin` | Cu 3d¹⁰4s ²S | same | SD-CI −1639.376374 |
| `be.inp` (+ `be.bas`) | `../native/be.stdin` | Be 2s² ¹S | cc-pVTZ, MCSCF of 2s² + 2p², SD-CI from both references | SD-CI −14.618544 |
| `c.inp` (+ `c.bas`) | `../native/c.stdin` | C 2s²2p² ³P | cc-pVTZ, MCSCF of 2s²2p² + 2p⁴, SD-CI from both references | SD-CI −37.779409 |

The first four form the regression suite of the build; `sc`, `ti` and
`cu` are transition-metal examples, `be` and `c` multi-reference examples
(see [`../native/README.md`](../native/README.md)).

`boron.inp` and `boron_nsdim700.inp` describe a general CI over a
hand-written CSF list with orbitals given in the deck. That has no short
form, so their groups are written as `raw:` blocks and the card data is
read from the three `.txt` files next to them. The other seven use the
short form only. The `.inp` format is described in
[`../../docs/INPUT_MANUAL.md`](../../docs/INPUT_MANUAL.md) §16.

## Running them

```sh
export ATOMCI_HOME=...     # after `make install` at the top of the repository
./run_inp.sh               # all nine, or name some: ./run_inp.sh f fpt
```

For each calculation, `run_inp.sh` makes a work directory
(`work/<name>/`, or `$INP_WORK/<name>/`), links `CFPTBL`, copies the
basis file, runs `atinpgen` and then `atomci`, and compares the energy
with the answer above. It prints `OK` or `FAIL` per calculation and
exits with status 0 only if all are `OK`. `fpt` runs in the work
directory of `f`, whose natural orbitals (`f.NO`) it reads, so run `f`
first.

By hand, for F:

```sh
mkdir -p ~/atomci-runs/f && cd ~/atomci-runs/f
ln -sf "$ATOMCI_HOME/CFPTBL" CFPTBL
cp "$repo/samples/inp/f.bas" .
"$ATOMCI_HOME/bin/atinpgen" "$repo/samples/inp/f.inp"   # writes f.deck and f.csf
"$ATOMCI_HOME/bin/atomci" < f.deck > f.output
grep -a 'SD-CI ENERGY  ' f.output
```

The hand-written decks are run the same way by
[`../native/run_native.sh`](../native/run_native.sh).
