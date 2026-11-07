from ..lint import lint
from ..parser import parse
from ..schema import validate
from .test_raw import _MINIMAL_RAW


def _validate(text):
    return validate(parse(text, 'x.inp'), 'x.inp')


def _tr_basvc_raw(basvc_path, itvci=0, extra_basvc_group='BASVC'):
    return _MINIMAL_RAW + (
        '  -\n'
        '    group: TR\n'
        '    params:\n'
        '      nsym: 2\n'
        '      nbf: 2,2\n'
        '      nob: 2,2\n'
        f'      itvci: {itvci}\n'
        '  -\n'
        f'    group: {extra_basvc_group}\n'
        '    params:\n'
        '      idprnt: 0\n'
        '      iunit: 5\n'
        '    payload:\n'
        '      kind: vectors\n'
        f'      path: {basvc_path}\n'
    )


def _errors(findings):
    return [f.message for f in findings if f.severity == 'error']


def test_iunit5_without_payload_is_error():
    # _MINIMAL_RAW's &AI block already sets iunit: 5 with no payload.
    data = _validate(_MINIMAL_RAW)
    findings = lint(data, inp_path='x.inp')
    assert any('sets IUNIT=5 but has no payload' in m for m in _errors(findings))


def test_payload_without_iunit5_is_error(tmp_path):
    sidecar = tmp_path / 'v.txt'
    sidecar.write_text('1.0 )\n')
    text = _MINIMAL_RAW + (
        '  -\n'
        '    group: BASVC\n'
        '    params:\n'
        '      idprnt: 0\n'
        '    payload:\n'
        '      kind: vectors\n'
        '      path: v.txt\n'
    )
    data = _validate(text)
    findings = lint(data, inp_path=str(tmp_path / 'x.inp'))
    assert any('do not set IUNIT=5' in m for m in _errors(findings))


def test_itvci_0_requires_basvc():
    text = _MINIMAL_RAW + (
        '  -\n'
        '    group: TR\n'
        '    params:\n'
        '      nsym: 2\n'
        '      nbf: 2,2\n'
        '      nob: 2,2\n'
        '      itvci: 0\n'
    )
    data = _validate(text)
    findings = lint(data, inp_path='x.inp')
    assert any('ITVCI=0 requires a &BASVC block' in m for m in _errors(findings))


def test_itvci_1_requires_get():
    text = _MINIMAL_RAW + (
        '  -\n'
        '    group: TR\n'
        '    params:\n'
        '      nsym: 2\n'
        '      nbf: 2,2\n'
        '      nob: 2,2\n'
        '      itvci: 1\n'
    )
    data = _validate(text)
    findings = lint(data, inp_path='x.inp')
    assert any('ITVCI=1 requires a &GET block' in m for m in _errors(findings))


def test_basvc_coefficient_count_matches_is_clean(tmp_path):
    # _MINIMAL_RAW's &AI block sets iunit: 5 with no payload of its own
    # (exercised separately by test_iunit5_without_payload_is_error) -- this
    # test only cares that a *correct* &BASVC payload raises neither the
    # coefficient-count nor the parenthesis-balance finding.
    sidecar = tmp_path / 'v.txt'
    sidecar.write_text(' 1.0 2.0 3.0 4.0 )\n 5.0 6.0 7.0 8.0 )\n')
    data = _validate(_tr_basvc_raw('v.txt'))
    findings = lint(data, inp_path=str(tmp_path / 'x.inp'))
    basvc_errors = [m for m in _errors(findings) if '&BASVC' in m]
    assert basvc_errors == []


def test_basvc_coefficient_count_mismatch_is_error(tmp_path):
    sidecar = tmp_path / 'v.txt'
    sidecar.write_text(' 1.0 2.0 3.0 )\n 5.0 6.0 7.0 8.0 )\n')  # one token short
    data = _validate(_tr_basvc_raw('v.txt'))
    findings = lint(data, inp_path=str(tmp_path / 'x.inp'))
    assert any('numeric tokens, expected 8' in m for m in _errors(findings))


def test_basvc_missing_symmetry_terminator_is_error(tmp_path):
    sidecar = tmp_path / 'v.txt'
    # both symmetry blocks' data run together under one terminator instead
    # of one each -- CARDVC would misassign the second block's data.
    sidecar.write_text(' 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 )\n')
    data = _validate(_tr_basvc_raw('v.txt'))
    findings = lint(data, inp_path=str(tmp_path / 'x.inp'))
    assert any('per-symmetry closing' in m for m in _errors(findings))


def test_basis_payload_without_closing_paren_is_error(tmp_path):
    (tmp_path / 'b.txt').write_text('1S 15.3745\n2S 10.0\n')  # missing terminator
    text = _MINIMAL_RAW.replace(
        '  -\n    group: AI\n    params:\n      iunit: 5\n      nwt: 47\n      z: 5.0D0\n',
        '  -\n    group: AI\n    params:\n      iunit: 5\n      nwt: 47\n      z: 5.0D0\n'
        '    payload:\n      kind: basis\n      path: b.txt\n')
    data = _validate(text)
    findings = lint(data, inp_path=str(tmp_path / 'x.inp'))
    assert any("does not end with a closing ')' line" in m for m in _errors(findings))


def test_boron_inp_lints_clean(atinputs_dir):
    path = str(atinputs_dir / 'boron.inp')
    data = validate(parse(open(path).read(), path), path)
    findings = lint(data, inp_path=path)
    assert _errors(findings) == []


# --- &TR MPOB restatement -----------------

def test_raw_tr_without_mpob_is_error(tmp_path):
    # _tr_basvc_raw's &TR block has nsym/nbf/nob/itvci but no mpob --
    # TRDRIV silently substitutes identity ordering when this is omitted.
    sidecar = tmp_path / 'v.txt'
    sidecar.write_text(' 1.0 2.0 3.0 4.0 )\n 5.0 6.0 7.0 8.0 )\n')
    data = _validate(_tr_basvc_raw('v.txt'))
    findings = lint(data, inp_path=str(tmp_path / 'x.inp'))
    assert any('&TR has no mpob' in m for m in _errors(findings))


def test_raw_tr_with_mpob_is_clean():
    text = _MINIMAL_RAW + (
        '  -\n'
        '    group: TR\n'
        '    params:\n'
        '      nsym: 2\n'
        '      nbf: 2,2\n'
        '      nob: 2,2\n'
        '      mpob: 2,1,2,1\n'
        '      itvci: 1\n'
        '  -\n'
        '    group: GET\n'
        '    params:\n'
        '      ivcs: 27\n'
    )
    data = _validate(text)
    findings = lint(data, inp_path='x.inp')
    assert not any('&TR has no mpob' in m for m in _errors(findings))


# --- &TR NPFLG -----------------------------

def test_raw_tr_npflg_nonzero_is_error():
    text = _MINIMAL_RAW + (
        '  -\n'
        '    group: TR\n'
        '    params:\n'
        '      nsym: 2\n'
        '      nbf: 2,2\n'
        '      nob: 2,2\n'
        '      mpob: 2,1,2,1\n'
        '      npflg: 1\n'
        '      itvci: 1\n'
        '  -\n'
        '    group: GET\n'
        '    params:\n'
        '      ivcs: 27\n'
    )
    data = _validate(text)
    findings = lint(data, inp_path='x.inp')
    assert any('&TR sets NPFLG!=0' in m for m in _errors(findings))


def test_raw_tr_npflg_zero_is_clean():
    text = _MINIMAL_RAW + (
        '  -\n'
        '    group: TR\n'
        '    params:\n'
        '      nsym: 2\n'
        '      nbf: 2,2\n'
        '      nob: 2,2\n'
        '      mpob: 2,1,2,1\n'
        '      npflg: 0\n'
        '      itvci: 1\n'
        '  -\n'
        '    group: GET\n'
        '    params:\n'
        '      ivcs: 27\n'
    )
    data = _validate(text)
    findings = lint(data, inp_path='x.inp')
    assert not any('&TR sets NPFLG!=0' in m for m in _errors(findings))
