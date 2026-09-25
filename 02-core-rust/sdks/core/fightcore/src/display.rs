//! Text that is a pure function of a contract code. It lives in the kernel because both feature
//! SDKs show codes to people: `fightevents` a result method, `fightslip` a validation error.

/// `split_decision` reads as a database column; `Split decision` reads as a result.
pub fn humanise(raw: &str) -> String {
    let spaced = raw.replace('_', " ");
    let mut chars = spaced.chars();
    match chars.next() {
        Some(first) => first.to_uppercase().collect::<String>() + chars.as_str(),
        None => String::new(),
    }
}
