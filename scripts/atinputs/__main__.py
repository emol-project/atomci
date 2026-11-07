"""python3 -m atinputs f.inp

Pipeline: parse -> validate (schema) -> lint -> obtain CSF -> sugar -> emit
-> write deck. Lint always runs; an error-level finding blocks deck
generation (not just under --lint-only). Warnings/info are printed but do
not block.
"""

import argparse
import json
import os
import sys

from .atg import write_atg
from .basis import BasisError
from .csf import CsfSourceError, obtain_csf
from .emit import emit
from .ir import to_jsonable
from .lint import lint
from .parser import ParseError, parse_file
from . import raw
from .raw import RawError
from .schema import SchemaError, validate
from .sugar import SugarError, build


def _resolve_basis_dir(inp_path, basis_filename):
    """The .inp's files.basis is a bare filename (it's just echoed into the
    deck's OPEN line, to be resolved at atomci-runtime relative to the work
    directory). To compute NSYM/NBF/MPOB at generation time we still need to
    read the real file, so search: cwd (matches the golden-run workflow,
    where basis is copied alongside the deck), then the .inp's own
    directory (every sample directory holds its own basis files)."""
    inp_dir = os.path.dirname(os.path.abspath(inp_path)) or '.'
    for candidate in ('.', inp_dir):
        if os.path.isfile(os.path.join(candidate, basis_filename)):
            return candidate
    return '.'


def main(argv=None):
    ap = argparse.ArgumentParser(prog='atinputs')
    ap.add_argument('inp', help='.inp file to process')
    ap.add_argument('--dump-ir', action='store_true',
                     help='print the IR as JSON and exit (no deck written)')
    ap.add_argument('--dump-atg', action='store_true',
                     help='print the .atg text and exit (no deck/csf written)')
    ap.add_argument('--lint-only', action='store_true',
                     help='run lint checks and exit (no deck written)')
    ap.add_argument('--csf-source', choices=('file', 'atgen', 'python'), default='python',
                     help="where the CSF list comes from (default: python, the "
                          "native-atgen port)")
    ap.add_argument('--style', choices=('jar', 'native'), default='jar',
                     help="deck formatting style (default: jar -- lowercase "
                          "group/param names, Z as a plain integer, matching "
                          "samples/atinputs/reference/; native uses uppercase "
                          "and Z=9.0D0 like samples/native/*.stdin)")
    args = ap.parse_args(argv)

    try:
        node = parse_file(args.inp)
        data = validate(node, args.inp)
    except (ParseError, SchemaError) as e:
        print(str(e), file=sys.stderr)
        return 1

    if args.dump_atg:
        print(write_atg(data), end='')
        return 0

    basis_dir = '.'
    if 'basis' in data['files']:
        basis_dir = _resolve_basis_dir(args.inp, data['files']['basis'])

    try:
        findings = lint(data, basis_dir=basis_dir, inp_path=args.inp)
    except (SugarError, BasisError, RawError, OSError) as e:
        print(f"{args.inp}: {e}", file=sys.stderr)
        return 1

    has_error = False
    for f in findings:
        print(f"{f.severity}: {f.message}", file=sys.stderr)
        if f.severity == 'error':
            has_error = True

    if args.lint_only:
        return 1 if has_error else 0
    if has_error:
        print(f"{args.inp}: not generating a deck (lint errors above)", file=sys.stderr)
        return 1

    try:
        deck = build(data, basis_dir=basis_dir)
        raw.merge_into_deck(deck, data, args.inp)
    except (SugarError, BasisError, RawError, OSError) as e:
        print(f"{args.inp}: {e}", file=sys.stderr)
        return 1

    if args.dump_ir:
        print(json.dumps(to_jsonable(deck), indent=2))
        return 0

    if 'csf' in data:
        try:
            obtain_csf(data, args.csf_source, work_dir='.')
        except CsfSourceError as e:
            print(f"{args.inp}: {e}", file=sys.stderr)
            return 1

    with open(data['deck'], 'w', encoding='utf-8') as f:
        f.write(emit(deck, style=args.style))
    return 0


if __name__ == '__main__':
    sys.exit(main())
