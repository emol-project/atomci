import pytest

from ..emit import emit
from ..lint import lint
from ..parser import parse
from ..raw import build_raw_blocks, merge_into_deck
from ..reverse import convert, parse_stdin
from ..schema import validate
from ..sugar import build


def test_boron_stdin_is_single_pass(samples_dir):
    _cfptable, _open, passes = parse_stdin((samples_dir / 'boron.stdin').read_text())
    assert len(passes) == 1


def test_boron_stdin_block_groups_in_order(samples_dir):
    _cfptable, _open, passes = parse_stdin((samples_dir / 'boron.stdin').read_text())
    assert [b['group'] for b in passes[0]] == [
        'CNTL', 'AI', 'WF', 'TR', 'BASVC', 'EX', 'CI', 'RS']


def test_boron_stdin_open_header(samples_dir):
    cfptable, files_open, _passes = parse_stdin((samples_dir / 'boron.stdin').read_text())
    assert cfptable == './CFPTBL'
    assert files_open == [{'unit': 7, 'file': 'boron.time', 'format': '', 'status': ''}]


def test_boron_stdin_tr_mpob_continuation_lines_reconstruct(samples_dir):
    # &TR's MPOB spans several continuation lines with no repeated 'MPOB='
    # -- this is the generic KEY=VALUE/bare-token parsing exercising itself,
    # not TR-specific code.
    _cfptable, _open, passes = parse_stdin((samples_dir / 'boron.stdin').read_text())
    tr = next(b for b in passes[0] if b['group'] == 'TR')
    assert tr['params']['mpob'] == [
        '3', '4', '5', '6', '7', '8', '1', '2',
        '2', '3', '4', '5', '6', '7', '1',
        '1', '2', '3', '4', '5', '6',
        '1', '2', '3', '4', '5',
        '1', '2', '3', '4',
        '1', '2', '3',
        '1', '2',
    ]


def test_boron_stdin_iunit5_groups_get_a_payload(samples_dir):
    _cfptable, _open, passes = parse_stdin((samples_dir / 'boron.stdin').read_text())
    by_group = {b['group']: b for b in passes[0]}
    assert by_group['AI']['payload_lines'] is not None
    assert by_group['WF']['payload_lines'] is not None
    assert by_group['BASVC']['payload_lines'] is not None
    assert by_group['TR']['payload_lines'] is None
    assert by_group['CI']['payload_lines'] is None


def test_convert_boron_produces_schema_valid_inp(tmp_path, samples_dir):
    inp_path = convert(str(samples_dir / 'boron.stdin'), str(tmp_path))
    data = validate(parse(open(inp_path).read(), inp_path), inp_path)
    assert len(data['raw']) == 8
    assert 'passes' not in data  # single pass: unchanged flat raw: form


def test_convert_boron_payload_matches_hand_written_sidecars(tmp_path, samples_dir, atinputs_dir):
    # Cross-check: the mechanically-converted payload
    # sidecars must carry the same card data as the hand-written boron.inp's
    # sidecars, even though the reverse converter names them differently
    # (kind-based, not group-based).
    inp_path = convert(str(samples_dir / 'boron.stdin'), str(tmp_path))
    data = validate(parse(open(inp_path).read(), inp_path), inp_path)
    blocks = build_raw_blocks(data['raw'], inp_path)

    hand_written = {
        'AI': (atinputs_dir / 'boron.basis.txt').read_text().splitlines(),
        'WF': (atinputs_dir / 'boron.csf.txt').read_text().splitlines(),
        'BASVC': (atinputs_dir / 'boron.basvc.txt').read_text().splitlines(),
    }
    for group, expected_lines in hand_written.items():
        block = next(b for b in blocks if b.group == group)
        assert block.payload.lines == expected_lines


def test_convert_boron_nsdim700_differs_from_boron_only_in_nsdim(tmp_path, samples_dir):
    boron_path = convert(str(samples_dir / 'boron.stdin'), str(tmp_path / 'a'))
    n700_path = convert(str(samples_dir / 'boron_nsdim700.stdin'), str(tmp_path / 'b'))
    boron_data = validate(parse(open(boron_path).read(), boron_path), boron_path)
    n700_data = validate(parse(open(n700_path).read(), n700_path), n700_path)

    boron_ci = next(b for b in boron_data['raw'] if b['group'] == 'CI')['params']
    n700_ci = next(b for b in n700_data['raw'] if b['group'] == 'CI')['params']
    diffs = {k for k in boron_ci if boron_ci[k] != n700_ci.get(k)}
    assert diffs == {'nsdim'}
    assert boron_ci['nsdim'] == '100'
    assert n700_ci['nsdim'] == '700'


# --- multi-pass (f.stdin) ---------------------------------------------------

def test_f_stdin_is_three_pass(samples_dir):
    _cfptable, _open, passes = parse_stdin((samples_dir / 'f.stdin').read_text())
    assert len(passes) == 3


def test_f_stdin_pass_boundaries_are_cntl_groups(samples_dir):
    _cfptable, _open, passes = parse_stdin((samples_dir / 'f.stdin').read_text())
    assert [p[0]['group'] for p in passes] == ['CNTL', 'CNTL', 'CNTL']
    assert [[b['group'] for b in p] for p in passes] == [
        ['CNTL', 'AI', 'MC', 'WF', 'TR', 'GET', 'CI', 'RS'],
        ['CNTL', 'TR', 'GET', 'CI', 'RS'],
        ['CNTL', 'RS'],
    ]


def test_f_stdin_pass_titles(samples_dir):
    _cfptable, _open, passes = parse_stdin((samples_dir / 'f.stdin').read_text())
    titles = [next(b for b in p if b['group'] == 'CNTL')['params']['title'][0]
              for p in passes]
    assert titles == ["' F DOUBLET P '", "' F DOUBLET P (NO 1) '", "' F DOUBLET P (NO 1) '"]


def test_convert_f_produces_passes_not_flat_raw(tmp_path, samples_dir):
    inp_path = convert(str(samples_dir / 'f.stdin'), str(tmp_path))
    data = validate(parse(open(inp_path).read(), inp_path), inp_path)
    assert 'raw' not in data  # multi-pass: passes:, not a flat top-level raw:
    assert len(data['passes']) == 3
    assert [p['ctrl'] for p in data['passes']] == [{}, {}, {}]


def test_convert_f_pass2_ind_record_differs_from_pass1(tmp_path, samples_dir):
    # &GET's IND record number is 1 in pass 1 (original SCF orbitals) and 2
    # in pass 2 (natural orbitals saved by pass 1's CIMAIN) -- the one
    # substantive difference between the two &TR/&GET restatements.
    inp_path = convert(str(samples_dir / 'f.stdin'), str(tmp_path))
    data = validate(parse(open(inp_path).read(), inp_path), inp_path)
    get1 = next(b for b in data['passes'][0]['raw'] if b['group'] == 'GET')
    get2 = next(b for b in data['passes'][1]['raw'] if b['group'] == 'GET')
    assert get1['params']['ind'].values[0] == '1'
    assert get2['params']['ind'].values[0] == '2'


def test_convert_f_lints_clean(tmp_path, samples_dir):
    inp_path = convert(str(samples_dir / 'f.stdin'), str(tmp_path))
    data = validate(parse(open(inp_path).read(), inp_path), inp_path)
    findings = lint(data, inp_path=inp_path)
    errors = [f.message for f in findings if f.severity == 'error']
    assert errors == []


# --- full round-trip, all four samples --------------------------------------
#
# Reverse-converted .inp/sidecars are written to tmp_path at test time and
# never committed (this project has untracked generated
# files three times already; a fourth instance would repeat a known mistake
# rather than avoid it). Golden-energy verification (running the resulting
# deck through the real compiled `atomci`) is done manually/in the full
# regression pass, not here -- no other test in this suite shells out to a
# compiled binary, and this one shouldn't be the first to require one just
# to run `pytest`.

@pytest.mark.parametrize('stem', ['f', 'fpt', 'boron', 'boron_nsdim700'])
def test_stdin_round_trips_to_a_valid_deck(tmp_path, samples_dir, stem):
    inp_path = convert(str(samples_dir / f'{stem}.stdin'), str(tmp_path))
    data = validate(parse(open(inp_path).read(), inp_path), inp_path)

    findings = lint(data, inp_path=inp_path)
    assert [f.message for f in findings if f.severity == 'error'] == []

    basis_dir = str(samples_dir) if 'basis' in data['files'] else '.'
    deck = build(data, basis_dir=basis_dir)
    merge_into_deck(deck, data, inp_path)
    text = emit(deck, style='native')
    assert text.strip()  # produced *something* -- byte-identity isn't the
                          # target here; golden energy is.
