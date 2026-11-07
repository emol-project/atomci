from ..emit import emit
from ..ir import Block, Deck, IntList, OpenLine, Pass, Payload, QuotedStr, StringArray
from ..parser import parse_file
from ..schema import validate
from ..sugar import build


def test_intlist_wraps_flat_at_n():
    deck = Deck(open=[], passes=[Pass(title='t', nrnfg=[0] * 8, blocks=[
        Block('TR', {'mpob': IntList(list(range(1, 26)), wrap=10)}),
    ])])
    text = emit(deck)
    lines = text.splitlines()
    assert lines[lines.index(' &tr') + 1] == 'mpob=' + ','.join(str(v) for v in range(1, 11)) + ','
    assert lines[lines.index(' &tr') + 2] == ','.join(str(v) for v in range(11, 21)) + ','
    assert lines[lines.index(' &tr') + 3] == ','.join(str(v) for v in range(21, 26)) + ','


def test_intlist_unwrapped_on_one_line():
    deck = Deck(open=[], passes=[Pass(title='t', nrnfg=[0] * 8, blocks=[
        Block('CI', {'nrnfg': IntList([1, 1, 1, 0, 1, 1])}),
    ])])
    text = emit(deck)
    assert 'nrnfg=1,1,1,0,1,1,\n' in text


def test_quoted_str_and_string_array():
    deck = Deck(open=[], passes=[Pass(title='t', nrnfg=[0] * 8, blocks=[
        Block('MC', {
            'closed': QuotedStr(' 1S)'),
            'csfs': StringArray([' 2S*2) 2P*5))', ' )))']),
        }),
    ])])
    text = emit(deck)
    assert "closed=' 1S)',\n" in text
    assert "csfs(1)=' 2S*2) 2P*5))',\n" in text
    assert "csfs(2)=' )))',\n" in text


def test_group_line_and_terminator():
    deck = Deck(open=[], passes=[Pass(title='t', nrnfg=[0] * 8, blocks=[
        Block('AI', {'z': 9}),
    ])])
    text = emit(deck)
    lines = text.splitlines()
    assert lines[0] == 'END'  # OPEN block always ends with a literal END, even if empty
    assert lines[1] == ' &ai'
    assert lines[2] == 'z=9,'
    assert lines[3] == ' /'


def test_open_lines_and_end_marker():
    deck = Deck(open=[
        OpenLine(unit=10, file='./CFPTBL', format='binary', status='old'),
        OpenLine(unit=3, file='f.bas', status='old'),
    ], passes=[])
    text = emit(deck)
    lines = text.splitlines()
    assert lines[0] == 'OPEN UNIT=10 FILE=./CFPTBL BINARY STATUS=OLD'
    assert lines[1] == 'OPEN UNIT=3 FILE=f.bas STATUS=OLD'
    assert lines[2] == 'END'


def test_deck_ends_with_trailing_blank_line():
    deck = Deck(open=[], passes=[Pass(title='t', nrnfg=[0] * 8, blocks=[
        Block('RS', {'pthr': -0.001}),
    ])])
    text = emit(deck)
    assert text.endswith(' /\n\n')


def test_payload_lines_pass_through_verbatim_after_terminator():
    deck = Deck(open=[], passes=[Pass(title='t', nrnfg=[0] * 8, blocks=[
        Block('BASVC', {'idprnt': 0, 'iunit': '5'},
              payload=Payload(kind='vectors', lines=[' 1.000000  0.000000', ' )'])),
    ])])
    text = emit(deck)
    lines = text.splitlines()
    basvc = lines.index(' &basvc')
    assert lines[basvc:basvc + 5] == [
        ' &basvc', 'idprnt=0,', 'iunit=5,', ' /', ' 1.000000  0.000000',
    ]
    assert lines[basvc + 5] == ' )'


def test_no_payload_is_unchanged():
    deck = Deck(open=[], passes=[Pass(title='t', nrnfg=[0] * 8, blocks=[
        Block('AI', {'z': 9}),
    ])])
    text = emit(deck)
    assert text == 'END\n &ai\nz=9,\n /\n\n'


def test_end_to_end_matches_frozen_reference(atinputs_dir, samples_dir, reference_dir):
    for name in ('f', 'fpt'):
        path = str(atinputs_dir / f'{name}.inp')
        data = validate(parse_file(path), path)
        deck = build(data, basis_dir=str(samples_dir))
        generated = emit(deck)
        expected = (reference_dir / f'{name}.deck').read_text()
        assert generated == expected


def test_rs_nrnfg_emits_a_new_line_when_present():
    # Additive: the new key adds exactly one 'nrnfg=N,' line
    # after 'rule=', it does not alter anything already there.
    deck = Deck(open=[], passes=[Pass(title='t', nrnfg=[0] * 8, blocks=[
        Block('RS', {'pthr': -0.001, 'rule': 2, 'nrnfg': 1}),
    ])])
    text = emit(deck)
    lines = text.splitlines()
    rs = lines.index(' &rs')
    assert lines[rs + 1:rs + 4] == ['pthr=-0.001,', 'rule=2,', 'nrnfg=1,']
