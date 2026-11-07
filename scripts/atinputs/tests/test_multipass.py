from ..parser import parse
from ..raw import merge_into_deck
from ..schema import validate
from ..sugar import build

_TWO_PASS = """
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
  frozen_core: 1S
  active: 2S, 2P
  outer: 11S, 10P, 6D, 5F
reference:
  - occ: 2S*2 2P*5
ctrl:
passes:
  -
    title: " pass one "
    ctrl:
      ai:  type: 2, idprnt: 0
      wf:  rule: 1, npflg: 0
      rs:  print: -0.001
  -
    title: " pass two "
    ctrl:
      rs:  print: -0.001
"""


def _validate(text):
    return validate(parse(text, 'x.inp'), 'x.inp')


def test_passes_absent_is_a_single_pass(atinputs_dir, samples_dir):
    # Absent/empty passes: -> exactly the
    # single-implicit-pass behavior from before multi-pass decks existed.
    # f.inp itself has no passes: key at all.
    path = str(atinputs_dir / 'f.inp')
    data = _validate(open(path).read())
    assert 'passes' not in data
    deck = build(data, basis_dir=str(samples_dir))
    assert len(deck.passes) == 1


def test_passes_produces_one_ir_pass_per_entry(samples_dir):
    data = _validate(_TWO_PASS)
    deck = build(data, basis_dir=str(samples_dir))
    assert len(deck.passes) == 2


def test_each_pass_gets_its_own_title_and_cntl(samples_dir):
    data = _validate(_TWO_PASS)
    deck = build(data, basis_dir=str(samples_dir))
    cntl1 = deck.passes[0].blocks[0]
    cntl2 = deck.passes[1].blocks[0]
    assert cntl1.group == cntl2.group == 'CNTL'
    assert cntl1.params['title'].value == ' pass one '
    assert cntl2.params['title'].value == ' pass two '


def test_no_inheritance_pass2_only_has_what_its_own_ctrl_states(samples_dir):
    # Pass 2's ctrl has only 'rs' -- it must not
    # pick up &AI/&WF from pass 1 in any form.
    data = _validate(_TWO_PASS)
    deck = build(data, basis_dir=str(samples_dir))
    groups_pass1 = [b.group for b in deck.passes[0].blocks]
    groups_pass2 = [b.group for b in deck.passes[1].blocks]
    assert groups_pass1 == ['CNTL', 'AI', 'WF', 'RS']
    assert groups_pass2 == ['CNTL', 'RS']


def test_nrnfg_differs_per_pass(samples_dir):
    data = _validate(_TWO_PASS)
    deck = build(data, basis_dir=str(samples_dir))
    cntl1 = deck.passes[0].blocks[0]
    cntl2 = deck.passes[1].blocks[0]
    # ai, wf, rs present in pass 1 -> CTRL_STEP_ORDER = (ai,mc,wf,tr,pt,ex,ci,rs)
    assert cntl1.params['nrnfg'].values == [1, 0, 1, 0, 0, 0, 0, 1]
    assert cntl2.params['nrnfg'].values == [0, 0, 0, 0, 0, 0, 0, 1]


def test_raw_and_sugar_both_work_within_a_pass(samples_dir):
    # A raw block inside one pass's own 'raw:'
    # replaces that pass's sugar-built block, the same raw-wins merge
    # already used for the single-pass case -- just applied per pass.
    text = _TWO_PASS.replace(
        '      rs:  print: -0.001\n  -\n    title: " pass two "',
        '      rs:  print: -0.001\n'
        '    raw:\n'
        '      -\n'
        '        group: AI\n'
        '        params:\n'
        '          z: 99.0D0\n'
        '  -\n    title: " pass two "',
    )
    data = _validate(text)
    deck = build(data, basis_dir=str(samples_dir))
    merge_into_deck(deck, data, 'x.inp')
    ai = next(b for b in deck.passes[0].blocks if b.group == 'AI')
    assert ai.params == {'z': '99.0D0'}  # raw replaced the sugar-built &AI entirely
    # pass 2 has no raw: at all -- merge_into_deck must leave it untouched.
    assert [b.group for b in deck.passes[1].blocks] == ['CNTL', 'RS']
