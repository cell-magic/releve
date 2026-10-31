// SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
// SPDX-License-Identifier: EUPL-1.2
//! Whether a signature is drand quicknet's over a round (scheme bls-unchained-g1-rfc9380):
//! the signature is a point of G1, the message SHA-256 of the round as 8 big-endian bytes,
//! hashed to G1 under RFC 9380, and e(signature, g2) = e(H(message), public key).
//! Pure: bytes in, a verdict out. Built for the command line (src/main.rs) and for the
//! browser (the two exports below, over WebAssembly's linear memory, nothing else).
use bls12_381::hash_to_curve::{ExpandMsgXmd, HashToCurve};
use bls12_381::{multi_miller_loop, G1Affine, G1Projective, G2Affine, G2Prepared, Gt};
use sha2::{Digest, Sha256};

/// The League of Entropy's quicknet key (chain 52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971).
pub const QUICKNET_KEY: &str = "83cf0f2896adee7eb8b5f01fcad3912212c437e0073e911fb90022d3e760183c8c4b450b6a0a6c3ac6a5776a2d1064510d1fec758c921cc22b0e17e63aaf4bcb5ed66304de9cf809bd274ca73bab4af5a6e9c76a4bc09e76eae8991ef5ece45a";
const DST: &[u8] = b"BLS_SIG_BLS12381G1_XMD:SHA-256_SSWU_RO_NUL_";

/// Some(true) when the signature holds, Some(false) when it does not, None when the bytes are not a signature and a key.
pub fn verify(round: u64, signature: &[u8], key: &[u8]) -> Option<bool> {
    let sig: [u8; 48] = signature.try_into().ok()?;
    let pk: [u8; 96] = key.try_into().ok()?;
    let sig = Option::<G1Affine>::from(G1Affine::from_compressed(&sig))?;
    let pk = Option::<G2Affine>::from(G2Affine::from_compressed(&pk))?;
    let message = Sha256::digest(&round.to_be_bytes());
    let h = G1Affine::from(<G1Projective as HashToCurve<ExpandMsgXmd<Sha256>>>::hash_to_curve(&message[..], DST));
    let g2 = G2Prepared::from(-G2Affine::generator());
    let ok = multi_miller_loop(&[(&sig, &g2), (&h, &G2Prepared::from(pk))]).final_exponentiation() == Gt::identity();
    Some(ok)
}

pub fn unhex(s: &str) -> Option<Vec<u8>> {
    if s.len() % 2 != 0 { return None; }
    (0..s.len()).step_by(2).map(|i| u8::from_str_radix(s.get(i..i + 2)?, 16).ok()).collect()
}

/// The browser's door: a buffer the page writes a signature into, and the check of it against quicknet's key.
static mut BUFFER: [u8; 64] = [0; 64];

#[no_mangle]
pub extern "C" fn buffer() -> *mut u8 {
    core::ptr::addr_of_mut!(BUFFER) as *mut u8
}

/// 1 when the signature in the buffer (its first `length` bytes) is quicknet's over `round`, 0 when not, -1 when it is no signature.
#[no_mangle]
pub extern "C" fn quicknet(round: u64, length: u32) -> i32 {
    let length = (length as usize).min(64);
    let signature = unsafe { core::slice::from_raw_parts(core::ptr::addr_of!(BUFFER) as *const u8, length) };
    match verify(round, signature, &unhex(QUICKNET_KEY).expect("the key is hex")) {
        Some(true) => 1,
        Some(false) => 0,
        None => -1,
    }
}
