// Knowledge of a square root of `y`, bound to a recipient.
// `recipient` is the claimer's EVM address as a field element.
fn main(x: Field, y: pub Field, recipient: pub Field) {
    assert(x * x == y);
    assert(recipient != 0);
}

#[test]
fn accepts_square_root() {
    main(3, 9, 0xc0ffe);
}

#[test(should_fail)]
fn rejects_wrong_root() {
    main(4, 9, 0xc0ffe);
}

#[test(should_fail)]
fn rejects_zero_recipient() {
    main(3, 9, 0);
}
