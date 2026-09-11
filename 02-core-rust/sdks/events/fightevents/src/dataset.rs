//! The dataset as it sits on disk. Both hosts used to declare these shapes themselves — one
//! in Swift `Codable`, one in Kotlin `@Serializable` — and both had to re-derive the bout
//! index from them at launch.

use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct EventsFile {
    pub events: Vec<Event>,
}

#[derive(Debug, Deserialize)]
pub struct FightersFile {
    pub fighters: Vec<Fighter>,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Event {
    pub id: String,
    pub name: String,
    pub date: String,
    pub venue: String,
    pub city: String,
    #[serde(default)]
    pub country: Option<String>,
    #[serde(default)]
    pub attendance: Option<u32>,
    pub bouts: Vec<Bout>,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Bout {
    pub id: String,
    pub order: u32,
    pub segment: String,
    pub weight_class: String,
    pub title_fight: bool,
    pub scheduled_rounds: u32,
    pub red_corner: Corner,
    pub blue_corner: Corner,
    pub result: BoutResult,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Corner {
    pub fighter_id: String,
    pub name: String,
    pub closing_odds: Odds,
}

#[derive(Debug, Clone, Deserialize)]
pub struct Odds {
    pub decimal: String,
    pub fractional: String,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BoutResult {
    pub winner_id: String,
    pub winner_name: String,
    pub method: String,
    pub detail: String,
    pub end_round: u32,
    pub end_time: String,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Fighter {
    pub id: String,
    pub name: String,
    #[serde(default)]
    pub nickname: Option<String>,
    #[serde(default)]
    pub country: Option<String>,
    #[serde(default)]
    pub height_cm: Option<u32>,
    #[serde(default)]
    pub reach_in: Option<u32>,
    #[serde(default)]
    pub stance: Option<String>,
    pub record: Record,
    pub portrait: String,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Record {
    pub wins: u32,
    pub losses: u32,
    pub draws: u32,
    pub no_contests: u32,
    pub display: String,
}
