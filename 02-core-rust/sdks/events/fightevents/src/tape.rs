//! Tale of the tape. The hosts rendered five rows of raw values; the SDK also decides who
//! holds each advantage, which is the part nobody wants to write twice.

use crate::dataset::Fighter;
use crate::display;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Advantage {
    Red,
    Blue,
    Even,
}

impl Advantage {
    pub fn code(&self) -> &'static str {
        match self {
            Self::Red => "red",
            Self::Blue => "blue",
            Self::Even => "even",
        }
    }
}

pub struct TapeRow {
    pub label: String,
    pub red: String,
    pub blue: String,
    pub advantage: Advantage,
}

const MISSING: &str = "—";

fn measure(value: Option<u32>, unit: &str) -> String {
    value.map_or_else(|| MISSING.to_string(), |v| format!("{v} {unit}"))
}

fn taller(red: Option<u32>, blue: Option<u32>) -> Advantage {
    match (red, blue) {
        (Some(r), Some(b)) if r > b => Advantage::Red,
        (Some(r), Some(b)) if b > r => Advantage::Blue,
        _ => Advantage::Even,
    }
}

fn text(value: &Option<String>) -> String {
    value.clone().unwrap_or_else(|| MISSING.to_string())
}

pub fn rows(red: Option<&Fighter>, blue: Option<&Fighter>) -> Vec<TapeRow> {
    let red_height = red.and_then(|f| f.height_cm);
    let blue_height = blue.and_then(|f| f.height_cm);
    let red_reach = red.and_then(|f| f.reach_in);
    let blue_reach = blue.and_then(|f| f.reach_in);

    vec![
        TapeRow {
            label: "RECORD".into(),
            red: red.map_or(MISSING.into(), |f| f.record.display.clone()),
            blue: blue.map_or(MISSING.into(), |f| f.record.display.clone()),
            advantage: match (red, blue) {
                (Some(r), Some(b)) if r.record.wins > b.record.wins => Advantage::Red,
                (Some(r), Some(b)) if b.record.wins > r.record.wins => Advantage::Blue,
                _ => Advantage::Even,
            },
        },
        TapeRow {
            label: "HEIGHT".into(),
            red: measure(red_height, "cm"),
            blue: measure(blue_height, "cm"),
            advantage: taller(red_height, blue_height),
        },
        TapeRow {
            label: "REACH".into(),
            red: measure(red_reach, "in"),
            blue: measure(blue_reach, "in"),
            advantage: taller(red_reach, blue_reach),
        },
        TapeRow {
            label: "STANCE".into(),
            red: red.map_or(MISSING.into(), |f| text(&f.stance.as_ref().map(|s| display::humanise(s)))),
            blue: blue.map_or(MISSING.into(), |f| text(&f.stance.as_ref().map(|s| display::humanise(s)))),
            advantage: Advantage::Even,
        },
        TapeRow {
            label: "COUNTRY".into(),
            red: red.map_or(MISSING.into(), |f| text(&f.country)),
            blue: blue.map_or(MISSING.into(), |f| text(&f.country)),
            advantage: Advantage::Even,
        },
    ]
}

/// One line for the matchup header: who is physically bigger, and by how much.
pub fn edge_summary(red: Option<&Fighter>, blue: Option<&Fighter>) -> Option<String> {
    let (red, blue) = (red?, blue?);
    let red_reach = red.reach_in?;
    let blue_reach = blue.reach_in?;
    if red_reach == blue_reach {
        return Some("Even on reach".to_string());
    }
    let (name, edge) = if red_reach > blue_reach {
        (&red.name, red_reach - blue_reach)
    } else {
        (&blue.name, blue_reach - red_reach)
    };
    Some(format!("{name} has a {edge} in reach advantage"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::dataset::Record;

    fn fighter(name: &str, height: u32, reach: u32, wins: u32) -> Fighter {
        Fighter {
            id: name.to_lowercase(),
            name: name.to_string(),
            nickname: None,
            country: Some("Testland".into()),
            height_cm: Some(height),
            reach_in: Some(reach),
            stance: Some("orthodox".into()),
            record: Record { wins, losses: 0, draws: 0, no_contests: 0, display: format!("{wins}-0-0") },
            portrait: String::new(),
        }
    }

    #[test]
    fn taller_fighter_takes_the_height_row() {
        let red = fighter("Red", 180, 70, 27);
        let blue = fighter("Blue", 175, 72, 20);
        let rows = rows(Some(&red), Some(&blue));
        assert_eq!(rows[1].advantage, Advantage::Red);
        assert_eq!(rows[2].advantage, Advantage::Blue);
    }

    #[test]
    fn reach_edge_names_the_longer_fighter() {
        let red = fighter("Red", 180, 70, 27);
        let blue = fighter("Blue", 175, 74, 20);
        assert_eq!(
            edge_summary(Some(&red), Some(&blue)).as_deref(),
            Some("Blue has a 4 in reach advantage")
        );
    }

    #[test]
    fn missing_fighter_yields_dashes() {
        let rows = rows(None, None);
        assert!(rows.iter().all(|r| r.red == MISSING && r.blue == MISSING));
    }
}
