"""The intermediate representation between sugar and the emitter.

Plain data, deliberately not tied to the input format: everything from
here down (emitter, formatting rules, lint) is expected to survive even
if the input format itself changes.

Field order within each dataclass matches emission order.
"""

from dataclasses import dataclass, field, asdict


@dataclass
class OpenLine:
    unit: int
    file: str
    format: str = ""
    status: str = ""


@dataclass
class Payload:
    """Free-form card data following a NAMELIST group (e.g. &BASVC's
    inline coefficient matrix, or CSF-list cards). `kind` is
    'basis' | 'csf' | 'vectors'; `lines` are the sidecar's lines, copied
    through verbatim by the emitter with no reformatting."""

    kind: str = ''
    lines: list = field(default_factory=list)


@dataclass
class QuotedStr:
    """A single-quoted Fortran string literal, e.g. TITLE, CLOSED."""

    value: str


@dataclass
class StringArray:
    """A Character array emitted as one indexed line per element, e.g. CSFS."""

    values: list


@dataclass
class IntList:
    """A numeric array, comma-joined and wrapped every `wrap` values (None
    = no wrapping, all on one line)."""

    values: list
    wrap: object = None  # int | None


@dataclass
class RealScalar:
    """A value that is declared REAL in the native NAMELIST regardless of
    the Python type holding it -- currently only &AI Z (an integer atomic
    number, but REAL in Fortran). The jar's own generated decks render it
    as a plain integer literal ('z=9,', confirmed byte-for-byte against
    reference/f.deck);
    the hand-written native decks render the same value as a D-exponent
    real literal ('Z=9.0D0'). Both are valid Fortran NAMELIST input for a
    REAL variable; which one is emitted is purely presentational and is
    `emit()`'s `style` parameter's job, not sugar.py's."""

    value: object


@dataclass
class Block:
    group: str  # "AI" | "MC" | "WF" | "TR" | "GET" | "PT" | "EX" | "CI" | "RS"
    # name -> int/float (plain) | QuotedStr | StringArray | IntList
    params: dict = field(default_factory=dict)
    payload: object = None  # Payload | None


@dataclass
class Pass:
    title: str
    nrnfg: list  # 8 ints, &CNTL NRNFG(1..8)
    blocks: list = field(default_factory=list)  # [Block]


@dataclass
class Deck:
    open: list = field(default_factory=list)  # [OpenLine]
    passes: list = field(default_factory=list)  # [Pass]


def to_jsonable(deck):
    """Convert a Deck to plain dict/list/scalar for --dump-ir. dataclasses.asdict
    already recurses through nested dataclasses (OpenLine, Pass, Block, Payload)."""
    return asdict(deck)
