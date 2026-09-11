//! Presentation strings that are pure functions of the data. Every one of these existed
//! twice — once in `DisplayFormatting.swift`, once inline in `FightDeckScreens.kt`.

/// `split_decision` reads as a database column; `Split decision` reads as a result.
pub fn humanise(raw: &str) -> String {
    let spaced = raw.replace('_', " ");
    let mut chars = spaced.chars();
    match chars.next() {
        Some(first) => first.to_uppercase().collect::<String>() + chars.as_str(),
        None => String::new(),
    }
}

/// Clock style, not "3 min" — a media player never drops the seconds.
pub fn duration(total_seconds: u32) -> String {
    format!("{}:{:02}", total_seconds / 60, total_seconds % 60)
}

pub fn weight_class(raw: &str) -> String {
    humanise(raw)
}

/// The grey line above a bout row: `LIGHTWEIGHT · TITLE · 5 RNDS`.
pub fn bout_headline(weight_class_raw: &str, title_fight: bool, scheduled_rounds: u32) -> String {
    let base = weight_class_raw.replace('_', " ").to_uppercase();
    let title = if title_fight { " · TITLE" } else { "" };
    format!("{base}{title} · {scheduled_rounds} RNDS")
}

/// `Justin Gaethje · Tko · R4 5:00`.
pub fn result_line(winner_name: &str, method: &str, end_round: u32, end_time: &str) -> String {
    format!("{winner_name} · {} · R{end_round} {end_time}", humanise(method))
}

pub fn record_display(wins: u32, losses: u32, draws: u32, no_contests: u32) -> String {
    if no_contests > 0 {
        format!("{wins}-{losses}-{draws} ({no_contests} NC)")
    } else {
        format!("{wins}-{losses}-{draws}")
    }
}

/// Ordering is a product rule, not an alphabetical accident.
pub const SEGMENT_ORDER: [&str; 6] = [
    "main",
    "main_card",
    "prelim",
    "prelims",
    "early_prelim",
    "early_prelims",
];

pub fn segment_title(segment: &str) -> String {
    match segment {
        "main" => "Main Event",
        "main_card" => "Main Card",
        "prelim" | "prelims" => "Prelims",
        _ => "Early Prelims",
    }
    .to_string()
}

pub fn segment_rank(segment: &str) -> usize {
    SEGMENT_ORDER
        .iter()
        .position(|s| *s == segment)
        .unwrap_or(SEGMENT_ORDER.len())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn humanises_contract_codes() {
        assert_eq!(humanise("split_decision"), "Split decision");
        assert_eq!(humanise("tko"), "Tko");
        assert_eq!(humanise(""), "");
    }

    #[test]
    fn formats_clock_durations() {
        assert_eq!(duration(204), "3:24");
        assert_eq!(duration(61), "1:01");
        assert_eq!(duration(1800), "30:00");
    }

    #[test]
    fn records_show_no_contests_only_when_present() {
        assert_eq!(record_display(27, 5, 0, 0), "27-5-0");
        assert_eq!(record_display(27, 5, 0, 1), "27-5-0 (1 NC)");
    }

    #[test]
    fn main_event_sorts_first() {
        assert!(segment_rank("main") < segment_rank("prelim"));
        assert!(segment_rank("prelim") < segment_rank("early_prelim"));
    }
}
