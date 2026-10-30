# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""The RADAR record, open side: its format and schema, its readings, its chain, the month's
Merkle tree, the published roots, the time-stamp client, the beacon, and the verifier.

What is judged or checked is written once in plié (record/*.plie) and runs as `releve core`
(Haskell) or in record/verifier.html (JavaScript). This package is the edge around it: it
reads files and the network, calls OpenSSL and the beacon, and hands JSON to the core."""
SCHEMA = "releve-record/2"
