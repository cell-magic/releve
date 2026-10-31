// SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
// SPDX-License-Identifier: EUPL-1.2
//! releve-bls ROUND SIGNATURE_HEX: "valid" (exit 0), "invalid" (exit 1), or "not a signature" (exit 2),
//! against drand quicknet's key. record/beacon.py calls it.
use releve_bls::{unhex, verify, QUICKNET_KEY};

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let (round, sig) = match (args.get(1).and_then(|r| r.parse::<u64>().ok()), args.get(2).and_then(|s| unhex(s))) {
        (Some(r), Some(s)) if args.len() == 3 => (r, s),
        _ => {
            eprintln!("releve-bls ROUND SIGNATURE_HEX");
            std::process::exit(2);
        }
    };
    match verify(round, &sig, &unhex(QUICKNET_KEY).expect("the key is hex")) {
        Some(true) => println!("valid"),
        Some(false) => { println!("invalid"); std::process::exit(1) }
        None => { println!("not a signature"); std::process::exit(2) }
    }
}
