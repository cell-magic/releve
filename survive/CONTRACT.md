# The survive record

Whether the C2PA, EXIF and IPTC markers of a page's images survive its delivery.
One JSON object, its keys sorted (`python -m survive URL --contact URL`).

Field names are frozen, in snake case. Where the contract named a field without
saying what it holds, relevé 0.10.1 defines it here; each such definition is
marked **(†)** and stands until the maintainer confirms or replaces it.

## Fields

| field | holds |
|---|---|
| `run_id` | **(†)** SHA-256 of the scope's canonical bytes. The same surface measured the same way has the same `run_id`, so two runs of one fixture agree on it. |
| `observed_at` | When the surface was observed, UTC, `YYYY-MM-DDTHH:MM:SSZ`. The one field two runs may differ in, and outside the body. |
| `scope.url` | The page observed. |
| `scope.probes[]` | **(†)** Every address probe 2 asked for, sorted: all that was fetched beyond the surface. |
| `scope.viewport`, `dpr`, `reduced_motion`, `locale`, `tz`, `ua` | How the surface was rendered: `{width 1280, height 800}`, `1`, `"reduce"`, `"en-US"`, `"UTC"`, and the robot's own user agent, which names its operator. |
| `scope.settle` | `{idle 500, quiet 1000, cap 15000, capped, active_pollers}`, on every run (settle.py). |
| `scope.pages` | **(†)** The number of pages observed: 1. |
| `assets[].url` | The image's absolute address, as the surface used it. |
| `assets[].role` | **(†)** Where the surface uses it: `img` (an image's current source) or `og:image` (the page's share card). |
| `assets[].classes` | `{c2pa, exif, iptc}`, each **(†)** `{delivered, origin, state}`: the bytes of that class in the delivered file; in the origin file (`null` when the origin was not seen); and the class's state. |
| `assets[].state` | The asset's state: its classes' first by rank (below). |
| `assets[].transformer` | The surface transformer: what stands at the address the surface uses, never the host behind it. `null` when none is known. **(†)** Named from edge headers (`cf-polished` cloudflare-polish, `cf-resized` cloudflare-images, `x-akamai-transformed` akamai-image-manager, `x-fastly-imageopto-api` fastly-image-optimizer) or from wrappers (`/_next/image` next-image, `/cdn-cgi/image/` cloudflare-images, imgix's parameters imgix). An edge header names it before a wrapper does: the header is what last touched the bytes. |
| `assets[].vector` | **(†)** How the transformer was known: `header`, `wrapper`, or `origin` when none stands between. |
| `probe2.attempted` | **(†)** How many probes were sent or refused (one per distinct target). |
| `probe2.status` | **(†)** Each probe's outcome, sorted: the HTTP status as text (`"200"`, `"403"`), or `timeout`, `error`, `refused` (the address guard), `robots` (robots.txt). |
| `probe2.still_transformed` | **(†)** How many probes came back with an edge-modification header. |
| `warnings[]` | Sentences, sorted, each once: what was not read or not sent, and why. |
| `root` | SHA-256 of the body's RFC 8785 bytes. **(†)** The body is the record without `observed_at`, `root` and `signed`. |
| `signed` | `false`: no signing key is configured, and none is needed to give the root. A run never waits on a key. |

## States

Per class, from its delivered and origin sizes:

| state | when |
|---|---|
| **(†)** `PRESENT` | The delivered bytes carry the class. (The fourth state, which the contract does not name.) |
| `STRIPPED_AT_DELIVERY` | The delivered bytes lack it; the origin, reached by probe 2, has it. |
| `ABSENT_AT_ORIGIN` | The delivered bytes lack it, and so does the origin. Only when a probe-2 response arrived, succeeded (200) and carried no edge-modification header. |
| `ORIGIN_UNOBSERVABLE` | The delivered bytes lack it, and the origin was not seen: no transformer stood between, so no probe was due; or the probe was refused, failed, timed out, or came back still transformed. |

Rank, for an asset's state and for the fix list: `STRIPPED_AT_DELIVERY`,
`ABSENT_AT_ORIGIN`, `ORIGIN_UNOBSERVABLE`, `PRESENT`.

## Order

Assets are sorted by normalised absolute address (scheme and host in lowercase, no
default port, no fragment, `/` for an empty path), then **(†)** by state rank, then by
role. The contract names the second key "state then class"; an asset holds all three
classes, so what separates two assets of one address is their role.

## Probe 2

Sent once per distinct target, only when a transformer is known **and** **(†)** some
class is missing from the delivered bytes (a file that kept everything needs no origin).
The wrapper is stripped; an absolute `url=` is URL-decoded. The request carries
`Cache-Control: no-transform` and **(†)** `Accept: */*`, which names no image format a
transformer could transcode to. One hop, no redirect followed, 5 s.

An absolute target is reached over `http` or `https` only, and never at 127/8, 10/8,
172.16/12, 192.168/16, 169.254/16, `::1` or fc00::/7, nor **(†)** 0/8 and `::`, which
reach the machine itself. The address checked is the one connected to. **(†)** A
relative target is the asset's own origin, already fetched by the browser, and is not
put to this guard. robots.txt is asked before any probe.

## Fix list

`record.fixlist(doc, markup)`: ranks only, no prose. Classes stripped at delivery,
then absent at origin, then the markup findings given; classes whose origin is
unobservable are listed apart, as unmeasured, and never ranked as a fault.
