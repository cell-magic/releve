# Boundary

relevé is the open half of the Bureau's instrument. What it does, anyone can run, read
and check; what the Bureau does with it as a service is kept apart.

**Open, here, under EUPL-1.2:**
- verification: observing a surface, and the rules that judge it;
- the record format (`survive/CONTRACT.md`, and the record the kernel reads);
- hashing: canonical bytes and the root over them;
- the verifier;
- the licence itself, EUPL-1.2, for all of the above.

**Closed, not here:**
- scheduling: when and how often a surface is observed;
- diffing: comparing records over time;
- alerting: telling anyone that something changed;
- member management: who subscribes, and to what;
- series storage: keeping records over time.

The open half must remain independently verifiable without the closed half. A record,
its root and the code that made them are enough to check it: anyone with relevé and a
record can run the same surface again, get the same body, and compute the same root,
without any service, account, key or schedule of the Bureau's. Nothing open may depend
on anything closed, and no closed part may be needed to read, recompute or verify what
the open part produces.
