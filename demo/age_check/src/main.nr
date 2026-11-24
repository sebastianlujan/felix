// Proves that a private age is at least a public minimum, without revealing the age.
fn main(age: u8, minimum: pub u8) {
    assert(age >= minimum);
}

#[test]
fn old_enough() {
    main(30, 18);
}

#[test]
fn exactly_the_minimum() {
    main(18, 18);
}

#[test(should_fail)]
fn too_young() {
    main(17, 18);
}
