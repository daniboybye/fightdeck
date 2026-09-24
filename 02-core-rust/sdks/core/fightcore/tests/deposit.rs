//! The deposit rules both hosts now read instead of writing their own.

use fightcore::deposit::quote;
use fightcore::{format, parse};

#[test]
fn wallet_fee_rounds_half_up_and_is_charged_on_top() {
    let quote = quote("10.50", "wallet", parse("500.00"));
    assert_eq!(format(quote.fee), "0.11");
    assert_eq!(format(quote.total), "10.61");
    assert_eq!(format(quote.new_balance), "510.50");
}

#[test]
fn card_and_bank_transfer_are_free() {
    assert_eq!(format(quote("100", "card", parse("0")).fee), "0.00");
    assert_eq!(format(quote("100", "bank", parse("0")).fee), "0.00");
}

#[test]
fn limits_include_both_ends() {
    assert_eq!(quote("10", "card", parse("0")).validation_message, None);
    assert_eq!(quote("2000", "card", parse("0")).validation_message, None);
    assert_eq!(quote("9.99", "card", parse("0")).validation_message, Some("Minimum deposit is €10"));
    assert_eq!(
        quote("2000.01", "card", parse("0")).validation_message,
        Some("Maximum deposit is €2,000")
    );
}

#[test]
fn an_empty_field_is_not_an_error_but_cannot_be_confirmed() {
    let quote = quote("", "card", parse("500.00"));
    assert_eq!(quote.validation_message, None);
    assert!(!quote.can_confirm);
    assert_eq!(format(quote.new_balance), "500.00");
}

#[test]
fn text_that_is_not_a_number_deposits_nothing() {
    let quote = quote("12,5", "card", parse("0"));
    assert_eq!(format(quote.amount), "0.00");
    assert_eq!(quote.validation_message, Some("Minimum deposit is €10"));
}
