"""--style jar|native equivalence.

`native` differs from the default `jar` style only presentationally:
uppercase group/parameter names and a Fortran D-exponent literal for `&AI
Z` instead of a plain integer.
`reference/` has nothing to byte-compare `native` output against -- the
only native decks in the repo are hand-written, multi-pass, and
structurally different artifacts (samples/native/*.stdin). So the
claim is verified by property instead:

    normalize(emit(ir, style='jar')) == normalize(emit(ir, style='native'))

where `normalize` case-folds the whole text and canonicalizes every
numeric literal to a plain float via `repr(float(...))` -- both styles
render the exact same *value* for every field, just spelled differently
(`z=9,` vs `Z=9.0D0`, `nrnfg=` vs `NRNFG=`). This intentionally reuses
`test_property_sweep.deck()`'s shell-configuration generator so the
property holds across a swept range of orbital/reference shapes, not just
`f.inp`/`fpt.inp`.
"""

import os
import re
import subprocess

import pytest
from hypothesis import HealthCheck, given, settings

from ..emit import emit
from ..sugar import build
from .test_property_sweep import deck as _shell_deck

_NUM_RE = re.compile(r'-?\d+\.?\d*(?:[de][+-]?\d+)?')


def _normalize(text):
    text = text.lower()
    return _NUM_RE.sub(lambda m: repr(float(m.group(0).replace('d', 'e'))), text)


def _full_data(shell_data):
    """Wrap test_property_sweep.deck()'s {csf, orbital, reference} draw
    (already the validated-dict shape for those three keys) with the rest
    of a minimal valid data dict, ctrl covering every &-group so the style
    property is exercised for all of them, not just &MC/&WF."""
    return {
        **shell_data,
        'title': 'STYLE SWEEP',
        'atom': {'z': 9, 'ang': 'P', 'spin': 2},
        'files': {'cfptable': './CFPTBL', 'basis': 'f.bas', 'format': 'atomci'},
        'ctrl': {
            'ai': {'type': 2, 'idprnt': 0},
            'mc': {'itmax': 20},
            'wf': {'rule': 2, 'npflg': 0},
            'tr': {'ind': [{'record': 1, 'l': 0, 'first': 1, 'last': 13}]},
            'pt': {'cthr': 0.01, 'ethr': 0.001, 'how': 0, 'nstate': 1},
            'ex': {'retry': False},
            'ci': {'ips': 7, 'maxit': 100, 'nsdim': 100, 'nstate': 1},
            'rs': {'print': -0.001, 'nrnfg': 1},
        },
    }


@settings(suppress_health_check=[HealthCheck.function_scoped_fixture])
@given(shell_data=_shell_deck())
def test_native_style_differs_only_presentationally(shell_data, samples_dir):
    data = _full_data(shell_data)
    deck = build(data, basis_dir=str(samples_dir))
    jar_text = emit(deck, style='jar')
    native_text = emit(deck, style='native')
    assert jar_text != native_text  # the styles must actually differ...
    assert _normalize(jar_text) == _normalize(native_text)  # ...only in spelling


def test_z_is_native_d0_literal_and_jar_plain_integer(samples_dir):
    data = _full_data({
        'csf': 'x.csf',
        'orbital': {'frozen_core': [{'label': '1S', 'n': 1, 'l': 0}],
                    'active': [{'label': '2S', 'n': 2, 'l': 0}],
                    'outer': [{'label': '11S', 'n': 11, 'l': 0}]},
        'reference': [{'occ': '2S*2'}],
    })
    deck = build(data, basis_dir=str(samples_dir))
    assert 'z=9,' in emit(deck, style='jar')
    assert 'Z=9.0D0,' in emit(deck, style='native')


ATOMCI_HOME = os.environ.get('ATOMCI_HOME')
ATOMCI = os.path.join(ATOMCI_HOME, 'bin', 'atomci') if ATOMCI_HOME else None
HAVE_ATOMCI = bool(ATOMCI and os.path.isfile(ATOMCI))


@pytest.mark.skipif(not HAVE_ATOMCI, reason='installed atomci binary not available (set ATOMCI_HOME)')
@pytest.mark.parametrize('name,golden', [('f', '-99.641223'), ('fpt', '-99.640355')])
def test_native_style_reaches_golden_energy(name, golden, atinputs_dir, samples_dir, tmp_path):
    """--style native must produce a deck real atomci can actually run --
    the property test above only proves presentational equivalence to the
    (already golden-verified) jar style; this confirms the native-styled
    text is still valid NAMELIST input end-to-end. fpt depends on f.NO from
    an f run in the same directory, so run both here, f first."""
    from ..parser import parse_file
    from ..schema import validate

    for basis in ('f.bas',):
        (tmp_path / basis).write_bytes((samples_dir / basis).read_bytes())
    cfptbl = os.path.join(ATOMCI_HOME, 'CFPTBL')
    (tmp_path / 'CFPTBL').symlink_to(cfptbl)

    result = None
    for n in (['f'] if name == 'fpt' else []) + [name]:
        inp_path = str(atinputs_dir / f'{n}.inp')
        data = validate(parse_file(inp_path), inp_path)
        deck = build(data, basis_dir=str(samples_dir))
        (tmp_path / data['deck']).write_text(emit(deck, style='native'))
        csf_ref = atinputs_dir / 'reference' / f'{n}.csf'
        (tmp_path / data['csf']).write_bytes(csf_ref.read_bytes())
        with (tmp_path / data['deck']).open() as deck_file:
            result = subprocess.run([ATOMCI], stdin=deck_file, cwd=str(tmp_path),
                                     capture_output=True, text=True)
        assert result.returncode == 0, result.stdout[-2000:]

    assert golden in result.stdout
