//! Deposit rules: the limits, the fee each method charges and how that fee rounds. They were
//! written four times — once per deposit screen, in two languages — before they moved here.

use crate::money;
use rust_decimal::Decimal;

pub struct Method {
    pub id: &'static str,
    pub title: &'static str,
    pub fee_note: &'static str,
    pub fee_rate: &'static str,
}

pub const METHODS: [Method; 3] = [
    Method { id: "card", title: "Card", fee_note: "Instant · 0% fee", fee_rate: "0" },
    Method { id: "bank", title: "Bank transfer", fee_note: "1–2 days · 0% fee", fee_rate: "0" },
    Method { id: "wallet", title: "Wallet", fee_note: "Instant · 1% fee", fee_rate: "0.01" },
];

/// The amounts offered as one-tap chips under the field.
pub const PRESETS: [&str; 4] = ["10", "25", "50", "100"];

pub const MIN_DEPOSIT: &str = "10.00";
pub const MAX_DEPOSIT: &str = "2000.00";

pub struct Quote {
    pub amount: Decimal,
    pub fee: Decimal,
    /// The fee is charged on top of the deposit, not taken out of it.
    pub total: Decimal,
    pub new_balance: Decimal,
    /// None while the field is empty: nothing typed is not yet a mistake.
    pub validation_message: Option<&'static str>,
    pub can_confirm: bool,
}

/// The amount is rounded before anything else reads it, so the limits judge — and the fee is
/// charged on — the figure that will actually reach the balance.
pub fn quote(amount_text: &str, method_id: &str, balance: Decimal) -> Quote {
    let amount = money::money(money::try_parse(amount_text).unwrap_or(Decimal::ZERO));
    let rate = METHODS
        .iter()
        .find(|method| method.id == method_id)
        .map_or(Decimal::ZERO, |method| money::parse_exact(method.fee_rate));
    let fee = money::money(amount * rate);
    let validation_message = if amount_text.is_empty() {
        None
    } else if amount < money::parse_exact(MIN_DEPOSIT) {
        Some("Minimum deposit is €10")
    } else if amount > money::parse_exact(MAX_DEPOSIT) {
        Some("Maximum deposit is €2,000")
    } else {
        None
    };
    Quote {
        amount,
        fee,
        total: amount + fee,
        new_balance: balance + amount,
        can_confirm: !amount_text.is_empty() && validation_message.is_none(),
        validation_message,
    }
}

