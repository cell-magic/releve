# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""Runtime: orders events through a kernel, keeps a hash chain, drops content.

Chain:  h_0 = H("genesis" | protocol | mug(config) | mug(state_0))
        h_n = H(h_{n-1} | mug(event_n) | mug(state_n))
Snapshots of state are kept every `every` events; events are kept only since the last
snapshot, so nothing persists except structure, the chain and the receipt.
"""
from hashlib import sha256
from . import kcenter as KC
from . import noun as N


def _h(*parts: str) -> str:
    return sha256("|".join(parts).encode()).hexdigest()


def genesis_head(cfg, state0, protocol=KC.PROTOCOL):
    return _h("genesis", protocol, N.mug(cfg), N.mug(state0))


def step_head(prev, event, state):
    return _h(prev, N.mug(event), N.mug(state))


class Runtime:
    def __init__(self, cfg, state0=None, every=64, kernel=KC, protocol=KC.PROTOCOL):
        self.cfg, self.kernel, self.protocol = cfg, kernel, protocol
        self.state = state0 if state0 is not None else kernel.genesis()
        self.head = genesis_head(cfg, self.state, protocol)
        self.n, self.every = 0, every
        self.snapshots = [(0, self.state, self.head)]
        self.window, self.log = [], []

    def poke(self, event):
        effects, self.state = self.kernel.poke(self.cfg, self.state, event)
        self.n += 1
        self.head = step_head(self.head, event, self.state)
        self.window.append(event)
        if self.n % self.every == 0:
            self.snapshots.append((self.n, self.state, self.head))
            self.window = []
        for e in effects:
            self.log.append((self.n, e))
        return effects

    def receipt(self):
        decisions, cov = [], None
        for n, eff in self.log:
            kind = N.uncord(eff[0]) if N.is_cell(eff) else N.uncord(eff)
            if kind == "pick":
                k, ref = eff[1]
                decisions.append(dict(n=n, decision="pick", order=k, ref=ref))
            elif kind == "coverage":
                cov = (N.a2s(eff[1][0]), eff[1][1])
        prm = KC.params(self.cfg)
        rec = dict(engine=self.protocol, budget=prm["budget"], config=N.mug(self.cfg),
                   genesis=genesis_head(self.cfg, self.snapshots[0][1], self.protocol),
                   head=self.head, events=self.n, state=N.mug(self.state), decisions=decisions)
        if cov is not None:
            rec["coverage"] = KC.coverage(cov[0], cov[1], len(decisions), prm["stop_r2"])
        return rec


def replay(cfg, state0, events, kernel=KC, protocol=KC.PROTOCOL):
    rt = Runtime(cfg, state0, every=10**12, kernel=kernel, protocol=protocol)
    effs = [rt.poke(ev) for ev in events]
    return rt.state, rt.head, effs


def verify(receipt, cfg, state0, events, kernel=KC, protocol=KC.PROTOCOL):
    """Valid iff the configuration matches and replaying the events reproduces head and state."""
    if N.mug(cfg) != receipt["config"] or receipt.get("engine") != protocol:
        return False
    state, head, _ = replay(cfg, state0, events, kernel, protocol)
    return head == receipt["head"] and N.mug(state) == receipt["state"]


def verify_segment(cfg, snapshot_state, snapshot_head, events, expected_head, kernel=KC):
    head, state = snapshot_head, snapshot_state
    for ev in events:
        _, state = kernel.poke(cfg, state, ev)
        head = step_head(head, ev, state)
    return head == expected_head
