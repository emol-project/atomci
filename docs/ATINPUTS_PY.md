# `atinpgen` reference

`atinpgen` (the Python package `scripts/atinputs/`) writes an ATOMCI NAMELIST
deck, and the CSF list that goes with it, from a short `.inp` file. This is the
full reference of its input; [`INPUT_MANUAL.md`](INPUT_MANUAL.md) §16 is the
introduction, with the table of step keys.

## 1. Running it

Once installed (`make install`, see [`../INSTALL.md`](../INSTALL.md)),
`atinpgen` runs by name and finds its own package:

```sh
cd <work dir>
ln -sf "$ATOMCI_HOME/CFPTBL" ./CFPTBL
cp /path/to/atomci/samples/inp/f.bas .

"$ATOMCI_HOME/bin/atinpgen" /path/to/atomci/samples/inp/f.inp   # writes f.deck and f.csf
"$ATOMCI_HOME/bin/atomci" < f.deck > f.output
```

From a source tree without `make install`, put `scripts/` on `PYTHONPATH`:

```sh
PYTHONPATH=/path/to/atomci/scripts python3 -m atinputs /path/to/atomci/samples/inp/f.inp
```

The basis file named in the `.inp` is looked for in the current directory and
then next to the `.inp`. `atomci` itself reads it from the current directory, so
copy it there.

| Option | Effect |
|---|---|
| `--lint-only` | Run the checks and exit (0 if there is no error, 1 otherwise); nothing is written. |
| `--dump-atg` | Print the equivalent `atgen` input; write nothing. |
| `--dump-ir` | Print the deck's internal form as JSON; write nothing. |
| `--csf-source {python,atgen,file}` | Where the CSF list comes from (§4; default `python`). |
| `--style {jar,native}` | Deck formatting (§3.3; default `jar`). |

The checks of §5 always run: an error stops the generation.

## 2. The `.inp` format

A small indented format, deliberately not YAML: no type inference, so notations
such as `1-3,S-S` or `08` stay as written. The parser produces strings, and each
key's declared type converts them. `z: "9"` and `z: 9` are the same.

1. Nesting is by indentation: spaces only, exactly 2 per level. A tab in the
   indentation is an error.
2. `key: value`: the value runs to the end of the line.
3. A bare `key:` followed by an indented block is a nested mapping.
4. A line starting with `-` is a list item.
5. `k: v, k: v, …` on one line is an inline record. `ai: type: 2, idprnt: 0` and
   the nested form (`ai:` with `type:`, `idprnt:` indented below it) are the same.
6. `#` to the end of the line is a comment, except inside quotes.
7. Blank lines are ignored.

Quotes `"…"` make the text literal: blanks, `,`, `:` and `#` lose their meaning.
The only escapes are `\"` and `\\`. Quotes are needed when leading or trailing
blanks matter (`title: " F DOUBLET P "`), when a value in an inline record
contains a comma, and when a value contains `#`.

Errors name the line and the key, and suggest the closest key:

```
f.inp:12: unknown key 'itmx' in $.ctrl.mc (did you mean 'itmax'?)
f.inp:20: $.ctrl.tr.ind[0].last expects an integer (cannot parse '13x')
f.inp:8:  indentation contains a tab
```

## 3. Keys

| Key | Type | Written as |
|---|---|---|
| `title` | string | `&CNTL TITLE` |
| `deck`, `csf` | string | names of the deck and of the CSF list to write |
| `atom.z` | integer | `&AI Z` |
| `atom.ang` | string | `IORB = 2L+1` (S→1, P→3, D→5, …) |
| `atom.spin` | integer | `ISPIN` |
| `files.cfptable` | string | `OPEN UNIT=10 … BINARY STATUS=OLD` |
| `files.basis` | string | `OPEN UNIT=3 … STATUS=OLD` and `&AI IUNIT=3` |
| `files.format` | string | format of the basis file (`atomci`) |
| `files.mcp` | string | `OPEN UNIT=44 …` (optional) |
| `files.open[]` | records | further `OPEN` lines: `unit`, `file`, `format`, `status` |
| `orbital.frozen_core` | shells | `&MC CLOSED`, `atgen` CARD 5 |
| `orbital.active` | shells | occupied shells of the references, CARD 2 and 4 |
| `orbital.outer` | shells | number of correlating orbitals per l, CARD 1 |
| `reference[]` | records | `scf`, `occ` (`CSFS` notation, e.g. `2S*2 2P*5`) |
| `ctrl.ai/mc/wf/tr/pt/ex/ci/rs` | records | the steps and their parameters; the table is [`INPUT_MANUAL.md`](INPUT_MANUAL.md) §16.1 |
| `passes[]` | records | several passes (§7); replaces the top-level `ctrl` |
| `raw[]` | records | groups written directly (§6) |

Shells are `<count-or-n><letter>` tokens, comma-separated (`frozen_core: 1S, 2S`).
In `orbital.outer` the number is the **count** of correlating orbitals of that l,
not a principal quantum number: `outer: 3S` means three s orbitals. Every step key
except `ai.type` and `wf.rule` is optional, and a key not given is not written, so
the program's default applies.

### 3.1 What is derived

- **From the basis file:** `NSYM`, `NBF`, and with `orbital.outer` also `NOB` and
  `MPOB` (descending `NOB..1`). `NOB` of an l is its core and active shells plus the
  `outer` count, so a small `outer` leaves the highest vectors out of the CI
  (`NOB < NBF`). `ctrl.tr.from_record: N` writes the `&GET IND` rows `N, l, 1, NOB(l)`
  for every symmetry. A symmetry with `NOB = 0` would stop CIMAIN (return code 7120),
  so it is refused, as is an `outer` that needs more orbitals than the basis has.
- **From the references:** `ITNEL` is 2(2l+1) per `frozen_core` shell plus the
  occupations of the first reference. `IPAR` is Σ(l·count) over the first reference,
  mod 2. The checks make all references agree in both. `CLOSED` comes from
  `frozen_core`. `CSFS` has one element per reference marked `scf: true` (every
  reference when none is marked), plus the terminator `' )))'`.
- **`&CNTL NRNFG`:** 1 or 0 from the presence of `ctrl.ai`, `mc`, `wf`, `tr`, `pt`,
  `ex`, `ci`, `rs`, in that order.
- **Fixed:** the units of `CFPTBL` (10), the basis (3), the CSF list (2), `mcp` (44);
  `&GET IVCS=27`; `&CI NRNFG=1,1,1,0,1,1`.

### 3.2 Basis files

With `ai.type: 2` the basis file is GTF ([`INPUT_MANUAL.md`](INPUT_MANUAL.md) §6.3).
With `ai.type: 1` it is STF: pairs of orbital type and exponent (`2P 5.509`), ending
at a token starting with `)`; lines starting with `#` or `"` are comments, as for GTF.
`samples/inp/boron.basis.txt` is such a file.

### 3.3 Deck formatting

`--style jar` (default) writes lower-case group and parameter names and `Z` as an
integer (`z=9,`). The name records the origin of the format, the Java generator
`msekiya.jar`. `--style native` writes upper-case names and `Z=9.0D0`, like the
hand-written decks. Nothing else changes: the same parameters, order and line
breaks, and the program reads both the same way.

## 4. The CSF list

`--csf-source` chooses where it comes from:

| Value | Behavior |
|---|---|
| `python` (default) | A port of `atgen` in Python, needing nothing else. Its output is byte-identical to `atgen`'s on the inputs tested. |
| `atgen` | Runs the `atgen` binary on the input `--dump-atg` prints. Needs `ATOMCI_HOME`, or `atgen` on `PATH`. |
| `file` | Uses the file named by `csf:`, which must exist. |

One record of the list can stand for many CSFs. Here the upper line lists the
destination orbitals: one 2s electron goes to any of the 11 correlating s orbitals.

```
                              21 20 19 18 17 16 15 14 13 12 11S* 1  )
          2S* 1   )   2P* 5   ))
```

### 4.1 Limits of the `atgen` binary

These concern `.atg` files written by hand, or `--csf-source atgen`. `atinpgen`
sorts and wraps its own output, and its checks reject bad occupations.

- CARD 1 must list the l values in ascending order (S, P, D, F, …), or `NKIND`
  comes out wrong without a message.
- A CARD 3 line longer than 72 columns crashes `atgen`.
- A reference with exactly one active electron crashes `atgen`. The Python port
  does not crash on it, but its result has not been compared with anything.
- Active shells of one l must have consecutive n (`2S, 3S`, not `1S, 3S`):
  otherwise `atgen` stops (`STOP 922`).
- CARD 2 has two characters per shell, so a label like `10M` is cut to `10`.
- Shell capacities in `atgen` are 2(2l+1) up to f, but 2 for g, h, i and 50 for
  k, l, m.
- Comment lines: the `OPEN` … `END` header takes `"`, `#` or `/` as the first
  non-blank character; CARD 1–3 take `'` or `"` in column 1; CARD 4–6 take `"` in
  column 1.

## 5. Checks

Errors stop the generation. Warnings and notes are printed.

| Check | Level |
|---|---|
| `ctrl.tr.input_unit` is given (`&TR NFAII=27` was seen to crash with SIGFPE, probably a collision with `&GET IVCS=27`; leave it out and the safe default 18 applies) | error |
| `ctrl.tr` with both `ind` and `from_record`, or with neither | error |
| `tr.ind` or `mc.ind` row outside the basis | error |
| `tr.ind` or `mc.ind` rows that do not cover the orbitals of every symmetry exactly once | warning |
| `ci.ioflg` with more than six values, or with CI vectors and density matrices saved in different places | error |
| `NSYM`, `NBF`, `NOB`, `MPOB` inconsistent; a symmetry with `NOB = 0`; `outer` larger than the basis | error |
| References that disagree in electron count or parity | error |
| A reference with a shell not in `orbital.active`, or above the shell's capacity | error |
| `orbital.outer` with two counts for one l (`6D, 3D`) | error |
| More CSFs than `atgen`'s limit (an overestimate of the true limit) | error |
| `ctrl.rs` missing: the run prints no `SD-CI ENERGY` line | warning |
| `NRNFG` different from the usual setting for `&WF RULE` | warning |
| `atom.z` different from `ITNEL` (fine for an ion) | note |

## 6. Raw blocks and payloads

The keys of §3 derive NAMELIST parameters. A deck that cannot be derived, such as
`samples/native/boron.stdin` (orbitals in the deck, a hand-written CSF list), uses
raw blocks: explicit NAMELIST groups, and payloads, card data attached to a group.

### 6.1 Raw blocks

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

Each entry uses the bare `-` form with its fields indented below it; the one-line
form of `files.open` cannot hold a nested `params`.

**Raw wins.** A raw block replaces the block of the same group (ignoring case) that
the keys of §3 built, or is added in list order if there is none.

Values in `params` are typed by how they are written:

- Starting with `"`: one character value.
- Otherwise split at commas. If every token is a Fortran `'…'` string: one character
  value, or a character array when there are several.
- Otherwise the text is kept as written: `5.0D0` and `7` stay unchanged, and several
  tokens make a comma-joined list.

### 6.2 Payloads

```
raw:
  -
    group: BASVC
    params:
      idprnt: 0
      iunit: 5
    payload:
      kind: vectors           # basis, csf or vectors
      path: boron.basvc.txt
```

The file's lines are copied into the deck unchanged, right after the group. The path
is looked for in the current directory and then next to the `.inp`. `source: file` is
the default and the only implemented source. `IUNIT=5` on a group says that card
data follows it.

Each kind has its own closing parentheses, set by the routine that reads it:

| Payload | Reader | Rule |
|---|---|---|
| `basis` | `AIISTF`, `GINPUT` | One `)` closes the whole list. Too few is a soft `BASORB FORMAT ERROR` that can consume the next card. |
| `csf` | `WFGENS` | Three levels (shell, configuration, list) for `RULE>0`. For `RULE=0` the first `)` of the last run is enough. |
| `vectors` | `CARDVC` | One `)` per non-empty symmetry, nothing more. |

Extra `)` are harmless: they are skipped by the next read.

### 6.3 Checks of raw blocks

- `&BASVC`: the number of coefficients equals the sum of `NOB(i)*NBF(i)` of `&TR`.
- `basis` and `csf` payloads end in a line of `)` only; `vectors` has one such line
  per non-empty symmetry.
- `&TR ITVCI=0` needs a `&BASVC` block, and `ITVCI=1` needs `&GET`.
- `IUNIT=5` and a payload go together.
- A raw `&TR` must give `MPOB`. Without it the program silently uses the identity
  ordering, and prints a `*WARNING*`.

`samples/inp/boron.inp` is almost entirely raw blocks, with `boron.basis.txt`,
`boron.csf.txt` and `boron.basvc.txt` as payloads. `boron_nsdim700.inp` differs from
it by one line.

### 6.4 From a deck to an `.inp`

```sh
PYTHONPATH="$ATOMCI_HOME/lib" python3 -m atinputs.reverse deck.stdin -o outdir
```

This writes `outdir/deck.inp` with raw blocks and payload files. Each `&CNTL` starts
a new pass. The result gives the same energies as the deck, but not the same bytes.

## 7. Several passes

```
passes:
  -
    title: " F DOUBLET P "
    ctrl:
      ...
    raw:
      - ...
  -
    title: " F DOUBLET P (NO 1) "
    ctrl:
      ...
```

Without `passes`, the top-level `title`, `ctrl` and `raw` make one pass. Each pass has
its own `ctrl` and optional `raw`. **Nothing is inherited**: each pass states all its
parameters. The reason lies in the program, where what carries between passes differs
by parameter:

- `&TR MPOB` must be repeated. `TRMAIN` resets it before every read, and without it
  the program uses the identity ordering.
- `&TR NBF` is overwritten from the integral file's header when orbitals come from
  files, so repeating it changes nothing.
- `&TR NOB` and the parameters of `&CI` and `&RS` carry over only because the build
  uses `-fno-automatic`.
- `&TR NSYM` is checked against the integral file, and a mismatch is an error.
- A pass whose `NRNFG` asks for a group that its input lacks stops with an error.

A deck written by hand should therefore repeat these parameters too.
`samples/inp/f.inp` is a three-pass example.

## 8. What the short form does not cover

A coupling order other than the order of `orbital.active`, and CSF lists other than
the SD list (intermediate-coupling ranges, symbolic occupations, excitations beyond
doubles). These need a raw `&WF` with a `csf` payload. See also
[`INPUT_MANUAL.md`](INPUT_MANUAL.md) §16.3.
