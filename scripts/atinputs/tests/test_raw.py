import pytest

from ..ir import Block, IntList, Payload, QuotedStr
from ..parser import parse
from ..raw import RawError, build_raw_blocks, merge
from ..schema import SchemaError, validate

# raw: list items use the bare-dash-then-indented-mapping form
# ('-' alone, fields indented 2 past it) -- parser.py's list-item grammar
# only supports either a single-line inline record (used elsewhere, e.g.
# files.open) or this form; it does not support '- key: val' with more
# fields nested underneath, which a multi-field raw block (group + params +
# payload, each themselves nested) needs.
_MINIMAL_RAW = """
title: x
deck: x.deck
atom:
  z: 5
  ang: P
  spin: 2
files:
  cfptable: ./CFPTBL
  format: atomci
orbital:
reference:
ctrl:
raw:
  -
    group: CNTL
    params:
      nrnfg: 1,0,1,1,0,1,1,1
      title: " B (DOUBLET P ODD) "
  -
    group: AI
    params:
      iunit: 5
      nwt: 47
      z: 5.0D0
"""

_BASVC_BLOCK = """  -
    group: BASVC
    payload:
      kind: vectors
      path: {path}
"""


def _validate(text):
    return validate(parse(text, 'x.inp'), 'x.inp')


# --- schema: RawParams coercion --------------------------------------------

def test_raw_block_validates():
    data = _validate(_MINIMAL_RAW)
    assert len(data['raw']) == 2
    assert data['raw'][0]['group'] == 'CNTL'


def test_raw_params_quoted_string_becomes_quotedstr():
    data = _validate(_MINIMAL_RAW)
    title = data['raw'][0]['params']['title']
    assert isinstance(title, QuotedStr)
    assert title.value == ' B (DOUBLET P ODD) '


def test_raw_params_comma_list_becomes_intlist():
    data = _validate(_MINIMAL_RAW)
    nrnfg = data['raw'][0]['params']['nrnfg']
    assert isinstance(nrnfg, IntList)
    assert nrnfg.values == ['1', '0', '1', '1', '0', '1', '1', '1']
    assert nrnfg.wrap is None


def test_raw_params_single_token_passes_through_literally():
    data = _validate(_MINIMAL_RAW)
    params = data['raw'][1]['params']
    assert params['nwt'] == '47'
    assert params['z'] == '5.0D0'  # D-exponent literal preserved verbatim


def test_raw_params_inline_record_form_rejected():
    # RawParams requires a true nested block -- an inline record's
    # top-level comma split would misparse a comma-list value.
    text = _MINIMAL_RAW.replace(
        '    params:\n      iunit: 5\n      nwt: 47\n      z: 5.0D0\n',
        '    params: iunit: 5, nwt: 47, z: 5.0D0\n')
    with pytest.raises(SchemaError):
        _validate(text)


def test_raw_payload_requires_kind():
    text = _MINIMAL_RAW + '  -\n    group: BASVC\n    payload:\n      path: x.txt\n'
    with pytest.raises(SchemaError) as exc:
        _validate(text)
    assert "missing required key 'kind'" in str(exc.value)


# --- raw.py: build_raw_blocks / merge --------------------------------------

def test_build_raw_blocks_no_payload():
    data = _validate(_MINIMAL_RAW)
    blocks = build_raw_blocks(data['raw'], 'x.inp')
    assert [b.group for b in blocks] == ['CNTL', 'AI']
    assert blocks[1].payload is None
    assert blocks[1].params['nwt'] == '47'


def test_build_raw_blocks_reads_payload_sidecar(tmp_path):
    sidecar = tmp_path / 'b.basis.txt'
    sidecar.write_text('1S 15.3745\n))\n')
    # b.inp itself need not exist -- build_raw_blocks only uses its
    # directory (via inp_path) to locate the sidecar, matching
    # _resolve_basis_dir's search-by-directory convention.
    inp_path = str(tmp_path / 'b.inp')
    data = _validate(_MINIMAL_RAW + _BASVC_BLOCK.format(path='b.basis.txt'))
    blocks = build_raw_blocks(data['raw'], inp_path)
    basvc = next(b for b in blocks if b.group == 'BASVC')
    assert basvc.payload == Payload(kind='vectors', lines=['1S 15.3745', '))'])


def test_build_raw_blocks_missing_sidecar_raises(tmp_path):
    inp_path = str(tmp_path / 'b.inp')
    data = _validate(_MINIMAL_RAW + _BASVC_BLOCK.format(path='does-not-exist.txt'))
    with pytest.raises(RawError):
        build_raw_blocks(data['raw'], inp_path)


def test_merge_replaces_same_group_in_place():
    blocks = [Block('CNTL', {'a': 1}), Block('AI', {'b': 2}), Block('RS', {'c': 3})]
    raw_blocks = [Block('AI', {'b': 99})]
    merged = merge(blocks, raw_blocks)
    assert [b.group for b in merged] == ['CNTL', 'AI', 'RS']
    assert merged[1].params == {'b': 99}


def test_merge_appends_new_groups_in_raw_order():
    blocks = [Block('CNTL', {})]
    raw_blocks = [Block('AI', {}), Block('WF', {}), Block('BASVC', {})]
    merged = merge(blocks, raw_blocks)
    assert [b.group for b in merged] == ['CNTL', 'AI', 'WF', 'BASVC']


def test_merge_is_case_insensitive_on_group_name():
    blocks = [Block('CNTL', {'a': 1})]
    raw_blocks = [Block('cntl', {'a': 2})]
    merged = merge(blocks, raw_blocks)
    assert len(merged) == 1
    assert merged[0].params == {'a': 2}
