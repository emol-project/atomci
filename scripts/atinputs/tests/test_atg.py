import os
import shutil
import subprocess

import pytest

from ..atg import read_atg, write_atg
from ..parser import parse_file
from ..schema import validate

ATGEN = shutil.which('atgen') or (
    os.path.join(os.environ['ATOMCI_HOME'], 'bin', 'atgen')
    if os.environ.get('ATOMCI_HOME') else None
)
HAVE_ATGEN = bool(ATGEN and os.path.isfile(ATGEN))


def _load(atinputs_dir, name):
    path = str(atinputs_dir / f'{name}.inp')
    return validate(parse_file(path), path)


def test_f_atg_structure(atinputs_dir):
    data = _load(atinputs_dir, 'f')
    text = write_atg(data)
    lines = text.splitlines()
    assert lines[0] == 'OPEN UNIT=7 FILE=f.csf'
    assert lines[1] == 'END'
    assert lines[3] == ' 11S 10P 6D 5F )))'
    assert lines[5] == ' 2S 2P )))'
    assert lines[7] == ' 2S*2) 2P*5))'
    assert lines[8] == ' )))'
    assert lines[10] == ' 2S 2P )))'
    assert lines[11] == '   1S'
    assert lines[12] == ' -1'


def test_card1_sorted_regardless_of_inp_order():
    # CARD 1 token order is load-bearing for native atgen's NKIND
    # computation (see atg.py's docstring) -- the writer must not just
    # pass through whatever order the .inp happened to list 'outer' in.
    data = {
        'csf': 'x.csf',
        'orbital': {
            'outer': [
                {'label': '5F', 'n': 5, 'l': 3},
                {'label': '11S', 'n': 11, 'l': 0},
                {'label': '6D', 'n': 6, 'l': 2},
                {'label': '10P', 'n': 10, 'l': 1},
            ],
            'active': [],
            'frozen_core': [],
        },
        'reference': [{'occ': '2S*2'}],
    }
    text = write_atg(data)
    card1 = text.splitlines()[3]
    assert card1 == ' 11S 10P 6D 5F )))'


def test_multi_shell_reference_paren_grammar():
    data = {
        'csf': 'x.csf',
        'orbital': {'outer': [], 'active': [], 'frozen_core': []},
        'reference': [{'occ': '2S*2 2P*3 3P*1'}],
    }
    text = write_atg(data)
    ref_line = text.splitlines()[7]
    # single ')' between shells, double '))' after the last shell of a config
    assert ref_line == ' 2S*2) 2P*3) 3P*1))'


def test_wide_reference_wraps_card3_at_72_columns(tmp_path):
    # CARD 3 is read (A) into a *72 buffer (src/atlib.f) --
    # an unwrapped line here used to run to 73 columns for exactly this
    # data and crash real atgen (segfault, confirmed against gfortran
    # 14.2.0; see atg.py's CARD 3 docstring). write_atg now wraps at 72,
    # breaking only between complete tokens.
    data = {
        'csf': 'x.csf',
        'orbital': {'outer': [], 'active': [], 'frozen_core': []},
        'reference': [{'occ': ('1S*2 1P*6 2P*6 1D*10 2D*10 3D*10 4D*10 '
                                '1F*14 2F*14 1G*2 1H*2')}],
    }
    text = write_atg(data)
    ref_lines = text.splitlines()[7:9]
    assert ref_lines == [
        ' 1S*2) 1P*6) 2P*6) 1D*10) 2D*10) 3D*10) 4D*10) 1F*14) 2F*14) 1G*2)',
        ' 1H*2))',
    ]
    assert all(len(line) <= 72 for line in ref_lines)
    # No token split across the boundary -- round-trips to the same tokens
    # a hypothetical unwrapped line would have parsed to.
    atg_path = tmp_path / 'x.atg'
    atg_path.write_text(text)
    d = read_atg(str(atg_path))
    assert d.reference == [[
        ('1S', 2), ('1P', 6), ('2P', 6), ('1D', 10), ('2D', 10),
        ('3D', 10), ('4D', 10), ('1F', 14), ('2F', 14), ('1G', 2), ('1H', 2),
    ]]


def test_read_sample_f_atg(samples_dir):
    d = read_atg(str(samples_dir / 'f.atg'))
    assert d.csf_unit == 7
    assert d.csf_file == 'f.csf'
    assert d.outer == {'S': 11, 'P': 10, 'D': 6, 'F': 5}
    assert d.active == ['2S', '2P']
    assert d.reference == [[('2S', 2), ('2P', 5)]]
    assert d.coupling_order == ['2S', '2P']
    assert d.closed_shell_text.strip() == '1S'
    assert d.sgshl == -1


def test_read_sample_fpt_atg(samples_dir):
    d = read_atg(str(samples_dir / 'fpt.atg'))
    assert d.csf_file == 'fpt.csf'
    assert d.reference == [[('2S', 2), ('2P', 5)]]


def test_write_then_read_round_trips(atinputs_dir, tmp_path):
    data = _load(atinputs_dir, 'f')
    atg_path = tmp_path / 'f.atg'
    atg_path.write_text(write_atg(data))
    d = read_atg(str(atg_path))
    assert d.csf_unit == 7
    assert d.csf_file == 'f.csf'
    assert d.outer == {'S': 11, 'P': 10, 'D': 6, 'F': 5}
    assert d.active == ['2S', '2P']
    assert d.reference == [[('2S', 2), ('2P', 5)]]
    assert d.coupling_order == ['2S', '2P']
    assert d.closed_shell_text.strip() == '1S'
    assert d.sgshl == -1


def test_read_multi_shell_multi_reference_card3(tmp_path):
    atg_path = tmp_path / 'x.atg'
    atg_path.write_text(
        'OPEN UNIT=7 FILE=x.csf\n'
        'END\n'
        '" title\n'
        ' 1S )))\n'
        '" title\n'
        ' 1S )))\n'
        '" title\n'
        ' 1S*1) 2S*1)) 3S*2))\n'
        ' )))\n'
        '" title\n'
        ' 1S )))\n'
        ' 1S\n'
        ' -1\n'
    )
    d = read_atg(str(atg_path))
    assert d.reference == [[('1S', 1), ('2S', 1)], [('3S', 2)]]


@pytest.mark.skipif(not HAVE_ATGEN, reason='native atgen binary not available')
def test_round_trip_matches_reference_atgen_csf(atinputs_dir, reference_dir, tmp_path):
    for name in ('f', 'fpt'):
        data = _load(atinputs_dir, name)
        atg_path = tmp_path / f'{name}.atg'
        atg_path.write_text(write_atg(data))
        with open(atg_path) as f:
            result = subprocess.run([ATGEN], stdin=f, cwd=str(tmp_path),
                                     capture_output=True, text=True)
        assert result.returncode == 0, result.stdout
        generated = (tmp_path / data['csf']).read_text()
        expected = (reference_dir / f'{name}.atgen.csf').read_text()
        assert generated == expected
