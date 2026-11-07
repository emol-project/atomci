"""Multi-reference SD-CI inputs (samples/inp/be.inp, c.inp; added
2026-11-03). Before then ITNEL and IPAR were summed over all references,
which doubled the electron count of a two-reference input."""

import os
import subprocess

import pytest

from ..csf import obtain_csf
from ..emit import emit
from ..lint import lint
from ..parser import parse_file
from ..schema import validate
from ..sugar import build, mcscf_references

ATOMCI_HOME = os.environ.get('ATOMCI_HOME')
ATOMCI = os.path.join(ATOMCI_HOME, 'bin', 'atomci') if ATOMCI_HOME else None
ATGEN = os.path.join(ATOMCI_HOME, 'bin', 'atgen') if ATOMCI_HOME else None
HAVE_ATOMCI = bool(ATOMCI and os.path.isfile(ATOMCI))

# name -> (Z, ITNEL, ISPIN, IORB, MCSCF energy, SD-CI energy)
CASES = {
    'be': (4, 4, 1, 1, '-14.61643826', '-14.618544'),
    'c': (6, 6, 3, 3, '-37.70402270', '-37.779409'),
}


def _load(path):
    return validate(parse_file(str(path)), str(path))


def _blocks(deck):
    return {b.group: b for b in deck.passes[0].blocks}


@pytest.fixture
def inp_dir(repo_root):
    return repo_root / 'samples' / 'inp'


@pytest.mark.parametrize('name', sorted(CASES))
def test_term_and_electrons_from_one_reference(name, inp_dir):
    z, itnel, ispin, iorb, _e_mc, _e_ci = CASES[name]
    data = _load(inp_dir / f'{name}.inp')
    blocks = _blocks(build(data, basis_dir=str(inp_dir)))
    for group in ('MC', 'WF'):
        p = blocks[group].params
        assert (p['itnel'], p['ispin'], p['iorb'], p['ipar']) == (itnel, ispin, iorb, 0)
    assert len(blocks['MC'].params['csfs'].values) == 3      # two references + ' )))'


@pytest.mark.parametrize('name', sorted(CASES))
def test_multiref_inputs_lint_clean(name, inp_dir):
    path = inp_dir / f'{name}.inp'
    findings = lint(_load(path), basis_dir=str(inp_dir), inp_path=str(path))
    assert not [f for f in findings if f.level == 'error'], findings


def test_mcscf_references_follow_the_scf_flag():
    refs = [{'scf': True, 'occ': '2S*2 2P*2'}, {'occ': '2S*0 2P*4'}]
    assert mcscf_references(refs) == refs[:1]
    unmarked = [{'occ': '2S*2 2P*2'}, {'occ': '2S*0 2P*4'}]
    assert mcscf_references(unmarked) == unmarked


@pytest.mark.skipif(not (HAVE_ATOMCI and os.path.isfile(ATGEN)),
                    reason='installed atomci/atgen not available (set ATOMCI_HOME)')
@pytest.mark.parametrize('name', sorted(CASES))
def test_multiref_golden_and_matches_native(name, samples_dir, inp_dir, tmp_path):
    _z, _itnel, _ispin, _iorb, e_mc, e_ci = CASES[name]
    (tmp_path / f'{name}.bas').write_bytes((inp_dir / f'{name}.bas').read_bytes())
    (tmp_path / 'CFPTBL').symlink_to(os.path.join(ATOMCI_HOME, 'CFPTBL'))
    data = _load(inp_dir / f'{name}.inp')
    (tmp_path / data['deck']).write_text(emit(build(data, basis_dir=str(inp_dir))))
    obtain_csf(data, 'python', work_dir=str(tmp_path))
    generated = (tmp_path / data['csf']).read_text()
    # the CSF list of the native atgen input is the same
    with (samples_dir / f'{name}.atg').open() as f:
        subprocess.run([ATGEN], stdin=f, cwd=str(tmp_path), capture_output=True, check=True)
    assert (tmp_path / f'{name}.csf').read_text() == generated
    with (tmp_path / data['deck']).open() as f:
        out = subprocess.run([ATOMCI], stdin=f, cwd=str(tmp_path), capture_output=True,
                             text=True, errors='replace').stdout
    bad = [ln for ln in out.splitlines()
           if 'RETURN CODE IS' in ln and 'RETURN CODE IS    0' not in ln]
    assert not bad, bad
    assert [ln.split()[3] for ln in out.splitlines() if 'Total Energy =' in ln] == [e_mc]
    assert [ln.split()[-1] for ln in out.splitlines() if 'SD-CI ENERGY  ' in ln] == [e_ci]
