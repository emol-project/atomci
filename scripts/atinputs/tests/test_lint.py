from ..lint import lint
from ..parser import parse
from ..schema import validate

MINIMAL = """
title: x
deck: x.deck
csf: x.csf
atom:
  z: 9
  ang: P
  spin: 2
files:
  cfptable: ./CFPTBL
  basis: f.bas
  format: atomci
orbital:
  frozen_core: 1S
  active: 2S, 2P
  outer: 11S, 10P, 6D, 5F
reference:
  - occ: 2S*2 2P*5
ctrl:
"""


def _lint(text, samples_dir):
    data = validate(parse(text, 'x.inp'), 'x.inp')
    return lint(data, basis_dir=str(samples_dir))


def _severities(findings):
    return {f.severity for f in findings}


def test_clean_f_like_input_has_no_errors(samples_dir):
    text = MINIMAL + (
        '  ai: type: 2, idprnt: 0\n'
        '  tr:\n'
        '    ind:\n'
        '      - record: 1, l: 0, first: 1, last: 13\n'
        '  rs:\n'
        '    print: -0.001\n'
    )
    findings = _lint(text, samples_dir)
    assert 'error' not in _severities(findings)


def test_tr_input_unit_is_error(samples_dir):
    text = MINIMAL + (
        '  tr:\n'
        '    input_unit: 27\n'
        '    ind:\n'
        '      - record: 1, l: 0, first: 1, last: 13\n'
    )
    findings = _lint(text, samples_dir)
    messages = [f.message for f in findings if f.severity == 'error']
    assert any('SIGFPE' in m for m in messages)


def test_tr_with_empty_ind_is_error(samples_dir):
    text = MINIMAL + '  tr:\n    ind:\n'
    findings = _lint(text, samples_dir)
    messages = [f.message for f in findings if f.severity == 'error']
    assert any('neither ind nor from_record' in m for m in messages)


def test_missing_rs_is_warning(samples_dir):
    text = MINIMAL
    findings = _lint(text, samples_dir)
    assert any(f.severity == 'warning' and 'SD-CI ENERGY' in f.message for f in findings)


def test_nrnfg_matching_rule_preset_is_clean(samples_dir):
    # RULE=1 with ai,mc,wf,tr,ci,rs present, pt/ex absent -> matches the
    # standard preset for RULE=1 exactly (docs/namelist.002).
    text = MINIMAL + (
        '  ai: type: 2, idprnt: 0\n'
        '  mc:\n    itmax: 20\n'
        '  wf: rule: 1, npflg: 0\n'
        '  tr:\n    ind:\n      - record: 1, l: 0, first: 1, last: 13\n'
        '  ci: ips: 7, maxit: 100, nsdim: 100, nstate: 1\n'
        '  rs: print: -0.001\n'
    )
    findings = _lint(text, samples_dir)
    assert not any('NRNFG' in f.message for f in findings)


def test_nrnfg_mismatching_rule_preset_is_warning(samples_dir):
    # RULE=2 preset wants PT and EX both present (NRNFG(5)=NRNFG(6)=1), but
    # neither ctrl.pt nor ctrl.ex is here -- a genuine RULE/PT/EX mismatch.
    text = MINIMAL + (
        '  wf: rule: 2, npflg: 0\n'
        '  tr:\n    ind:\n      - record: 1, l: 0, first: 1, last: 13\n'
    )
    findings = _lint(text, samples_dir)
    assert any(f.severity == 'warning' and 'NRNFG' in f.message for f in findings)


def test_nrnfg_mc_deviation_from_rule_preset_is_not_a_warning(samples_dir):
    # Only PT and EX vary across NRNFG_PRESET_BY_RULE's presets (constants.py)
    # -- MC is an independent, legitimate user choice (e.g. reusing another
    # job's natural orbitals via *.NO instead of running MCSCF) and must not
    # be compared against the RULE preset. This mirrors samples/atinputs/
    # fpt.inp exactly: RULE=2 with pt/ex present but mc absent.
    text = MINIMAL + (
        '  wf: rule: 2, npflg: 0\n'
        '  tr:\n    ind:\n      - record: 1, l: 0, first: 1, last: 13\n'
        '  pt:  cthr: 0.01, ethr: 0.001, how: 0, nstate: 1\n'
        '  ex:  retry: false\n'
    )
    findings = _lint(text, samples_dir)
    assert not any('NRNFG' in f.message for f in findings)


def test_atom_z_vs_itnel_is_info(samples_dir):
    # F+ ion: z=9 but only 8 electrons declared -> info, not error/warning
    text = MINIMAL.replace('occ: 2S*2 2P*5', 'occ: 2S*2 2P*4')
    findings = _lint(text, samples_dir)
    info = [f for f in findings if f.severity == 'info']
    assert any('atom.z' in f.message for f in info)
    assert not any(f.severity == 'error' for f in findings)


# --- §4: CSF-generation lint additions ------------------------------------

def test_reference_shell_not_in_active_is_error(samples_dir):
    text = MINIMAL.replace('occ: 2S*2 2P*5', 'occ: 2S*2 3S*5')
    findings = _lint(text, samples_dir)
    messages = [f.message for f in findings if f.severity == 'error']
    assert any("'3S*5'" in m and 'not declared' in m for m in messages)


def test_reference_occupation_exceeds_capacity_is_error(samples_dir):
    text = MINIMAL.replace('occ: 2S*2 2P*5', 'occ: 2S*2 2P*7')  # P capacity is 6
    findings = _lint(text, samples_dir)
    messages = [f.message for f in findings if f.severity == 'error']
    assert any("'2P*7'" in m and 'exceeds shell capacity' in m for m in messages)


def test_outer_count_that_reads_as_a_shell_label_is_not_an_error(samples_dir):
    # outer: 2S / 1S are counts of correlating s orbitals (CARD 1), not the
    # shells 2s / 1s of orbital.active / orbital.frozen_core.
    for outer in ('2S, 10P, 6D, 5F', '1S, 10P, 6D, 5F'):
        text = MINIMAL.replace('outer: 11S, 10P, 6D, 5F', f'outer: {outer}')
        findings = _lint(text, samples_dir)
        assert not any('orbital.outer' in f.message for f in findings), outer


def test_outer_two_counts_for_one_l_is_error(samples_dir):
    text = MINIMAL.replace('outer: 11S, 10P, 6D, 5F', 'outer: 11S, 10P, 6D, 3D')
    findings = _lint(text, samples_dir)
    messages = [f.message for f in findings if f.severity == 'error']
    assert any('more than one count for l=D' in m for m in messages)


def test_itnel_counts_p_core_shells_as_six(samples_dir):
    # Sc 3d4s2: core 1s2 2s2 2p6 3s2 3p6 = 18 electrons, + 3 = 21 = z
    text = (MINIMAL.replace('z: 9', 'z: 21').replace('ang: P', 'ang: D')
            .replace('frozen_core: 1S', 'frozen_core: 1S, 2S, 2P, 3S, 3P')
            .replace('active: 2S, 2P', 'active: 4S, 3D')
            .replace('outer: 11S, 10P, 6D, 5F', 'outer: 3S, 4P, 3D, 2F, 1G')
            .replace('occ: 2S*2 2P*5', 'occ: 4S*2 3D*1'))
    findings = _lint(text, samples_dir)
    assert not any('atom.z' in f.message for f in findings)
    # (f.bas has no g functions, so 1G is rightly flagged; only the outer
    # counts read as shell labels must not be.)
    assert not any('more than one count' in f.message for f in findings)


def test_reference_parity_inconsistency_is_error(samples_dir):
    # 2S*2 2P*5 (sum l = 5, odd) vs 2S*1 2P*6 (sum l = 6, even) -- genuinely
    # different parity classes, which csfgen would silently conflate.
    text = MINIMAL.replace(
        'reference:\n  - occ: 2S*2 2P*5\n',
        'reference:\n  - occ: 2S*2 2P*5\n  - occ: 2S*1 2P*6\n')
    findings = _lint(text, samples_dir)
    messages = [f.message for f in findings if f.severity == 'error']
    assert any('inconsistent parity' in m for m in messages)


def test_csf_count_exceeding_mconf_is_error(samples_dir, monkeypatch):
    from .. import lint as lint_module
    monkeypatch.setattr(lint_module, '_MCORE', 10)  # force a tiny fixed-dimension limit
    findings = _lint(MINIMAL, samples_dir)
    messages = [f.message for f in findings if f.severity == 'error']
    assert any('fixed-dimension limit' in m for m in messages)


def test_wide_reference_exceeding_csfs_72_columns_is_error(samples_dir):
    # &MC's CSFS is CHARACTER*72 with no continuation across array elements
    # (src/mcmcsf.f) -- a reference this wide renders to 73 columns,
    # which MCMCSF can't represent at all.
    text = MINIMAL.replace(
        'orbital:\n  frozen_core: 1S\n  active: 2S, 2P\n'
        '  outer: 11S, 10P, 6D, 5F\n',
        'orbital:\n  frozen_core:\n'
        '  active: 1S,1P,2P,1D,2D,3D,4D,1F,2F,1G,1H\n'
        '  outer: 11S,10P,6D,5F,3G,3H\n',
    ).replace(
        'reference:\n  - occ: 2S*2 2P*5\n',
        'reference:\n  - occ: 1S*2 1P*6 2P*6 1D*10 2D*10 3D*10 4D*10 1F*14 2F*14 1G*2 1H*2\n',
    ) + '  mc:\n    itmax: 20\n'
    findings = _lint(text, samples_dir)
    messages = [f.message for f in findings if f.severity == 'error']
    assert any('73-character CSFS line' in m and 'CHARACTER*72' in m for m in messages)


def test_wide_reference_without_mc_is_not_flagged(samples_dir):
    # Same over-width reference, but no 'mc' ctrl step -- CSFS is never
    # emitted, so this must NOT be flagged (gated on
    # 'mc' in ctrl to avoid a false positive on WF/TR-only decks).
    text = MINIMAL.replace(
        'orbital:\n  frozen_core: 1S\n  active: 2S, 2P\n'
        '  outer: 11S, 10P, 6D, 5F\n',
        'orbital:\n  frozen_core:\n'
        '  active: 1S,1P,2P,1D,2D,3D,4D,1F,2F,1G,1H\n'
        '  outer: 11S,10P,6D,5F,3G,3H\n',
    ).replace(
        'reference:\n  - occ: 2S*2 2P*5\n',
        'reference:\n  - occ: 1S*2 1P*6 2P*6 1D*10 2D*10 3D*10 4D*10 1F*14 2F*14 1G*2 1H*2\n',
    )
    findings = _lint(text, samples_dir)
    messages = [f.message for f in findings]
    assert not any('CSFS line' in m for m in messages)
