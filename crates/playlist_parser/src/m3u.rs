use crate::paths::resolve_playlist_entry;
use std::path::{Path, PathBuf};

pub(crate) fn parse_m3u_text(text: &str, playlist_path: &Path) -> Vec<PathBuf> {
    let base_dir = playlist_path.parent().unwrap_or_else(|| Path::new(""));

    text.lines()
        .filter_map(parse_m3u_line)
        .filter_map(|entry| resolve_playlist_entry(base_dir, entry))
        .collect()
}

fn parse_m3u_line(line: &str) -> Option<&str> {
    let trimmed = line.trim();
    if trimmed.is_empty() || trimmed.starts_with('#') {
        return None;
    }

    Some(trimmed)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_m3u_entries_and_ignores_metadata() {
        let text = "#EXTM3U\r\n#EXTINF:123,Sample\r\nsong.mp3\r\n\r\nhttp://example.test/live.mp3\r\n";
        let parsed = parse_m3u_text(text, Path::new(r"C:\media\list.m3u"));

        assert_eq!(parsed.len(), 2);
        assert_eq!(parsed[0], PathBuf::from(r"C:\media\song.mp3"));
        assert_eq!(parsed[1], PathBuf::from("http://example.test/live.mp3"));
    }
}
