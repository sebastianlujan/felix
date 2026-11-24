// Commits to a secret with a salt: the public output is the Pedersen hash of both.
fn main(secret: Field, salt: Field) -> pub Field {
    std::hash::pedersen_hash([secret, salt])
}

#[test]
fn the_commitment_depends_on_the_secret() {
    assert(main(42, 7) != main(43, 7));
}
