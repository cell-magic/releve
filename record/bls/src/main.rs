// SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
// SPDX-License-Identifier: EUPL-1.2
//! releve-bls ROUND SIGNATURE_HEX [KEY_HEX]: "valid" (exit 0), "invalid" (exit 1), or "not a signature"
//! (exit 2), against drand quicknet's key, or the key given (the tests' own beacon). record/beacon.py calls it.
use releve_bls::{unhex, verify, QUICKNET_KEY};

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let key = args.get(3).map(String::as_str).unwrap_or(QUICKNET_KEY);
    let (round, sig, key) = match (args.get(1).and_then(|r| r.parse::<u64>().ok()), args.get(2).and_then(|s| unhex(s)), unhex(key)) {
        (Some(r), Some(s), Some(k)) if args.len() == 3 || args.len() == 4 => (r, s, k),
        _ => {
            eprintln!("releve-bls ROUND SIGNATURE_HEX [KEY_HEX]");
            std::process::exit(2);
        }
    };
    match verify(round, &sig, &key) {
        Some(true) => println!("valid"),
        Some(false) => { println!("invalid"); std::process::exit(1) }
        None => { println!("not a signature"); std::process::exit(2) }
    }
}
