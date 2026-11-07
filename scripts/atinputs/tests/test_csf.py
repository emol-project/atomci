import os

import pytest

from ..csf import CsfSourceError, obtain_csf
from .test_atg import HAVE_ATGEN


def test_file_source_missing_is_error(tmp_path):
    data = {'csf': 'missing.csf'}
    with pytest.raises(CsfSourceError, match='does not exist'):
        obtain_csf(data, 'file', work_dir=str(tmp_path))


def test_file_source_present_is_noop(tmp_path):
    (tmp_path / 'x.csf').write_text('placeholder')
    data = {'csf': 'x.csf'}
    result = obtain_csf(data, 'file', work_dir=str(tmp_path))
    assert result is None
    assert (tmp_path / 'x.csf').read_text() == 'placeholder'


def test_python_source_generates_csf(tmp_path, atinputs_dir, reference_dir):
    from ..parser import parse_file
    from ..schema import validate
    path = str(atinputs_dir / 'f.inp')
    data = validate(parse_file(path), path)
    result = obtain_csf(data, 'python', work_dir=str(tmp_path))
    assert result is None
    generated = (tmp_path / data['csf']).read_text()
    expected = (reference_dir / 'f.atgen.csf').read_text()
    assert generated == expected


def test_unknown_source_is_error(tmp_path):
    data = {'csf': 'x.csf'}
    with pytest.raises(CsfSourceError, match='unknown csf_source'):
        obtain_csf(data, 'bogus', work_dir=str(tmp_path))


@pytest.mark.skipif(not HAVE_ATGEN, reason='native atgen binary not available')
def test_atgen_source_generates_csf(tmp_path, atinputs_dir):
    from ..parser import parse_file
    from ..schema import validate
    path = str(atinputs_dir / 'f.inp')
    data = validate(parse_file(path), path)
    atg_path = obtain_csf(data, 'atgen', work_dir=str(tmp_path))
    assert atg_path is not None
    assert os.path.isfile(atg_path)
    assert (tmp_path / data['csf']).is_file()
