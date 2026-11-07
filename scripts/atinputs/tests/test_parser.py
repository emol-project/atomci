import pytest

from ..parser import Mapping, NodeList, ParseError, RawValue, parse


def test_key_value_scalar():
    m = parse('deck: f.deck\n', 'x.inp')
    assert isinstance(m['deck'], RawValue)
    assert m['deck'].scalar() == 'f.deck'


def test_nested_mapping():
    text = 'atom:\n  z: 9\n  ang: P\n'
    m = parse(text, 'x.inp')
    assert isinstance(m['atom'], Mapping)
    assert m['atom']['z'].scalar() == '9'
    assert m['atom']['ang'].scalar() == 'P'


def test_list_items():
    text = 'outer:\n  - a\n  - b\n'
    m = parse(text, 'x.inp')
    assert isinstance(m['outer'], NodeList)
    assert [v.scalar() for v in m['outer']] == ['a', 'b']


def test_comment_to_eol_ignored():
    m = parse('deck: f.deck  # a comment\n', 'x.inp')
    assert m['deck'].scalar() == 'f.deck'


def test_comment_only_line_ignored():
    m = parse('# just a comment\ndeck: f.deck\n', 'x.inp')
    assert list(m.keys()) == ['deck']


def test_blank_lines_ignored():
    m = parse('\n\ndeck: f.deck\n\n\ncsf: f.csf\n\n', 'x.inp')
    assert m['deck'].scalar() == 'f.deck'
    assert m['csf'].scalar() == 'f.csf'


def test_tab_in_indentation_is_error():
    text = 'atom:\n\tz: 9\n'
    with pytest.raises(ParseError) as exc:
        parse(text, 'f.inp')
    assert 'tab' in str(exc.value)
    assert 'f.inp:2:' in str(exc.value)


def test_quoted_value_preserves_whitespace():
    m = parse('title:  " F DOUBLET P "\n', 'x.inp')
    assert m['title'].scalar() == ' F DOUBLET P '


def test_quote_disables_comma_and_hash():
    m = parse('title: "a, b # c"\n', 'x.inp')
    assert m['title'].scalar() == 'a, b # c'


def test_escaped_quote_and_backslash():
    m = parse(r'title: "a \"b\" c\\d"' + '\n', 'x.inp')
    assert m['title'].scalar() == 'a "b" c\\d'


def test_wrong_indent_step_is_error():
    # child must be exactly +2, not +1 or +4
    text = 'atom:\n z: 9\n'
    with pytest.raises(ParseError):
        parse(text, 'x.inp')


# --- §4.4: the one ambiguity, resolved by schema.py; the parser's job is
# only to capture both possible interpretations faithfully. ---------------

def test_inline_record_form_captured_as_raw_text():
    m = parse('ai: type: 2, idprnt: 0\n', 'x.inp')
    assert isinstance(m['ai'], RawValue)
    record = m['ai'].record()
    assert record['type'].scalar() == '2'
    assert record['idprnt'].scalar() == '0'


def test_nested_record_form_captured_as_mapping():
    text = 'tr:\n  ind:\n    - record: 1, l: 0, first: 1, last: 13\n'
    m = parse(text, 'x.inp')
    assert isinstance(m['tr'], Mapping)
    assert isinstance(m['tr']['ind'], NodeList)
    row = m['tr']['ind'][0].record()
    assert row['record'].scalar() == '1'
    assert row['last'].scalar() == '13'


def test_scalars_and_nested_blocks_coexist_in_one_mapping():
    # fpt.inp's tr: record: 1 (scalar) sits alongside ind: (nested list)
    text = 'tr:\n  record: 1\n  ind:\n    - record: 2, l: 0, first: 1, last: 2\n'
    m = parse(text, 'x.inp')
    assert m['tr']['record'].scalar() == '1'
    assert isinstance(m['tr']['ind'], NodeList)


def test_string_typed_value_with_colon_quoted():
    m = parse('title: "abc: def"\n', 'x.inp')
    assert m['title'].scalar() == 'abc: def'


def test_string_typed_value_with_colon_unquoted():
    # the parser only splits on the FIRST top-level ':' (the key delimiter);
    # a string-typed key's value runs to end of line, colons and all.
    m = parse('deck: some:weird:value\n', 'x.inp')
    assert m['deck'].scalar() == 'some:weird:value'


def test_list_items_as_inline_records():
    text = 'open:\n  - unit: 27, file: f.NO, format: binary, status: unknown\n'
    m = parse(text, 'x.inp')
    row = m['open'][0].record()
    assert row['unit'].scalar() == '27'
    assert row['file'].scalar() == 'f.NO'
    assert row['format'].scalar() == 'binary'
    assert row['status'].scalar() == 'unknown'
