//! Commands for a running title (diagnostics builds): `VICTORY_LIVE` names a
//! file that is read and removed at each presented frame, one command a
//! line, so that a pipeline can be cut or a frame captured without starting
//! the title again.
//!
//! - `skip <hash>` / `unskip <hash>`: the pipelines using that shader draw
//!   nothing / draw again (as `VICTORY_SKIP_PIPELINES`, which they extend);
//! - `skips`: logs the shaders skipped;
//! - `capture`: the next frame is captured as `VICTORY_CAPTURE_FRAMES` would
//!   (with its targets under `VICTORY_DUMP_TARGETS`);
//! - `mark <text>`: logs `text`, to cut a run's measures.

use std::path::PathBuf;
use std::sync::OnceLock;

/// A command of the file.
#[derive(Debug, PartialEq, Eq)]
pub(crate) enum Command {
    Skip(String),
    Unskip(String),
    Skips,
    Capture,
    Mark(String),
}

/// The command of one line; `Err` names what is wrong with it.
pub(crate) fn parse(line: &str) -> Result<Command, String> {
    let line = line.trim();
    let (word, rest) = line.split_once(char::is_whitespace).unwrap_or((line, ""));
    let rest = rest.trim();
    let hash = |rest: &str| {
        if rest.len() == 16 && rest.bytes().all(|b| b.is_ascii_hexdigit()) {
            Ok(rest.to_ascii_lowercase())
        } else {
            Err(format!("{word} takes a 16-digit shader hash, not {rest:?}"))
        }
    };
    match word {
        "skip" => hash(rest).map(Command::Skip),
        "unskip" => hash(rest).map(Command::Unskip),
        "skips" => Ok(Command::Skips),
        "capture" => Ok(Command::Capture),
        "mark" => Ok(Command::Mark(rest.to_string())),
        _ => Err(format!("unknown command {line:?}")),
    }
}

fn file() -> Option<&'static PathBuf> {
    static FILE: OnceLock<Option<PathBuf>> = OnceLock::new();
    FILE.get_or_init(|| std::env::var_os("VICTORY_LIVE").map(PathBuf::from))
        .as_ref()
}

/// At the present of frame `frame`: runs the commands waiting in the file.
pub(crate) fn poll(frame: u64) {
    let Some(path) = file() else { return };
    let Ok(text) = std::fs::read_to_string(path) else {
        return;
    };
    let _ = std::fs::remove_file(path);
    for line in text.lines().filter(|l| !l.trim().is_empty()) {
        match parse(line) {
            Ok(Command::Skip(hash)) => {
                crate::pipeline::live_skip(&hash, true);
                tracing::warn!(frame, hash, "live: skipped");
            }
            Ok(Command::Unskip(hash)) => {
                crate::pipeline::live_skip(&hash, false);
                tracing::warn!(frame, hash, "live: skipped no more");
            }
            Ok(Command::Skips) => {
                tracing::warn!(frame, hashes = ?crate::pipeline::live_skips(), "live: skipped shaders")
            }
            Ok(Command::Capture) => {
                crate::capture::capture_next(frame);
                tracing::warn!(frame, "live: the next frame is captured");
            }
            Ok(Command::Mark(text)) => tracing::warn!(frame, "live: mark {text}"),
            Err(why) => tracing::warn!(frame, "live: {why}"),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn commands_are_read_from_their_lines() {
        assert_eq!(
            parse("skip 7F05DDAB771799A9"),
            Ok(Command::Skip("7f05ddab771799a9".into()))
        );
        assert_eq!(
            parse("  unskip 7f05ddab771799a9 "),
            Ok(Command::Unskip("7f05ddab771799a9".into()))
        );
        assert_eq!(parse("skips"), Ok(Command::Skips));
        assert_eq!(parse("capture"), Ok(Command::Capture));
        assert_eq!(
            parse("mark cell, FSR on"),
            Ok(Command::Mark("cell, FSR on".into()))
        );
        assert!(parse("skip 1234").is_err());
        assert!(parse("skip zzzzzzzzzzzzzzzz").is_err());
        assert!(parse("explode").is_err());
    }
}
