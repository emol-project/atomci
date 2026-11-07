import pytest

from ..parser import parse
from ..schema import SchemaError, validate

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
reference:
  - occ: 2S*2 2P*5
ctrl:
"""


def _validate(text):
    return validate(parse(text, 'x.inp'), 'x.inp')


def test_minimal_document_validates():
    data = _validate(MINIMAL)
    assert data['atom']['z'] == 9
    assert data['reference'][0]['occ'] == '2S*2 2P*5'


def test_int_coercion_failure_message():
    text = MINIMAL.replace('z: 9', 'z: nine')
    with pytest.raises(SchemaError) as exc:
        _validate(text)
    assert "expects an integer (cannot parse 'nine')" in str(exc.value)


def test_unknown_key_did_you_mean():
    text = MINIMAL + '  mc:\n    itmx: 5\n'
    with pytest.raises(SchemaError) as exc:
        _validate(text)
    assert "unknown key 'itmx'" in str(exc.value)
    assert "did you mean 'itmax'?" in str(exc.value)


def test_missing_required_key():
    text = MINIMAL.replace('  z: 9\n', '')
    with pytest.raises(SchemaError) as exc:
        _validate(text)
    assert "missing required key 'z'" in str(exc.value)


def test_bool_true_false():
    text = MINIMAL + '  ex:\n    retry: false\n'
    data = _validate(text)
    assert data['ctrl']['ex']['retry'] is False


def test_bool_bad_value():
    text = MINIMAL + '  ex:\n    retry: maybe\n'
    with pytest.raises(SchemaError):
        _validate(text)


def test_shells_shorthand():
    text = MINIMAL.replace('orbital:\n', 'orbital:\n  outer: 11S, 10P, 6D, 5F\n')
    data = _validate(text)
    assert data['orbital']['outer'] == [
        {'label': '11S', 'n': 11, 'l': 0},
        {'label': '10P', 'n': 10, 'l': 1},
        {'label': '6D', 'n': 6, 'l': 2},
        {'label': '5F', 'n': 5, 'l': 3},
    ]


def test_shells_bad_token_shape():
    text = MINIMAL.replace('orbital:\n', 'orbital:\n  outer: eleven-S\n')
    with pytest.raises(SchemaError):
        _validate(text)


def test_shells_unknown_letter():
    # 'J' is conventionally skipped in spectroscopic notation
    text = MINIMAL.replace('orbital:\n', 'orbital:\n  outer: 11J\n')
    with pytest.raises(SchemaError):
        _validate(text)


def test_record_inline_and_nested_forms_agree():
    inline = MINIMAL + '  ai: type: 2, idprnt: 0\n'
    nested = MINIMAL + '  ai:\n    type: 2\n    idprnt: 0\n'
    assert _validate(inline)['ctrl']['ai'] == _validate(nested)['ctrl']['ai']


def test_list_of_record_open():
    text = MINIMAL.replace(
        '  format: atomci\n',
        '  format: atomci\n  open:\n    - unit: 27, file: f.NO, format: binary, status: unknown\n')
    data = _validate(text)
    assert data['files']['open'] == [
        {'unit': 27, 'file': 'f.NO', 'format': 'binary', 'status': 'unknown'}]


def test_empty_list_of_record_is_empty_list():
    # ctrl.tr.ind: with nothing under it -> [] rather than a type error,
    # so lint.py can give the dedicated "ind is empty" diagnostic.
    text = MINIMAL + '  tr:\n    ind:\n'
    data = _validate(text)
    assert data['ctrl']['tr']['ind'] == []
