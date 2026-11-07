"""`.stdin` (hand-written native deck) -> `.inp` (+ payload sidecars). Built
after the raw block layer + payload mechanism, once there was somewhere for
the result to land.

Deliberately general, not tuned to any one sample: NAMELIST params are
parsed generically (comma-split tokens, a `KEY=...` token starts a new
key, anything else extends the current key's value list -- this is what
reconstructs a continuation-line array like &TR's MPOB with no TR-specific
code), and a payload is recognized purely from IUNIT=5 among a group's own
params, using the confirmed reader behavior: whatever follows a group up
to the next `&GROUP` card (or EOF) is either that group's payload (if
IUNIT=5) or dead text a subsequent NAMELIST READ would silently skip over
(if not) -- either way, it is exactly the span this module captures.

Not a general Fortran NAMELIST parser: no array-subscript syntax
(`FOO(2)=`), no `&END` terminator (only bare `/`), no repeat counts
(`3*0`). None of the four in-tree samples need them.
"""

import os
import re

_GROUP_START = re.compile(r'^[ \t]*&(\w+)', re.MULTILINE)
_OPEN_LINE = re.compile(
    r'^\s*OPEN\s+UNIT=(\d+)\s+FILE=(\S+)(?:\s+(.*))?$', re.IGNORECASE)
_KEY_TOKEN = re.compile(r'^([A-Za-z][A-Za-z0-9_]*)\s*=\s*(.*)$', re.DOTALL)

# Cosmetic only (the payload.kind label), not a control-flow
# dispatch -- reverse() would build the exact same Block/Payload shape for
# an unrecognized group name, just with kind: 'unknown'.
_KIND_BY_GROUP = {'AI': 'basis', 'WF': 'csf', 'BASVC': 'vectors'}


class ReverseError(Exception):
    pass


def _split_top_level(text, sep=','):
    """Comma-split, but not inside a Fortran '...' string literal."""
    parts = []
    start = 0
    in_quotes = False
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == "'":
            in_quotes = not in_quotes
        elif c == sep and not in_quotes:
            parts.append(text[start:i])
            start = i + 1
        i += 1
    parts.append(text[start:])
    return parts


def _find_terminator(text, start):
    """Index just after the first unquoted bare '/' at or after start."""
    in_quotes = False
    i, n = start, len(text)
    while i < n:
        c = text[i]
        if c == "'":
            in_quotes = not in_quotes
        elif c == '/' and not in_quotes:
            return i + 1
        i += 1
    raise ReverseError("unterminated NAMELIST group (no closing '/' found)")


def _parse_params(param_text):
    """'&GROUP <this part> /'s inside -> {key: [token, ...]}, insertion
    order preserved. A token matching KEY=... starts a new key; anything
    else (a bare value) extends the current key's value list -- this is
    what reconstructs a continuation-line array with no group-specific
    code."""
    params = {}
    order = []
    current = None
    for raw_tok in _split_top_level(param_text):
        tok = raw_tok.strip()
        if not tok:
            continue
        m = _KEY_TOKEN.match(tok)
        if m:
            current = m.group(1).lower()
            value = m.group(2).strip()
            params[current] = [] if value == '' else [value]
            order.append(current)
        else:
            if current is None:
                raise ReverseError(f"value '{tok}' with no preceding KEY=")
            params[current].append(tok)
    return params, order


def _payload_lines(text, start, end):
    lines = [ln.rstrip() for ln in text[start:end].splitlines()]
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()
    return lines


def _parse_open_header(text):
    """Leading 'OPEN UNIT=... FILE=...' / 'END' lines -> (cfptable, [open
    entries], index just past 'END'). The first OPEN (matching
    constants.CFPTBL_UNIT) is cfptable; the rest are files.open entries."""
    from . import constants
    opens = []
    pos = 0
    for line in text.splitlines(keepends=True):
        stripped = line.strip()
        if stripped == 'END':
            pos += len(line)
            break
        m = _OPEN_LINE.match(line)
        if m:
            unit, file_, rest = int(m.group(1)), m.group(2), (m.group(3) or '')
            fmt = 'binary' if 'BINARY' in rest.upper() else ''
            status_m = re.search(r'STATUS=(\S+)', rest, re.IGNORECASE)
            status = status_m.group(1).lower() if status_m else ''
            opens.append({'unit': unit, 'file': file_, 'format': fmt, 'status': status})
        pos += len(line)
    else:
        raise ReverseError("no 'END' line found terminating the OPEN header")

    cfptable = None
    files_open = []
    for entry in opens:
        if entry['unit'] == constants.CFPTBL_UNIT and cfptable is None:
            cfptable = entry['file']
        else:
            files_open.append(entry)
    return cfptable, files_open, pos


def parse_stdin(text):
    """.stdin text -> (cfptable, files_open, [pass]), pass = [block, ...],
    block = {'group', 'params': {key: [tokens]}, 'order': [key,...],
    'payload_lines': [str] | None}.

    A native multi-pass restart deck (f.stdin's 3-pass structure --
    sugar.py's build() docstring) repeats &CNTL; each repetition starts a
    new pass, grouping every block up to (not
    including) the next &CNTL into that pass -- mirroring exactly how
    src/ci.f's own GO TO-loop re-reads &CNTL and re-dispatches AIMAIN..
    RSMAIN each time."""
    cfptable, files_open, pos = _parse_open_header(text)

    blocks = []
    matches = list(_GROUP_START.finditer(text, pos))
    for i, m in enumerate(matches):
        group = m.group(1).upper()
        header_end = m.end()
        term = _find_terminator(text, header_end)
        param_text = text[header_end:term - 1]
        params, order = _parse_params(param_text)

        iunit = params.get('iunit')
        has_iunit5 = iunit is not None and iunit and iunit[0].strip() == '5'
        next_start = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        payload_lines = _payload_lines(text, term, next_start) if has_iunit5 else None

        blocks.append({'group': group, 'params': params, 'order': order,
                        'payload_lines': payload_lines})

    passes = []
    for b in blocks:
        if b['group'] == 'CNTL' or not passes:
            passes.append([])
        passes[-1].append(b)
    return cfptable, files_open, passes


def _inp_param_value(tokens):
    """[token,...] -> the .inp RawParams-syntax text for this param.
    Native Fortran '...'-quoted tokens (one, or several -- a NAMELIST
    array literal like CSFS='a','b') pass through completely unchanged:
    schema.py's RawParams recognizes an all-quoted token list on its own
    (-> QuotedStr / StringArray), so reverse.py doesn't need to re-quote
    anything it read straight off the .stdin. A bare numeric/literal
    token list is likewise just comma-joined as-is."""
    return ','.join(t.strip() for t in tokens)


def _title_from_blocks(blocks):
    """The bare title text (no quote marks) for the .inp's top-level
    'title:' field, which -- unlike a raw param -- uses the "..." .inp
    escaping convention (schema.Str's dequote only strips '\"', not
    Fortran \"'\"), so the native '...' quoting has to be stripped here."""
    for b in blocks:
        if b['group'] == 'CNTL' and 'title' in b['params']:
            tok = b['params']['title'][0].strip()
            if len(tok) >= 2 and tok[0] == "'" and tok[-1] == "'":
                return tok[1:-1]
            return tok
    return ''


def _emit_raw_block(b, indent, sidecar_stem, sidecars):
    """One raw block ('  -\\n    group: ...' etc, the
    bare-dash-then-nested-mapping list-item form -- parser.py's grammar
    doesn't support any other shape for a multi-field list item) at a
    given base indent (the column its own '-' sits at). Returns the
    block's text lines; sidecar payload content, if any, is added to
    `sidecars` keyed by the filename referenced in the 'path:' line."""
    pad = ' ' * indent
    lines = [f'{pad}-', f'{pad}  group: {b["group"]}']
    if b['order']:
        lines.append(f'{pad}  params:')
        for key in b['order']:
            lines.append(f'{pad}    {key}: {_inp_param_value(b["params"][key])}')
    if b['payload_lines'] is not None:
        kind = _KIND_BY_GROUP.get(b['group'], 'unknown')
        path = f"{sidecar_stem}.{kind}.txt"
        lines.append(f'{pad}  payload:')
        lines.append(f'{pad}    kind: {kind}')
        lines.append(f'{pad}    path: {path}')
        sidecars[path] = b['payload_lines']
    return lines


def to_inp_text(stem, cfptable, files_open, passes):
    """(parse_stdin's result) -> (.inp text, {sidecar_filename: [lines]}).

    One pass (the common case): a flat top-level `raw:` list. More than one
    (a multi-pass restart deck): `passes:`, one entry per &CNTL, each with
    its own `title` (read off that pass's own &CNTL) and its own `raw:`
    list -- `ctrl:` stays empty in every pass, same convention as the
    single-pass case (raw wins; there's nothing for sugar to derive from a
    mechanically reverse-converted deck). Sidecar filenames get a `.passN`
    segment when multi-pass, so two passes payload-ing the same group kind
    (untested by anything in-tree) can't collide."""
    lines = [
        f'# Mechanically converted by atinputs.reverse from {stem}.stdin',
        '# (semantic round-trip, not a byte-for-byte match with the original .stdin).',
        '',
        f'title:  "{_title_from_blocks(passes[0])}"',
        f'deck:   {stem}.deck',
        '',
        'atom:',
        '  z:     0',
        '  ang:   S',
        '  spin:  1',
        '',
        'files:',
    ]
    if cfptable:
        lines.append(f'  cfptable:  {cfptable}')
    if files_open:
        lines.append('  open:')
        for entry in files_open:
            parts = [f"unit: {entry['unit']}", f"file: {entry['file']}"]
            if entry['format']:
                parts.append(f"format: {entry['format']}")
            if entry['status']:
                parts.append(f"status: {entry['status']}")
            lines.append('    - ' + ', '.join(parts))
    lines += ['', 'orbital:', 'reference:', 'ctrl:', '']

    sidecars = {}
    if len(passes) == 1:
        lines.append('raw:')
        for b in passes[0]:
            lines.extend(_emit_raw_block(b, 2, stem, sidecars))
    else:
        lines.append('passes:')
        for i, pass_blocks in enumerate(passes):
            sidecar_stem = f'{stem}.pass{i + 1}'
            lines.append('  -')
            lines.append(f'    title: "{_title_from_blocks(pass_blocks)}"')
            lines.append('    ctrl:')
            lines.append('    raw:')
            for b in pass_blocks:
                lines.extend(_emit_raw_block(b, 6, sidecar_stem, sidecars))

    return '\n'.join(lines) + '\n', sidecars


def convert(stdin_path, out_dir):
    """.stdin -> (out_dir/<stem>.inp, out_dir/<sidecars>). Returns the
    .inp path. atom.z/ang/spin are placeholders (0/S/1) -- the reverse
    converter has no way to recover them from a fully-raw deck; they're
    unused when every block is raw, same as boron.inp."""
    stem = os.path.splitext(os.path.basename(stdin_path))[0]
    with open(stdin_path, encoding='utf-8') as f:
        text = f.read()
    cfptable, files_open, passes = parse_stdin(text)
    inp_text, sidecars = to_inp_text(stem, cfptable, files_open, passes)

    os.makedirs(out_dir, exist_ok=True)
    inp_path = os.path.join(out_dir, f'{stem}.inp')
    with open(inp_path, 'w', encoding='utf-8') as f:
        f.write(inp_text)
    for filename, sidecar_lines in sidecars.items():
        with open(os.path.join(out_dir, filename), 'w', encoding='utf-8') as f:
            f.write('\n'.join(sidecar_lines) + ('\n' if sidecar_lines else ''))
    return inp_path


def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser(prog='atinputs.reverse')
    ap.add_argument('stdin_file', help='a hand-written native .stdin deck')
    ap.add_argument('-o', '--out-dir', default='.',
                     help='directory to write the .inp + sidecars into (default: .)')
    args = ap.parse_args(argv)
    try:
        inp_path = convert(args.stdin_file, args.out_dir)
    except (ReverseError, OSError) as e:
        print(f"{args.stdin_file}: {e}")
        return 1
    print(inp_path)
    return 0


if __name__ == '__main__':
    import sys
    sys.exit(main())
