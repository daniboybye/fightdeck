//! The catalogue: parse once, then answer the questions both screens ask.

use crate::dataset::{Bout, Event, EventsFile, Fighter, FightersFile};
use crate::display;
use std::collections::HashMap;

#[derive(Default)]
pub struct Catalog {
    events: Vec<Event>,
    fighters: HashMap<String, Fighter>,
    bout_to_event: HashMap<String, String>,
}

#[derive(Debug, thiserror::Error)]
pub enum CatalogError {
    #[error("could not decode {field}")]
    Decoding { field: String },
}

impl Catalog {
    pub fn parse(events_json: &str, fighters_json: &str) -> Result<Self, CatalogError> {
        let events: EventsFile = serde_json::from_str(events_json)
            .map_err(|_| CatalogError::Decoding { field: "events".into() })?;
        let fighters: FightersFile = serde_json::from_str(fighters_json)
            .map_err(|_| CatalogError::Decoding { field: "fighters".into() })?;

        let mut bout_to_event = HashMap::new();
        for event in &events.events {
            for bout in &event.bouts {
                bout_to_event.insert(bout.id.clone(), event.id.clone());
            }
        }

        Ok(Self {
            events: events.events,
            fighters: fighters
                .fighters
                .into_iter()
                .map(|f| (f.id.clone(), f))
                .collect(),
            bout_to_event,
        })
    }

    pub fn events(&self) -> &[Event] {
        &self.events
    }

    pub fn event(&self, id: &str) -> Option<&Event> {
        self.events.iter().find(|e| e.id == id)
    }

    pub fn fighter(&self, id: &str) -> Option<&Fighter> {
        self.fighters.get(id)
    }

    pub fn bout(&self, id: &str) -> Option<&Bout> {
        self.events
            .iter()
            .flat_map(|e| e.bouts.iter())
            .find(|b| b.id == id)
    }

    pub fn event_of_bout(&self, bout_id: &str) -> Option<&Event> {
        let event_id = self.bout_to_event.get(bout_id)?;
        self.event(event_id)
    }

    /// Every bout flattened to the four fields the slip engine needs. Both hosts used to
    /// re-derive this from their own JSON decoding at launch.
    pub fn bout_index(&self) -> Vec<(&str, &str, &str, &str)> {
        self.events
            .iter()
            .flat_map(|e| e.bouts.iter())
            .map(|b| {
                (
                    b.id.as_str(),
                    b.red_corner.fighter_id.as_str(),
                    b.blue_corner.fighter_id.as_str(),
                    b.result.winner_id.as_str(),
                )
            })
            .collect()
    }

    /// A card in running order: main event first, then main card, prelims, early prelims,
    /// each section internally sorted by bout order.
    pub fn card_sections(&self, event_id: &str) -> Vec<(String, Vec<&Bout>)> {
        let Some(event) = self.event(event_id) else {
            return vec![];
        };
        let mut grouped: HashMap<&str, Vec<&Bout>> = HashMap::new();
        for bout in &event.bouts {
            grouped.entry(bout.segment.as_str()).or_default().push(bout);
        }
        let mut segments: Vec<&str> = grouped.keys().copied().collect();
        segments.sort_by_key(|s| display::segment_rank(s));

        segments
            .into_iter()
            .map(|segment| {
                let mut bouts = grouped.remove(segment).unwrap_or_default();
                bouts.sort_by_key(|b| b.order);
                (display::segment_title(segment), bouts)
            })
            .filter(|(_, bouts)| !bouts.is_empty())
            .collect()
    }

    pub fn opponent_of(&self, bout_id: &str, fighter_id: &str) -> Option<&Fighter> {
        let bout = self.bout(bout_id)?;
        let opponent_id = if bout.red_corner.fighter_id == fighter_id {
            &bout.blue_corner.fighter_id
        } else {
            &bout.red_corner.fighter_id
        };
        self.fighter(opponent_id)
    }
}
