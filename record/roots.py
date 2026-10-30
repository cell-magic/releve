# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""The published roots: their format and check are the core's (record/Roots.plie); this is
the one thing about them not yet done.

Renewal (RFC 4998, 5.2). A time-stamp stays evidence while its algorithms hold. Before
SHA-256 or the authority's signature weakens, each entry's token is to be covered by a new
token, over a hash of the old one under a stronger algorithm; the new token then vouches for
the old, and the chain of entries for the roots. An entry for it takes the form
{cycle, renews: <entry hash>, token_hash, prev_entry_hash}. The interface is fixed here so
that the list's shape need not change; nothing renews yet."""


def renew(entries, entry_hash, token, algorithm):
    """The list with an entry renewing the entry named by `entry_hash`, under `algorithm`."""
    raise NotImplementedError("renewal under RFC 4998 is not done yet; the shape of the list leaves room for it")
