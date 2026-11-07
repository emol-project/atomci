"""Raw NAMELIST blocks + payload sidecars -> IR. Deliberately separate
from sugar.py: this module never
derives anything from `atom`/`orbital`/`reference` -- it just states what
the author wrote, plus (for a payload) copies a sidecar file through
verbatim. No sugar derivation logic lives here or changes because of it.
"""

import os

from .ir import Block, Payload
from .schema import pass_entries


class RawError(Exception):
    pass


def _resolve_sidecar_dir(inp_path, filename):
    """Where a sidecar payload file actually lives: cwd first (matches the
    golden-run workflow, where sidecars are copied alongside the deck),
    then the .inp's own directory (matches samples/atinputs/boron.inp
    finding boron.basis.txt next to it without copying). Mirrors
    __main__._resolve_basis_dir's search order."""
    inp_dir = os.path.dirname(os.path.abspath(inp_path)) or '.'
    for candidate in ('.', inp_dir):
        if os.path.isfile(os.path.join(candidate, filename)):
            return candidate
    return '.'


def _read_payload(payload_data, inp_path):
    kind = payload_data['kind']
    source = payload_data.get('source', 'file')
    if source != 'file':
        raise RawError(f"payload source '{source}' is not supported (only 'file' is)")
    path = payload_data.get('path')
    if not path:
        raise RawError(f"payload kind '{kind}' has source: file but no path")
    sidecar_dir = _resolve_sidecar_dir(inp_path, path)
    full_path = os.path.join(sidecar_dir, path)
    try:
        with open(full_path, encoding='utf-8') as f:
            text = f.read()
    except OSError as e:
        raise RawError(f"could not read payload sidecar '{path}': {e}")
    return Payload(kind=kind, lines=text.splitlines())


def build_raw_blocks(raw_entries, inp_path):
    """A validated raw: list (top-level `data['raw']`, or one pass's own
    `raw` under `data['passes']`) -> [Block]. inp_path: the .inp
    file's own path, used to resolve payload sidecar paths."""
    blocks = []
    for entry in raw_entries:
        payload = None
        if entry.get('payload') is not None:
            payload = _read_payload(entry['payload'], inp_path)
        blocks.append(Block(entry['group'].upper(), entry.get('params', {}), payload))
    return blocks


def merge_into_deck(deck, data, inp_path):
    """Merge every pass's raw blocks (top-level `raw`, or each entry's own
    `raw` under `passes`) into an already sugar-built Deck, in place, one
    pass at a time -- `deck.passes` and `pass_entries(data)` are always the
    same length and in the same order, since sugar.build() derives its
    passes from the identical fallback."""
    for i, entry in enumerate(pass_entries(data)):
        raw_blocks = entry.get('raw', [])
        if raw_blocks:
            deck.passes[i].blocks = merge(
                deck.passes[i].blocks, build_raw_blocks(raw_blocks, inp_path))


def merge(blocks, raw_blocks):
    """Raw wins: a raw block replaces the sugar block of
    the same group name (case-insensitive) in place; a raw block naming a
    group sugar didn't build (e.g. &BASVC) is appended in raw's own list
    order. One rule, no per-group-name special-casing -- it's what lets a
    fully-raw boron.inp (sugar contributes only &CNTL, itself raw-replaced)
    end up in the right order (&CNTL, &AI, &WF, &TR, &BASVC, &EX, &CI,
    &RS) purely from the order raw.py's blocks were listed in the .inp."""
    result = list(blocks)
    index_by_group = {b.group.upper(): i for i, b in enumerate(result)}
    for rb in raw_blocks:
        key = rb.group.upper()
        if key in index_by_group:
            result[index_by_group[key]] = rb
        else:
            index_by_group[key] = len(result)
            result.append(rb)
    return result
