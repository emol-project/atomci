"""IR -> deck text.

Formatting rules, confirmed byte-for-byte against the frozen jar decks
(samples/atinputs/reference/{f,fpt}.deck):

- NAMELIST terminator is '/' (not '&END'); group lines are ' &group'
  (one leading space, lowercase group name); the block closes with ' /'.
- Parameter lines have NO leading space/indentation and always end in a
  trailing comma, including the last parameter before ' /'.
- Numeric arrays are comma-joined; when wrapped, continuation lines carry
  no 'name=' prefix and no indentation. MPOB wraps flat at 10 values per
  line regardless of symmetry boundaries; IND wraps at 4 (one (record, l,
  first, last) tuple per line). Z is a plain integer literal in the jar's
  output ('z=9,'), not the '9.0D0' form used by hand-written native decks.
- CSFS (a Character array) is the exception to "one name= per block": one
  'name(i)=' line per string element.
- The OPEN-directive block ends with a literal 'END' line, directly
  followed by the first '&group' line (no blank line between them). The
  whole deck ends with a trailing blank line after the final ' /'.

**A line-length audit**, prompted by the CSF-file 72-column
wrap (`csfgen/format.py`) turning out to be a real native constraint that
this module's own "long lines can be emitted as-is" assumption shares the
shape of, if not the specifics:

- MPOB/NBF/NOB (`IntList`, `&TR`): **no constraint exists** — confirmed by
  direct testing (a standalone probe program declaring the exact native
  types, `INTEGER*4 MPOB(150), NBF(20), NOB(20)`, `NAMELIST /TR/`), not
  inferred from the frozen samples. A single unwrapped 497-character line
  filling MPOB to its full 150-element capacity reads identically to the
  10-per-line wrapped form under gfortran 14.2.0 — NAMELIST list-directed
  READ has no line-width limit here. The existing 10-per-line/4-per-line
  wrapping above is a readability/jar-compatibility convention only.
  (`MPOB(150)`/`NBF(20)`/`NOB(20)`/`IND(4,100)` do have real array-*size*
  bounds, a different constraint class from line length and not audited
  here; `lint.py` already cross-checks `len(MPOB[i])` against `NOB[i]`
  per-symmetry, but not the overall array capacities.)
- CSFS (`StringArray`, `&MC`): **a real constraint exists**, and unlike
  the CSF file there is no wrap to implement — `CSFS` is `CHARACTER*72`
  (`src/mcmain.f`) with no continuation across array elements
  (`src/mcmcsf.f`'s `GET_NEXT`: running past column 72 mid-configuration
  is a hard parse error). A reference configuration whose rendered line
  exceeds 72 characters simply cannot be represented in this field.
  `lint.py`'s `_csf_lint` now rejects that case before emission (mirroring
  this codebase's existing convention of turning native hard-failures
  into lint errors) rather than silently writing a deck `MCMCSF` would
  reject or a NAMELIST read would silently truncate. See
  `sugar.csfs_reference_line`'s docstring for the full mechanism.

## `style`

`emit(deck, style='jar' | 'native')`. `'jar'` is the default and covers
everything documented above. `'native'` changes two
purely presentational things, matching the hand-written decks
(`samples/native/*.stdin`): group and parameter names are uppercase (` &AI`,
`Z=`, not ` &ai`, `z=`), and any `RealScalar`-wrapped value (currently
just `&AI Z`) renders as a Fortran D-exponent literal (`Z=9.0D0`) instead
of a plain number. Everything else — which params appear, their order,
array wrapping, quoting, the `OPEN`/`END` header — is identical between
styles; `tests/test_style_equivalence.py` proves this with a
case-and-numeric-literal-normalizing property test across a generated
sweep, not just `f`/`fpt`.

`'jar'` stays the default: `samples/atinputs/reference/` is the frozen
byte-for-byte comparison baseline for the whole regression suite
(`test_end_to_end_matches_frozen_reference`), and changing the default
would break it. The name records the origin of the format, `msekiya.jar`.

## Payload passthrough

A `Block` whose `payload` is not `None` gets its `payload.lines` appended
verbatim after the ` /` terminator, with no `style`-dependent formatting
applied (not case-folded, not reflowed) -- payload content is opaque to
the emitter, copied through from sidecar to deck exactly as authored.
`f`/`fpt` never set a payload, so this is inert for both frozen-reference
decks.
"""

from .ir import QuotedStr, StringArray, IntList, RealScalar

_STYLES = ('jar', 'native')


def _format_number(value):
    if isinstance(value, bool):
        return '1' if value else '0'
    return str(value)


def _format_native_real(value):
    """Fortran D-exponent literal, e.g. 9 -> '9.0D0'. Only ever applied to
    a RealScalar's value (currently just Z), so an integer-valued float is
    the only case that actually occurs; the general (non-integer) branch
    is a reasonable extension, not separately exercised."""
    f = float(value)
    if f == int(f):
        return f'{int(f)}.0D0'
    text = repr(f)
    return text.upper().replace('E', 'D') if 'e' in text else f'{text}D0'


def _render_intlist(name, intlist, style):
    values = intlist.values
    wrap = intlist.wrap
    chunks = [values[i:i + wrap] for i in range(0, len(values), wrap)] if wrap else [values]
    lines = []
    for i, chunk in enumerate(chunks):
        prefix = f'{name}=' if i == 0 else ''
        lines.append(prefix + ','.join(_format_number(v) for v in chunk) + ',')
    return lines


def _render_block(block, style):
    group = block.group if style == 'native' else block.group.lower()
    lines = [f' &{group}']
    for name, value in block.params.items():
        pname = name.upper() if style == 'native' else name
        if isinstance(value, QuotedStr):
            lines.append(f"{pname}='{value.value}',")
        elif isinstance(value, StringArray):
            for i, v in enumerate(value.values):
                lines.append(f"{pname}({i + 1})='{v}',")
        elif isinstance(value, IntList):
            lines.extend(_render_intlist(pname, value, style))
        elif isinstance(value, RealScalar):
            rendered = (_format_native_real(value.value) if style == 'native'
                        else _format_number(value.value))
            lines.append(f"{pname}={rendered},")
        else:
            lines.append(f"{pname}={_format_number(value)},")
    lines.append(' /')
    if block.payload is not None:
        # Card data is opaque to the emitter by design: copied through
        # verbatim, no reformatting, no computed terminator -- whatever
        # the sidecar contains is what gets emitted.
        lines.extend(block.payload.lines)
    return lines


def _render_open(open_lines):
    lines = []
    for o in open_lines:
        parts = [f'OPEN UNIT={o.unit} FILE={o.file}']
        if o.format:
            parts.append(o.format.upper())
        if o.status:
            parts.append(f'STATUS={o.status.upper()}')
        lines.append(' '.join(parts))
    lines.append('END')
    return lines


def emit(deck, style='jar'):
    if style not in _STYLES:
        raise ValueError(f"unknown style {style!r}, expected one of {_STYLES}")
    lines = _render_open(deck.open)
    for p in deck.passes:
        for block in p.blocks:
            lines.extend(_render_block(block, style))
    return '\n'.join(lines) + '\n\n'
