# samples/ — example inputs

Nine calculations, each with its answer. A step-by-step walk-through is
[`../docs/TUTORIAL.md`](../docs/TUTORIAL.md).

## Two input forms

Every calculation is given in both input forms that ATOMCI supports:

1. **NAMELIST deck** (`*.stdin`, with an `atgen` input `*.atg` for the
   SD-CI list): what `atomci` itself reads. In
   [`native/`](native/README.md).
2. **`.inp` file**: a short description from which `atinpgen` writes the
   deck and the CSF list. In [`inp/`](inp/README.md).

Each of the two directories is flat and closed: it holds every file its
calculations read (the basis files are in both), and neither uses the
other. Both give the same energies. Each has a script that runs its nine
calculations and prints `OK` or `FAIL` against the answers:

```sh
export ATOMCI_HOME=...      # after `make install`
native/run_native.sh        # boron boron_nsdim700 f fpt sc ti cu be c
inp/run_inp.sh              # the same nine from the .inp files
```

## The calculations

| Name | Atom, term | Calculation | Answer (hartree) |
|---|---|---|---|
| `boron` | B 2s²2p ²Pᵒ | general CI over a hand-written CSF list, Slater-type basis | `ET = -24.6461953967` |
| `boron_nsdim700` | same | same, with the CI matrix diagonalized directly | `ET = -24.6461953996` |
| `f` | F 2s²2p⁵ ²Pᵒ | SCF, SD-CI; SD-CI on its natural orbitals; RS with Bunge's estimate | SD-CI −99.641223, −99.641037, −99.641037 |
| `fpt` | same | SD-CI with perturbative selection on the natural orbitals of `f` | SD-CI −99.640355 |
| `sc`, `ti`, `cu` | Sc 3d4s² ²D, Ti 3d²4s² ³F, Cu 3d¹⁰4s ²S | cc-pVTZ, MCSCF, SD-CI of the 4s and 3d electrons | −759.776305, −848.458805, −1639.376374 |
| `be`, `c` | Be 2s² ¹S, C 2s²2p² ³P | cc-pVTZ, two-configuration MCSCF, multi-reference SD-CI | −14.618544, −37.779409 |

The first four are the regression suite of the build; see
[INSTALL.md → "Verifying the build"](../INSTALL.md#verifying-the-build).
`f` and `fpt` run in the same work directory, `f` first: `fpt` reads
`f.NO`, the natural-orbital file `f` writes. Every other calculation needs a
work directory of its own: a stale `fort.*` from an earlier run appends an
extra vector set.

## `atinputs/`

[`atinputs/`](atinputs/README.md) holds the test inputs of the generator
`atinpgen` and its frozen reference decks, used by
`scripts/atinputs/tests/`, with its own `f.bas`. `f_no.inp` and `b_stf.inp`
there show two more uses of the short form; `f.xml` and `fpt.xml` are inputs of
the archived Java generator.

## `boron_nsdim700`

It is `boron.stdin` with one change, `&CI NSDIM=100 → NSDIM=700`. With
`NSDIM` (700) ≥ `NKEEP` (673) the run takes the direct (non-Davidson)
diagonalization branch of `DIAGDR` (`cici.f`), which the other samples never
reach. Its energy, `-24.6461953996`, is the state the Davidson path finds
(`-24.6461953967`) to 8 decimals: direct diagonalization is at machine
precision, Davidson at its `IPS=7` threshold.
