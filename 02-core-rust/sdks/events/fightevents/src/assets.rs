//! Serves the dataset over HTTP on 127.0.0.1, so the image loaders on both platforms make a
//! real network fetch rather than reading a file. Each host used to carry its own server —
//! Network.framework on iOS, a `ServerSocket` on Android — doing the same four things: bind,
//! read a request line, refuse paths outside the dataset, answer with the file.

use crate::ffi::EventsError;
use std::fs;
use std::io::{BufRead, BufReader, Write};
use std::net::{TcpListener, TcpStream};
use std::path::{Path, PathBuf};
use std::sync::{Mutex, MutexGuard};
use std::thread;
use std::time::Duration;

/// Zero while nothing is listening.
static PORT: Mutex<u16> = Mutex::new(0);

fn lock_port() -> MutexGuard<'static, u16> {
    PORT.lock().unwrap_or_else(|poisoned| poisoned.into_inner())
}

/// Starts serving `dataset_root` on a port the kernel picks and returns it. The demo apps share
/// one simulator, and a fixed port goes to whichever of them launches first. A second call
/// while the server runs returns the same port, so a Retry cannot start another server and
/// leave the app pointing at the wrong one.
#[uniffi::export]
pub fn start_asset_server(dataset_root: String) -> Result<u16, EventsError> {
    let mut port = lock_port();
    if *port != 0 {
        return Ok(*port);
    }
    let io = |error: std::io::Error| EventsError::Io { reason: error.to_string() };
    let root = fs::canonicalize(&dataset_root).map_err(io)?;
    let listener = TcpListener::bind(("127.0.0.1", 0)).map_err(io)?;
    *port = listener.local_addr().map_err(io)?.port();
    thread::spawn(move || {
        for stream in listener.incoming() {
            let Ok(stream) = stream else { break };
            let root = root.clone();
            thread::spawn(move || serve(&stream, &root));
        }
        // Image URLs are built from the port, so a listener that died must stop advertising it.
        *lock_port() = 0;
    });
    Ok(*port)
}

/// None until the server is up, so an image shows its placeholder rather than a URL that
/// nothing answers.
#[uniffi::export]
pub fn asset_url(path: String) -> Option<String> {
    let port = *lock_port();
    (port != 0).then(|| format!("http://127.0.0.1:{port}/{path}"))
}

fn serve(stream: &TcpStream, root: &Path) {
    // A client that connects and never writes would otherwise hold this thread for good.
    let _ = stream.set_read_timeout(Some(Duration::from_secs(5)));
    let Some(request_line) = read_request(stream) else { return };
    let response = match request_line.split(' ').nth(1) {
        Some(path) => match file_under(root, path) {
            Some((file, body)) => response("200 OK", content_type(&file), &body),
            None => response("404 Not Found", "text/plain", b"Not Found"),
        },
        None => response("400 Bad Request", "text/plain", b"Bad Request"),
    };
    let mut writer = stream;
    let _ = writer.write_all(&response);
}

/// Reads the headers as well, though nothing uses them: closing a socket with unread bytes
/// makes the kernel answer with a reset, and the reset can reach the client before the image.
fn read_request(stream: &TcpStream) -> Option<String> {
    let mut reader = BufReader::new(stream);
    let mut request_line = String::new();
    reader.read_line(&mut request_line).ok()?;
    let mut header = String::new();
    while reader.read_line(&mut header).is_ok_and(|read| read > 2) {
        header.clear();
    }
    Some(request_line)
}

/// Canonicalised before the prefix check, so `../` cannot climb out of the dataset.
fn file_under(root: &Path, request_path: &str) -> Option<(PathBuf, Vec<u8>)> {
    let file = fs::canonicalize(root.join(request_path.trim_start_matches('/'))).ok()?;
    if !file.starts_with(root) {
        return None;
    }
    let body = fs::read(&file).ok()?;
    Some((file, body))
}

fn response(status: &str, content_type: &str, body: &[u8]) -> Vec<u8> {
    let mut response = format!(
        "HTTP/1.1 {status}\r\nContent-Type: {content_type}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
        body.len()
    )
    .into_bytes();
    response.extend_from_slice(body);
    response
}

fn content_type(file: &Path) -> &'static str {
    let extension = file.extension().and_then(|ext| ext.to_str()).map(str::to_ascii_lowercase);
    match extension.as_deref() {
        Some("jpg" | "jpeg") => "image/jpeg",
        Some("png") => "image/png",
        _ => "application/octet-stream",
    }
}

