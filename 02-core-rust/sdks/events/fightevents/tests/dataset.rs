//! The dataset as the hosts now receive it: loaded from a directory.

use fightevents::{EventCatalog, EventsError};

const DATASET: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/../../../../dataset");

#[test]
fn loads_the_catalogue_news_and_media_from_the_dataset_root() {
    let catalog = EventCatalog::load(DATASET.to_string()).unwrap();
    assert!(!catalog.events().is_empty());
    assert!(!catalog.news().unwrap().is_empty());
    assert!(catalog.media().unwrap().iter().all(|clip| clip.duration_seconds > 0));
}

#[test]
fn a_missing_dataset_is_an_error_rather_than_an_empty_catalogue() {
    let missing = EventCatalog::load("/nonexistent/dataset".to_string());
    assert!(matches!(missing, Err(EventsError::Io { .. })));
}
