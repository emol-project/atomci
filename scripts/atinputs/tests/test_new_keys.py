"""The short-form keys added 2026-11-03: STF basis files, NOB < NBF from
orbital.outer, ctrl.tr.from_record, a top-level-ctrl-free passes: deck,
and the further NAMELIST parameters of each step."""

import os
import subprocess

import pytest
import verify_namelists

from ..basis import BasisError, read_basis
from ..csf import obtain_csf
from ..emit import emit
from ..ir import IntList
from ..lint import lint
from ..parser import parse_file
from ..schema import SchemaError, validate
from ..sugar import build

ATOMCI_HOME = os.environ.get('ATOMCI_HOME')
ATOMCI = os.path.join(ATOMCI_HOME, 'bin', 'atomci') if ATOMCI_HOME else None
HAVE_ATOMCI = bool(ATOMCI and os.path.isfile(ATOMCI))

PARAMS_INP = '''\
title:  " F DOUBLET P "
deck:   fparams.deck
csf:    fparams.csf
atom:
  z:     9
  ang:   P
  spin:  2
files:
  cfptable:  ./CFPTBL
  basis:     f.bas
orbital:
  frozen_core:  1S
  active:       2S, 2P
  outer:        11S, 10P, 6D, 5F
reference:
  - scf: true, occ: 2S*2 2P*5
ctrl:
  ai:  type: 2
  mc:
    itmax:  30
    ethr:   1.0e-8
    c2thr:  1.0e-6
    nsol:   1
    nset:   2
    nopt:   1 1 1
    ind:
      - record: 1, l: 0, first: 1, last: 13
      - record: 1, l: 1, first: 1, last: 11
      - record: 1, l: 2, first: 1, last: 6
      - record: 1, l: 3, first: 1, last: 5
  wf:  rule: 2, ismax: 21, irmax: 31
  tr:
    from_record: 1
    nbase: 0
  pt:  istate: 1, ips: 6, pthr: 1.0, nrnfg: 1 1 1
  ex:  nfexw: 14, nfexe: 15
  ci:
    ips:    7
    ioflg:  0 0 0 0 0 0
    inflg:  0 0 0 0 0 0
    nfiv:   37
    thrcsf: 0.001
    xref:   -99.6
  rs:  print: -0.001, rule: 1, nrnfg: 1
'''


def _load(path):
    return validate(parse_file(str(path)), str(path))


def _blocks(deck, npass=0):
    return {b.group: b for b in deck.passes[npass].blocks}


def _params_data(tmp_path, text=PARAMS_INP):
    p = tmp_path / 'fparams.inp'
    p.write_text(text)
    return _load(p)


# --- STF basis ----------------------------------------------------------

def test_stf_basis_counts(atinputs_dir):
    basis = read_basis(str(atinputs_dir / 'boron.basis.txt'), ntype=1)
    assert basis.nbf == [10, 9, 8, 8, 6, 4, 2]
    assert basis.nob == basis.nbf


def test_stf_basis_bad_token(tmp_path):
    p = tmp_path / 'x.stf'
    p.write_text(' 1S 7.3  2S\n ))\n')
    with pytest.raises(BasisError, match='exponent'):
        read_basis(str(p), ntype=1)
    p.write_text(' S 7.3\n ))\n')
    with pytest.raises(BasisError, match="orbital type"):
        read_basis(str(p), ntype=1)


# --- NOB < NBF and from_record -------------------------------------------

def test_b_stf_nob_from_outer(atinputs_dir):
    deck = build(_load(atinputs_dir / 'b_stf.inp'), basis_dir=str(atinputs_dir))
    b = _blocks(deck)
    assert b['AI'].params['ntype'] == 1
    assert b['TR'].params['nob'].values == [8, 7, 6, 5, 4, 2, 1]
    assert b['TR'].params['nbf'].values == [10, 9, 8, 8, 6, 4, 2]
    assert b['TR'].params['mpob'].values[:8] == list(range(8, 0, -1))
    assert b['GET'].params['nind'] == 7
    assert b['GET'].params['ind'].values[:8] == [1, 0, 1, 8, 1, 1, 1, 7]


def test_nob_equal_nbf_is_unchanged(atinputs_dir, samples_dir):
    # f.inp: outer counts fill the basis exactly, so NOB stays NBF.
    deck = build(_load(atinputs_dir / 'f.inp'), basis_dir=str(samples_dir))
    assert _blocks(deck)['TR'].params['nob'].values == [13, 11, 6, 5]


def _lint_text(tmp_path, samples_dir, text):
    p = tmp_path / 'x.inp'
    p.write_text(text)
    return lint(_load(p), basis_dir=str(samples_dir), inp_path=str(p))


def _errors(findings):
    return [f.message for f in findings if f.severity == 'error']


def test_outer_beyond_basis_is_error(tmp_path, samples_dir):
    text = PARAMS_INP.replace('outer:        11S, 10P, 6D, 5F', 'outer: 12S, 10P, 6D, 5F, 1G')
    errors = _errors(_lint_text(tmp_path, samples_dir, text))
    assert any('need 14 orbitals' in m for m in errors)
    assert any('no G functions' in m for m in errors)


def test_symmetry_without_orbitals_is_error(tmp_path, samples_dir):
    text = PARAMS_INP.replace('outer:        11S, 10P, 6D, 5F', 'outer: 11S, 10P, 6D')
    errors = _errors(_lint_text(tmp_path, samples_dir, text))
    assert any('symmetry 4 (F)' in m and 'NOB=0' in m for m in errors)


def test_ind_and_from_record_together_is_error(tmp_path, samples_dir):
    text = PARAMS_INP.replace(
        '    from_record: 1\n',
        '    from_record: 1\n    ind:\n      - record: 1, l: 0, first: 1, last: 13\n')
    errors = _errors(_lint_text(tmp_path, samples_dir, text))
    assert any('both ind and from_record' in m for m in errors)


def test_ind_gap_is_warning(tmp_path, samples_dir):
    text = PARAMS_INP.replace(
        '    from_record: 1\n',
        '    ind:\n      - record: 1, l: 0, first: 1, last: 12\n'
        '      - record: 1, l: 1, first: 1, last: 11\n'
        '      - record: 1, l: 2, first: 1, last: 6\n'
        '      - record: 1, l: 3, first: 1, last: 5\n')
    findings = _lint_text(tmp_path, samples_dir, text)
    assert any(f.severity == 'warning' and 'l=0 cover orbitals 1-12' in f.message
               for f in findings)
    assert not _errors(findings)


def test_ioflg_vectors_and_density_to_records_is_error(tmp_path, samples_dir):
    text = PARAMS_INP.replace('ioflg:  0 0 0 0 0 0', 'ioflg:  0 2 0 0 0 0')
    errors = _errors(_lint_text(tmp_path, samples_dir, text))
    assert any('IOFLG(2)=2 with IOFLG(3)=0' in m for m in errors)


def test_params_input_lints_clean(tmp_path, samples_dir):
    assert not _errors(_lint_text(tmp_path, samples_dir, PARAMS_INP))


# --- parameters -----------------------------------------------------------

def test_new_parameters_are_emitted(tmp_path, samples_dir):
    deck = build(_params_data(tmp_path), basis_dir=str(samples_dir))
    b = _blocks(deck)
    mc = b['MC'].params
    assert mc['nset'] == 2 and mc['itmax'] == 30
    assert mc['ethr'] == 1e-8 and mc['c2thr'] == 1e-6 and mc['nsol'] == 1
    assert mc['nopt'].values == [1, 1, 1]
    assert mc['nind'] == 4 and mc['ind'].values[:4] == [1, 0, 1, 13]
    assert 'idprnt' not in b['AI'].params
    assert b['WF'].params['ismax'] == 21 and 'npflg' not in b['WF'].params
    assert b['GET'].params['nbase'] == 0
    assert b['PT'].params == {'istate': 1, 'ips': 6, 'pthr': 1.0,
                              'nrnfg': IntList([1, 1, 1])}
    assert b['EX'].params == {'nfexw': 14, 'nfexe': 15}
    ci = b['CI'].params
    assert ci['ioflg'].values == [0, 0, 0, 0, 0, 0]
    assert ci['nfiv'] == 37 and ci['thrcsf'] == 0.001 and ci['xref'].values == [-99.6]
    assert 'maxit' not in ci
    assert b['RS'].params == {'pthr': -0.001, 'rule': 1, 'nrnfg': 1}


def test_emitted_members_are_all_declared(tmp_path, atinputs_dir, samples_dir):
    declared, _at_limit = verify_namelists.load_source()
    decks = [build(_params_data(tmp_path), basis_dir=str(samples_dir)),
             build(_load(atinputs_dir / 'f_no.inp'), basis_dir=str(samples_dir)),
             build(_load(atinputs_dir / 'b_stf.inp'), basis_dir=str(atinputs_dir))]
    for deck in decks:
        for p in deck.passes:
            for block in p.blocks:
                missing = {n.upper() for n in block.params} - set(declared.get(block.group, []))
                assert not missing, f"&{block.group}: {sorted(missing)}"


def test_number_list_errors(tmp_path):
    text = PARAMS_INP.replace('nopt:   1 1 1', 'nopt:   1 x 1')
    with pytest.raises(SchemaError, match='expects integers'):
        _params_data(tmp_path, text)


# --- passes ---------------------------------------------------------------

def test_f_no_passes(atinputs_dir, samples_dir):
    data = _load(atinputs_dir / 'f_no.inp')
    assert 'ctrl' not in data
    deck = build(data, basis_dir=str(samples_dir))
    assert [p.nrnfg for p in deck.passes] == [
        [1, 1, 1, 1, 0, 0, 1, 1], [0, 0, 0, 1, 0, 0, 1, 1], [0, 0, 0, 0, 0, 0, 0, 1]]
    assert _blocks(deck, 1)['GET'].params['ind'].values[:4] == [2, 0, 1, 13]
    assert _blocks(deck, 2)['RS'].params['rule'] == 1
    findings = lint(data, basis_dir=str(samples_dir), inp_path=str(atinputs_dir / 'f_no.inp'))
    assert not _errors(findings)


# --- end to end -----------------------------------------------------------

def _run(data, basis_dir, tmp_path):
    deck = build(data, basis_dir=basis_dir)
    (tmp_path / data['deck']).write_text(emit(deck))
    obtain_csf(data, 'python', work_dir=str(tmp_path))
    with (tmp_path / data['deck']).open() as f:
        result = subprocess.run([ATOMCI], stdin=f, cwd=str(tmp_path),
                                capture_output=True, text=True, errors='replace')
    assert result.returncode == 0, result.stdout[-2000:]
    assert 'RETURN CODE IS    0' in result.stdout
    bad = [ln for ln in result.stdout.splitlines()
           if 'RETURN CODE IS' in ln and 'RETURN CODE IS    0' not in ln]
    assert not bad, bad
    return [ln.split()[-1] for ln in result.stdout.splitlines()
            if 'SD-CI ENERGY  ' in ln]


@pytest.mark.skipif(not HAVE_ATOMCI, reason='installed atomci binary not available (set ATOMCI_HOME)')
def test_f_no_reproduces_f_stdin(atinputs_dir, samples_dir, tmp_path):
    (tmp_path / 'f.bas').write_bytes((samples_dir / 'f.bas').read_bytes())
    (tmp_path / 'CFPTBL').symlink_to(os.path.join(ATOMCI_HOME, 'CFPTBL'))
    energies = _run(_load(atinputs_dir / 'f_no.inp'), str(samples_dir), tmp_path)
    assert energies == ['-99.641223', '-99.641037', '-99.641037']


@pytest.mark.skipif(not HAVE_ATOMCI, reason='installed atomci binary not available (set ATOMCI_HOME)')
def test_b_stf_golden(atinputs_dir, tmp_path):
    (tmp_path / 'boron.basis.txt').write_bytes((atinputs_dir / 'boron.basis.txt').read_bytes())
    (tmp_path / 'CFPTBL').symlink_to(os.path.join(ATOMCI_HOME, 'CFPTBL'))
    energies = _run(_load(atinputs_dir / 'b_stf.inp'), str(atinputs_dir), tmp_path)
    assert energies == ['-24.599517']
