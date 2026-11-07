"""Key definitions, types, required/optional — the 1:1 port of f.xml/fpt.xml.
This is also where the parser's structural-vs-inline ambiguity gets resolved:
a value node is either a structural Mapping/NodeList (built by the parser
from an indented block) or a RawValue (built from one line); coerce_*
accepts either for record-typed keys.

Error messages follow one convention: "<file>:<line>: <message>", with
did-you-mean suggestions for unknown keys.
"""

import difflib
import re
from dataclasses import dataclass

from .parser import RawValue, Mapping, NodeList, _split_top_level
from .constants import ANGULAR_MOMENTUM_LETTERS
from .ir import IntList, QuotedStr, StringArray

_SHELL_RE = re.compile(r'^(\d+)([A-Za-z])$')


class SchemaError(Exception):
    def __init__(self, message, filename, line):
        self.message = message
        self.filename = filename
        self.line = line
        super().__init__(f"{filename}:{line}: {message}")


# --- type declarations ---------------------------------------------------

class Str:
    pass


class Int:
    pass


class Float:
    pass


class Bool:
    pass


class Ints:
    """A list of integers, separated by blanks or commas: 'ioflg: 0 -1 -1 0 0'.
    Blanks are needed inside an inline record ('ci: ioflg: 0 -1 -1 0 0,
    ips: 7'), where a comma would end the field."""


class Floats:
    """A list of reals, separated like Ints."""


class Shells:
    """Comma-separated shorthand shell list: 'frozen_core: 1S' or
    'outer: 11S, 10P, 6D, 5F'. Each token is nL (principal quantum number
    + spectroscopic letter). Coerces to a list of {'label','n','l'}."""


class RawParams:
    """A raw NAMELIST block's params: an arbitrary
    key -> value mapping, no fixed field set. Must be a true nested
    Mapping (indented block), not a single-line inline record -- an
    inline record's top-level-comma split would misparse a value like
    'nbf: 10,9,8,8,6,4,2' as several fields instead of one comma-joined
    list. Each value is classified generically, with no per-key-name
    branching ("resist per-group logic", extended here
    to per-param-name):

    - text starts with '\"' (before dequoting) -> a Fortran CHARACTER
      value -> ir.QuotedStr(dequoted text). Same convention already used
      by top-level 'title:'.
    - otherwise, split on top-level commas. If every resulting token is
      itself a native Fortran '...'-quoted string (as it already is, read
      straight off a .stdin by reverse.py) -> one token -> QuotedStr(its
      dequoted content); more than one -> ir.StringArray(their dequoted
      contents) (emit.py already renders one NAME(i)='...' line per
      element -- that rendering isn't sugar-specific, sugar.py's &MC CSFS
      just happens to be its other producer).
    - otherwise (not all-quoted -- the numeric case): one token -> passed
      through as a plain string (emit.py's fallback branch already
      renders a plain string verbatim, so a D-exponent literal like
      '5.0D0' or a bare int like '7' survive unchanged); more than one
      token -> ir.IntList(values=[tokens], wrap=None) (comma-joined,
      unwrapped -- emit.py's own line-length audit found no real NAMELIST
      constraint to wrap for)."""


@dataclass
class Record:
    fields: dict  # name -> Field


@dataclass
class ListOfRecord:
    item: Record


@dataclass
class Field:
    type: object
    required: bool = True


def field(type, required=True):
    return Field(type, required)


# --- schema tree ----------------------------------------------------------

_OPEN_LINE = Record({
    'unit': field(Int()),
    'file': field(Str()),
    'format': field(Str(), required=False),
    'status': field(Str(), required=False),
})

_IND = Record({
    'record': field(Int()),
    'l': field(Int()),
    'first': field(Int()),
    'last': field(Int()),
})

# Every step key except the run-defining ones (ai.type, wf.rule) is
# optional: an absent key is not emitted, so the native default applies
# (docs/namelist.002). The keys after the first few of each step were added
# 2026-11-03; each maps to the NAMELIST member of the same name unless noted.
_CTRL = Record({
    'ai': field(Record({
        'type': field(Int()),
        'idprnt': field(Int(), required=False),
    }), required=False),
    'mc': field(Record({
        'itmax': field(Int(), required=False),
        'ethr': field(Float(), required=False),
        'c2thr': field(Float(), required=False),
        'nsol': field(Int(), required=False),
        'nset': field(Int(), required=False),     # default constants.MC_NSET
        'nopt': field(Ints(), required=False),
        'ind': field(ListOfRecord(_IND), required=False),  # starting orbitals
    }), required=False),
    'wf': field(Record({
        'rule': field(Int()),
        'npflg': field(Int(), required=False),
        'ismax': field(Int(), required=False),
        'irmax': field(Int(), required=False),
    }), required=False),
    'tr': field(Record({
        'input_unit': field(Int(), required=False),
        'record': field(Int(), required=False),
        'ind': field(ListOfRecord(_IND), required=False),
        # &GET IND for every symmetry, orbitals 1..NOB, from this record
        'from_record': field(Int(), required=False),
        'nbase': field(Int(), required=False),    # &GET NBASE
    }), required=False),
    'pt': field(Record({
        'cthr': field(Float(), required=False),
        'ethr': field(Float(), required=False),
        'how': field(Int(), required=False),
        'nstate': field(Int(), required=False),   # &PT NSOLVE
        'istate': field(Int(), required=False),
        'ips': field(Int(), required=False),
        'pthr': field(Float(), required=False),
        'nrnfg': field(Ints(), required=False),
    }), required=False),
    'ex': field(Record({
        'retry': field(Bool(), required=False),
        'nfexw': field(Int(), required=False),
        'nfexe': field(Int(), required=False),
    }), required=False),
    'ci': field(Record({
        'ips': field(Int(), required=False),
        'maxit': field(Int(), required=False),
        'nsdim': field(Int(), required=False),
        'nstate': field(Int(), required=False),
        'nfiv': field(Int(), required=False),
        'ioflg': field(Ints(), required=False),   # default constants.CI_IOFLG
        'inflg': field(Ints(), required=False),
        'thrcsf': field(Float(), required=False),
        'xref': field(Floats(), required=False),
    }), required=False),
    'rs': field(Record({
        'print': field(Float(), required=False),  # &RS PTHR
        'nrnfg': field(Int(), required=False),
        'rule': field(Int(), required=False),     # default constants.RS_RULE
    }), required=False),
})

_PAYLOAD = Record({
    'kind': field(Str()),
    'source': field(Str(), required=False),  # 'file' (default) | 'inline'
    'path': field(Str(), required=False),    # sidecar filename, required when source: file
})

_RAW_BLOCK = Record({
    'group': field(Str()),
    'params': field(RawParams(), required=False),
    'payload': field(_PAYLOAD, required=False),
})

# One &CNTL pass: its own title (each &CNTL has its
# own TITLE), its own ctrl (NRNFG/step params are inherently per-pass), and
# optionally its own raw blocks -- the same shapes top-level title/ctrl/raw
# already have for the single-implicit-pass case, just repeated per pass.
_PASS = Record({
    'title': field(Str()),
    'ctrl': field(_CTRL),
    'raw': field(ListOfRecord(_RAW_BLOCK), required=False),
})

ROOT = Record({
    'title': field(Str()),
    'deck': field(Str()),
    # Unused when every group that would consume a generated CSF list is
    # itself raw with an inline payload instead (raw wins; boron.inp's &WF
    # payload IS its CSF list, there is no separate generated file).
    'csf': field(Str(), required=False),
    'atom': field(Record({
        'z': field(Int()),
        'ang': field(Str()),
        'spin': field(Int()),
    })),
    'files': field(Record({
        'cfptable': field(Str()),
        # 'basis'/'format' are unused for the same reason as top-level
        # 'csf': a raw &AI block with an inline basis payload has no
        # separate basis file to open or describe the format of.
        'basis': field(Str(), required=False),
        'format': field(Str(), required=False),
        'mcp': field(Str(), required=False),
        'open': field(ListOfRecord(_OPEN_LINE), required=False),
    })),
    'orbital': field(Record({
        'frozen_core': field(Shells(), required=False),
        'active': field(Shells(), required=False),
        'outer': field(Shells(), required=False),
    })),
    'reference': field(ListOfRecord(Record({
        'scf': field(Bool(), required=False),
        'occ': field(Str()),
    }))),
    # Optional when 'passes' is given (each pass has its own ctrl).
    'ctrl': field(_CTRL, required=False),
    # Raw NAMELIST blocks: explicit group/params/payload,
    # bypassing sugar derivation entirely. Merged into the sugar-built deck
    # by raw.py, replacing any sugar block of the same group name.
    'raw': field(ListOfRecord(_RAW_BLOCK), required=False),
    # Multi-pass restart decks: absent/empty -> a
    # single implicit pass, exactly top-level title/ctrl/raw (unchanged
    # behavior, strictly additive). When
    # present, top-level ctrl/raw are unused; each pass states its own.
    'passes': field(ListOfRecord(_PASS), required=False),
})


# --- validation ------------------------------------------------------------

def validate(root_node, filename):
    """Parse-tree -> typed dict, per ROOT. Raises SchemaError."""
    return _coerce(root_node, ROOT, '$', filename)


def pass_entries(data):
    """validate()'s output -> the list of per-pass {title, ctrl, raw} to
    build: `data['passes']` itself if present and
    non-empty, else a single implicit pass wrapping top-level
    title/ctrl/raw -- exactly the pre-Phase-7 single-pass behavior. This is
    the one place that fallback is expressed; sugar.py, raw.py, and lint.py
    all call this rather than each writing (and risking drifting from)
    their own `data.get('passes') or [...]`."""
    return data.get('passes') or [{
        'title': data['title'], 'ctrl': data.get('ctrl', {}), 'raw': data.get('raw', []),
    }]


def _line_of(node, fallback):
    if isinstance(node, RawValue):
        return node.line
    if isinstance(node, (Mapping, NodeList)) and node.line is not None:
        return node.line
    return fallback


def _did_you_mean(key, candidates):
    matches = difflib.get_close_matches(key, list(candidates), n=1, cutoff=0.6)
    return matches[0] if matches else None


def _coerce(node, type_, path, filename):
    if isinstance(type_, Record):
        return _coerce_record(node, type_, path, filename)
    if isinstance(type_, ListOfRecord):
        return _coerce_list_of_record(node, type_, path, filename)
    if isinstance(type_, Shells):
        return _coerce_shells(node, path, filename)
    if isinstance(type_, RawParams):
        return _coerce_raw_params(node, path, filename)
    if isinstance(type_, (Ints, Floats)):
        return _coerce_numbers(node, int if isinstance(type_, Ints) else float,
                               path, filename)
    # Str / Int / Float / Bool all read a single RawValue.
    if not isinstance(node, RawValue):
        raise SchemaError(f"{path} expects a scalar value", filename,
                           _line_of(node, 0))
    raw = node.scalar()
    if isinstance(type_, Str):
        return raw
    if isinstance(type_, Int):
        try:
            return int(raw)
        except ValueError:
            raise SchemaError(f"{path} expects an integer (cannot parse '{raw}')",
                               filename, node.line)
    if isinstance(type_, Float):
        try:
            return float(raw)
        except ValueError:
            raise SchemaError(f"{path} expects a number (cannot parse '{raw}')",
                               filename, node.line)
    if isinstance(type_, Bool):
        low = raw.strip().lower()
        if low in ('true', '1', 'yes'):
            return True
        if low in ('false', '0', 'no'):
            return False
        raise SchemaError(f"{path} expects true/false (cannot parse '{raw}')",
                           filename, node.line)
    raise AssertionError(f"unhandled schema type {type_!r}")


def _fields_of(node, path, filename):
    """A record's raw fields, whichever form (nested block or inline) it
    was written in — the §4.4 disambiguation point."""
    if isinstance(node, Mapping):
        return dict(node), node.line
    if isinstance(node, RawValue):
        return node.record(), node.line
    raise SchemaError(f"{path} expects a mapping", filename, _line_of(node, 0))


def _coerce_record(node, type_, path, filename):
    raw_fields, line = _fields_of(node, path, filename)
    for key, value_node in raw_fields.items():
        if key not in type_.fields:
            suggestion = _did_you_mean(key, type_.fields.keys())
            msg = f"unknown key '{key}' in {path}"
            if suggestion:
                msg += f" (did you mean '{suggestion}'?)"
            raise SchemaError(msg, filename, _line_of(value_node, line))
    result = {}
    for name, spec in type_.fields.items():
        if name in raw_fields:
            result[name] = _coerce(raw_fields[name], spec.type, f"{path}.{name}", filename)
        elif spec.required:
            raise SchemaError(f"missing required key '{name}' in {path}", filename, line)
    return result


def _coerce_list_of_record(node, type_, path, filename):
    if isinstance(node, RawValue) and node.scalar() == '':
        return []
    if not isinstance(node, NodeList):
        raise SchemaError(f"{path} expects a list", filename, _line_of(node, 0))
    return [_coerce_record(item, type_.item, f"{path}[{i}]", filename)
            for i, item in enumerate(node)]


def _coerce_raw_params(node, path, filename):
    if not isinstance(node, Mapping):
        raise SchemaError(
            f"{path} expects a nested block (one 'key: value' line per "
            f"param), not an inline record", filename, _line_of(node, 0))
    result = {}
    for key, value_node in node.items():
        if not isinstance(value_node, RawValue):
            raise SchemaError(f"{path}.{key} expects a scalar value",
                               filename, _line_of(value_node, node.line))
        text = value_node.text.strip()
        if text.startswith('"'):
            result[key] = QuotedStr(value_node.scalar())
            continue
        tokens = [t.strip() for t in _split_top_level(text, ',')]
        is_quoted = [len(t) >= 2 and t[0] == "'" and t[-1] == "'" for t in tokens]
        if tokens and all(is_quoted):
            dequoted = [t[1:-1] for t in tokens]
            result[key] = QuotedStr(dequoted[0]) if len(tokens) == 1 else StringArray(dequoted)
        else:
            result[key] = IntList(tokens, wrap=None) if len(tokens) > 1 else tokens[0]
    return result


def _coerce_numbers(node, convert, path, filename):
    if not isinstance(node, RawValue):
        raise SchemaError(f"{path} expects a list of numbers", filename, _line_of(node, 0))
    tokens = node.scalar().replace(',', ' ').split()
    if not tokens:
        raise SchemaError(f"{path} expects at least one number", filename, node.line)
    try:
        return [convert(t) for t in tokens]
    except ValueError:
        kind = 'integers' if convert is int else 'numbers'
        raise SchemaError(f"{path} expects {kind} (cannot parse '{node.scalar()}')",
                           filename, node.line)


def _coerce_shells(node, path, filename):
    if not isinstance(node, RawValue):
        raise SchemaError(f"{path} expects a shell list", filename, _line_of(node, 0))
    text = node.scalar()
    if text == '':
        return []
    shells = []
    for token in text.split(','):
        token = token.strip()
        m = _SHELL_RE.match(token)
        if not m:
            raise SchemaError(
                f"{path} expects shells like '11S' (cannot parse '{token}')",
                filename, node.line)
        n, letter = int(m.group(1)), m.group(2).upper()
        if letter not in ANGULAR_MOMENTUM_LETTERS:
            raise SchemaError(f"{path} has unknown angular-momentum letter '{letter}'",
                               filename, node.line)
        shells.append({
            'label': f'{n}{letter}',
            'n': n,
            'l': ANGULAR_MOMENTUM_LETTERS.index(letter),
        })
    return shells
