//! The `fightevents` UniFFI namespace.

use crate::catalog::{Catalog, CatalogError};
use crate::dataset::{Bout, Event, Fighter};
use crate::display;
use crate::tape;
use fightcore::{money, odds};
use std::sync::Arc;

#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum EventsError {
    #[error("decoding")]
    Decoding { field: String },
    #[error("not found")]
    NotFound { id: String },
}

impl From<CatalogError> for EventsError {
    fn from(value: CatalogError) -> Self {
        let CatalogError::Decoding { field } = value;
        Self::Decoding { field }
    }
}

// MARK: - Records

#[derive(uniffi::Record, Clone, Debug)]
pub struct EventSummary {
    pub id: String,
    pub name: String,
    pub date: String,
    pub venue: String,
    pub city: String,
    /// `Etihad Arena · Abu Dhabi` — assembled once, not in two layout files.
    pub location_line: String,
    pub bout_count: u32,
    pub title_fight_count: u32,
    pub poster_path: String,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct BoutSummary {
    pub id: String,
    pub event_id: String,
    pub segment: String,
    pub order: u32,
    pub headline: String,
    pub weight_class_display: String,
    pub title_fight: bool,
    pub red: CornerSummary,
    pub blue: CornerSummary,
    pub result_line: String,
    pub winner_id: String,
    pub winner_name: String,
    pub result_method: String,
    pub result_detail: String,
    pub end_round: u32,
    pub end_time: String,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct CornerSummary {
    pub fighter_id: String,
    pub name: String,
    pub record_display: String,
    pub portrait_path: String,
    pub odds_decimal: String,
    pub odds_fractional: String,
    pub implied_probability: String,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct CardSection {
    pub title: String,
    pub bouts: Vec<BoutSummary>,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct FighterSummary {
    pub id: String,
    pub name: String,
    pub nickname: Option<String>,
    pub country: Option<String>,
    pub height_cm: Option<u32>,
    pub reach_in: Option<u32>,
    pub stance: Option<String>,
    pub record_display: String,
    pub wins: u32,
    pub losses: u32,
    pub draws: u32,
    pub no_contests: u32,
    pub portrait_path: String,
}

#[derive(uniffi::Enum, Clone, Copy, Debug, PartialEq, Eq)]
pub enum AdvantageRecord {
    Red,
    Blue,
    Even,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct TapeRowRecord {
    pub label: String,
    pub red: String,
    pub blue: String,
    pub advantage: AdvantageRecord,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct TaleOfTheTape {
    pub rows: Vec<TapeRowRecord>,
    pub edge_summary: Option<String>,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct BoutIndexEntry {
    pub id: String,
    pub red_fighter_id: String,
    pub blue_fighter_id: String,
    pub winner_id: String,
}

/// Everything the slip row needs about one leg. This replaced two nested lookups that the
/// slip screen was doing by hand on every body pass.
#[derive(uniffi::Record, Clone, Debug)]
pub struct LegContext {
    pub fighter_name: String,
    pub opponent_name: String,
    pub event_name: String,
    pub subtitle: String,
}

// MARK: - Mapping

fn corner_summary(
    catalog: &Catalog,
    corner: &crate::dataset::Corner,
) -> CornerSummary {
    let fighter = catalog.fighter(&corner.fighter_id);
    let implied = money::try_parse(&corner.closing_odds.decimal)
        .map(|value| money::format_implied_probability(odds::implied_probability(value)))
        .unwrap_or_default();
    CornerSummary {
        fighter_id: corner.fighter_id.clone(),
        name: corner.name.clone(),
        record_display: fighter.map_or("—".to_string(), |f| f.record.display.clone()),
        portrait_path: fighter.map_or_else(
            || format!("assets/fighters/{}.jpg", corner.fighter_id),
            |f| f.portrait.clone(),
        ),
        odds_decimal: corner.closing_odds.decimal.clone(),
        odds_fractional: corner.closing_odds.fractional.clone(),
        implied_probability: implied,
    }
}

fn bout_summary(catalog: &Catalog, event_id: &str, bout: &Bout) -> BoutSummary {
    BoutSummary {
        id: bout.id.clone(),
        event_id: event_id.to_string(),
        segment: bout.segment.clone(),
        order: bout.order,
        headline: display::bout_headline(&bout.weight_class, bout.title_fight, bout.scheduled_rounds),
        weight_class_display: display::weight_class(&bout.weight_class),
        title_fight: bout.title_fight,
        red: corner_summary(catalog, &bout.red_corner),
        blue: corner_summary(catalog, &bout.blue_corner),
        result_line: display::result_line(
            &bout.result.winner_name,
            &bout.result.method,
            bout.result.end_round,
            &bout.result.end_time,
        ),
        winner_id: bout.result.winner_id.clone(),
        winner_name: bout.result.winner_name.clone(),
        result_method: bout.result.method.clone(),
        result_detail: bout.result.detail.clone(),
        end_round: bout.result.end_round,
        end_time: bout.result.end_time.clone(),
    }
}

fn event_summary(event: &Event) -> EventSummary {
    EventSummary {
        id: event.id.clone(),
        name: event.name.clone(),
        date: event.date.clone(),
        venue: event.venue.clone(),
        city: event.city.clone(),
        location_line: format!("{} · {}", event.venue, event.city),
        bout_count: event.bouts.len() as u32,
        title_fight_count: event.bouts.iter().filter(|b| b.title_fight).count() as u32,
        poster_path: format!("assets/events/{}.jpg", event.id),
    }
}

fn fighter_summary(fighter: &Fighter) -> FighterSummary {
    FighterSummary {
        id: fighter.id.clone(),
        name: fighter.name.clone(),
        nickname: fighter.nickname.clone(),
        country: fighter.country.clone(),
        height_cm: fighter.height_cm,
        reach_in: fighter.reach_in,
        stance: fighter.stance.as_deref().map(display::humanise),
        record_display: display::record_display(
            fighter.record.wins,
            fighter.record.losses,
            fighter.record.draws,
            fighter.record.no_contests,
        ),
        wins: fighter.record.wins,
        losses: fighter.record.losses,
        draws: fighter.record.draws,
        no_contests: fighter.record.no_contests,
        portrait_path: fighter.portrait.clone(),
    }
}

impl From<tape::Advantage> for AdvantageRecord {
    fn from(value: tape::Advantage) -> Self {
        match value {
            tape::Advantage::Red => Self::Red,
            tape::Advantage::Blue => Self::Blue,
            tape::Advantage::Even => Self::Even,
        }
    }
}

// MARK: - Object

#[derive(uniffi::Object)]
pub struct EventCatalog {
    catalog: Catalog,
}

#[uniffi::export]
impl EventCatalog {
    /// Both files are handed in as text: the SDK does no I/O, so the host keeps control of
    /// sandboxing and bundling.
    #[uniffi::constructor]
    pub fn parse(events_json: String, fighters_json: String) -> Result<Arc<Self>, EventsError> {
        let catalog = Catalog::parse(&events_json, &fighters_json)?;
        Ok(Arc::new(Self { catalog }))
    }

    pub fn events(&self) -> Vec<EventSummary> {
        self.catalog.events().iter().map(event_summary).collect()
    }

    pub fn event(&self, id: String) -> Result<EventSummary, EventsError> {
        self.catalog
            .event(&id)
            .map(event_summary)
            .ok_or(EventsError::NotFound { id })
    }

    pub fn card_sections(&self, event_id: String) -> Vec<CardSection> {
        self.catalog
            .card_sections(&event_id)
            .into_iter()
            .map(|(title, bouts)| CardSection {
                title,
                bouts: bouts
                    .into_iter()
                    .map(|bout| bout_summary(&self.catalog, &event_id, bout))
                    .collect(),
            })
            .collect()
    }

    pub fn bout(&self, id: String) -> Result<BoutSummary, EventsError> {
        let event_id = self
            .catalog
            .event_of_bout(&id)
            .map(|e| e.id.clone())
            .unwrap_or_default();
        self.catalog
            .bout(&id)
            .map(|bout| bout_summary(&self.catalog, &event_id, bout))
            .ok_or(EventsError::NotFound { id })
    }

    pub fn fighter(&self, id: String) -> Result<FighterSummary, EventsError> {
        self.catalog
            .fighter(&id)
            .map(fighter_summary)
            .ok_or(EventsError::NotFound { id })
    }

    pub fn tale_of_the_tape(&self, bout_id: String) -> Result<TaleOfTheTape, EventsError> {
        let bout = self
            .catalog
            .bout(&bout_id)
            .ok_or(EventsError::NotFound { id: bout_id })?;
        let red = self.catalog.fighter(&bout.red_corner.fighter_id);
        let blue = self.catalog.fighter(&bout.blue_corner.fighter_id);
        Ok(TaleOfTheTape {
            rows: tape::rows(red, blue)
                .into_iter()
                .map(|row| TapeRowRecord {
                    label: row.label,
                    red: row.red,
                    blue: row.blue,
                    advantage: row.advantage.into(),
                })
                .collect(),
            edge_summary: tape::edge_summary(red, blue),
        })
    }

    pub fn bout_index(&self) -> Vec<BoutIndexEntry> {
        self.catalog
            .bout_index()
            .into_iter()
            .map(|(id, red, blue, winner)| BoutIndexEntry {
                id: id.to_string(),
                red_fighter_id: red.to_string(),
                blue_fighter_id: blue.to_string(),
                winner_id: winner.to_string(),
            })
            .collect()
    }

    pub fn leg_context(&self, bout_id: String, fighter_id: String) -> LegContext {
        let fighter_name = self
            .catalog
            .fighter(&fighter_id)
            .map_or_else(|| fighter_id.clone(), |f| f.name.clone());
        let opponent_name = self
            .catalog
            .opponent_of(&bout_id, &fighter_id)
            .map_or_else(|| "—".to_string(), |f| f.name.clone());
        let event_name = self
            .catalog
            .event_of_bout(&bout_id)
            .map_or_else(|| "—".to_string(), |e| e.name.clone());
        LegContext {
            fighter_name,
            opponent_name: opponent_name.clone(),
            event_name: event_name.clone(),
            subtitle: format!("vs {opponent_name} · {event_name}"),
        }
    }

}

// MARK: - Pure formatting

#[uniffi::export]
pub fn format_duration(total_seconds: u32) -> String {
    display::duration(total_seconds)
}

#[uniffi::export]
pub fn humanise_code(raw: String) -> String {
    display::humanise(&raw)
}

#[uniffi::export]
pub fn segment_title(segment: String) -> String {
    display::segment_title(&segment)
}
