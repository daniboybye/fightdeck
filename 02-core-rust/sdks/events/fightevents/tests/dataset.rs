//! The dataset as the hosts now receive it: loaded from a directory and served over HTTP.

use fightevents::{asset_url, start_asset_server, EventCatalog, EventsError};
use std::io::{Read, Write};
use std::net::TcpStream;

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

fn get(port: u16, path: &str) -> String {
    let mut stream = TcpStream::connect(("127.0.0.1", port)).unwrap();
    write!(stream, "GET /{path} HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n").unwrap();
    let mut response = Vec::new();
    stream.read_to_end(&mut response).unwrap();
    String::from_utf8_lossy(&response).into_owned()
}

#[test]
fn serves_dataset_files_and_nothing_outside_it() {
    let port = start_asset_server(DATASET.to_string()).unwrap();
    assert_eq!(start_asset_server(DATASET.to_string()).unwrap(), port);
    assert_eq!(asset_url("a.jpg".into()), Some(format!("http://127.0.0.1:{port}/a.jpg")));

    let image = get(port, "assets/events/ufc-328.jpg");
    assert!(image.starts_with("HTTP/1.1 200 OK\r\nContent-Type: image/jpeg\r\n"));
    assert!(get(port, "assets/events/missing.jpg").starts_with("HTTP/1.1 404"));
    assert!(get(port, "../README.md").starts_with("HTTP/1.1 404"));
}
