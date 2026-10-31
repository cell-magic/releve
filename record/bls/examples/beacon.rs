// SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
// SPDX-License-Identifier: EUPL-1.2
//! The tests' own beacon, on quicknet's scheme and schedule, under a key of the tests' own:
//! `beacon SECRET` prints the public key; `beacon SECRET ROUND` prints the round's signature.
//! For tests only, as their own time-stamping authority is (tests/authority.py); it is not
//! built into releve-bls or the page, and nothing it signs is quicknet's.
use bls12_381::hash_to_curve::{ExpandMsgXmd, HashToCurve};
use bls12_381::{G1Affine, G1Projective, G2Affine, Scalar};
use releve_bls::DST;
use sha2::{Digest, Sha256};

fn hex(b: &[u8]) -> String {
    b.iter().map(|x| format!("{x:02x}")).collect()
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let secret = match args.get(1).and_then(|s| s.parse::<u64>().ok()) {
        Some(s) if s > 0 => Scalar::from(s),
        _ => {
            eprintln!("beacon SECRET [ROUND]");
            std::process::exit(2);
        }
    };
    match args.get(2).and_then(|r| r.parse::<u64>().ok()) {
        None => println!("{}", hex(&G2Affine::from(G2Affine::generator() * secret).to_compressed())),
        Some(round) => {
            let message = Sha256::digest(&round.to_be_bytes());
            let h = <G1Projective as HashToCurve<ExpandMsgXmd<Sha256>>>::hash_to_curve(&message[..], DST);
            println!("{}", hex(&G1Affine::from(h * secret).to_compressed()));
        }
    }
}
