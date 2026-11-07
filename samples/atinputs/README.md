# samples/atinputs/ — test inputs of `atinpgen`

> ← Back to [`../README.md`](../README.md). To learn the `.inp` form, start from
> [`../inp/`](../inp/README.md). The format is described in
> [`docs/ATINPUTS_PY.md`](../../docs/ATINPUTS_PY.md).

The inputs and reference files of the generator's test suite
(`scripts/atinputs/tests/`; see [`INSTALL.md`](../../INSTALL.md#testing-atinpgen)).

| File | Calculation | Answer (hartree) |
|------|-------------|---------------------|
| `f.inp` | F 2s²2p⁵ ²Pᵒ, one pass: SCF, SD-CI | SD-CI −99.641223 |
| `fpt.inp` | same, SD-CI with perturbative selection on the natural orbitals of `f` | SD-CI −99.640355 |
| `f_no.inp` | the three passes of `samples/native/f.stdin` in short form | SD-CI −99.641223, then −99.641037 twice |
| `b_stf.inp` | B 2s²2p ²Pᵒ, STF basis file, SCF, SD-CI with `NOB < NBF` | SD-CI −24.599517 |
| `boron.inp` | general CI, raw blocks and payloads | `ET = -24.6461953967` |
| `boron_nsdim700.inp` | same, direct diagonalization | `ET = -24.6461953996` |

The other files: `f.bas` and `boron.*.txt`, the data these read;
[`reference/`](reference/README.md), the reference decks and CSF lists; `f.xml` and
`fpt.xml`, the same `f` and `fpt` as inputs of the archived Java generator
([`docs/ATINPUTS_MANUAL.md`](../../docs/ATINPUTS_MANUAL.md)).

They run like the other examples:

```sh
mkdir -p ~/atomci-runs/fx && cd ~/atomci-runs/fx
ln -sf "$ATOMCI_HOME/CFPTBL" ./CFPTBL
cp "$repo/samples/atinputs/f.bas" .
"$ATOMCI_HOME/bin/atinpgen" "$repo/samples/atinputs/f.inp"    # writes f.deck and f.csf
"$ATOMCI_HOME/bin/atomci" < f.deck > f.output
```

`fpt.inp` reads `f.NO`, so run it after `f.inp` in the same directory. `b_stf.inp` needs
`boron.basis.txt` in the work directory.

To run the archived Java generator, obtain CERN Colt 1.0.2 (`colt.jar`) separately;
it is not distributed here:

```sh
CP="$repo/attic/msekiya-jar/msekiya.jar:<path>/colt.jar"
java -cp "$CP" org.atomci.msekiya.atgen.Main "$repo/samples/atinputs/f.xml"
```
