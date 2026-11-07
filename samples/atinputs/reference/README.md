# samples/atinputs/reference/ — reference files of the tests

The test suite of `atinpgen` compares its output with these files.

| Files | What they are | Compared with |
|---|---|---|
| `f.deck`, `fpt.deck` | decks written by the Java generator `msekiya.jar` from `../f.xml`, `../fpt.xml` | `atinpgen ../f.inp`, `../fpt.inp` with the default `--style jar`, byte for byte |
| `f.csf`, `fpt.csf` | CSF lists written by the same generator | not compared: another format of equivalent content |
| `f.atgen.csf`, `fpt.atgen.csf` | CSF lists written by `atgen` | the Python port of `atgen`, byte for byte |

The two kinds of CSF list look different (numbering of the correlating orbitals,
columns, order), but either one in the same deck gives the same energies.

These decks are one-pass calculations, so they are not the same decks as
`../../native/f.stdin`, which has three passes.
