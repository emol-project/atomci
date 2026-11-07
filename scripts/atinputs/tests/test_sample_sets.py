"""samples/native/ and samples/inp/ are flat, closed input sets: every file a
calculation reads is in its own directory, and neither uses the other."""
import re

import pytest

NAMES = ('boron', 'boron_nsdim700', 'f', 'fpt', 'sc', 'ti', 'cu', 'be', 'c')
REFERS_TO_FILE = re.compile(r'^\s*(?:basis|path):\s*(\S+)', re.M)
GOES_OUTSIDE = re.compile(r'\.\./|dirname "\$here"|samples/')


@pytest.fixture
def native_dir(repo_root):
    return repo_root / 'samples' / 'native'


@pytest.fixture
def inp_dir(repo_root):
    return repo_root / 'samples' / 'inp'


@pytest.mark.parametrize('name', NAMES)
def test_each_calculation_is_in_both_sets(name, native_dir, inp_dir):
    assert (native_dir / f'{name}.stdin').is_file()
    assert (inp_dir / f'{name}.inp').is_file()


def test_sets_are_flat(native_dir, inp_dir):
    for d in (native_dir, inp_dir):
        assert [p.name for p in d.iterdir() if p.is_dir() and p.name != 'work'] == []


@pytest.mark.parametrize('name', NAMES)
def test_inp_files_are_next_to_it(name, inp_dir):
    text = (inp_dir / f'{name}.inp').read_text()
    for filename in REFERS_TO_FILE.findall(text):
        assert (inp_dir / filename).is_file(), filename


def test_atg_decks_have_their_basis(native_dir):
    for deck in native_dir.glob('*.atg'):
        basis = 'f.bas' if deck.stem == 'fpt' else f'{deck.stem}.bas'
        assert (native_dir / basis).is_file(), deck.name


def test_shared_basis_files_agree(native_dir, inp_dir):
    copies = sorted(p.name for p in inp_dir.glob('*.bas'))
    assert copies == sorted(p.name for p in native_dir.glob('*.bas'))
    for name in copies:
        assert (inp_dir / name).read_bytes() == (native_dir / name).read_bytes(), name


def test_runners_stay_in_their_directory(native_dir, inp_dir):
    for script in (native_dir / 'run_native.sh', inp_dir / 'run_inp.sh'):
        body = '\n'.join(line for line in script.read_text().splitlines()
                         if not line.lstrip().startswith('#'))
        assert not GOES_OUTSIDE.search(body), script.name
