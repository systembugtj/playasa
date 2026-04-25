use crate::paths::resolve_playlist_entry;
use std::path::{Path, PathBuf};

pub(crate) fn parse_pls_text(text: &str, playlist_path: &Path) -> Vec<PathBuf> {
    let base_dir = playlist_path.parent().unwrap_or_else(|| Path::new(""));

    text.lines()
        .filter_map(parse_pls_file_value)
        .filter_map(|entry| resolve_playlist_entry(base_dir, entry))
        .collect()
}

fn parse_pls_file_value(line: &str) -> Option<&str> {
    let trimmed = line.trim();
    if trimmed.is_empty() || trimmed.starts_with(';') || trimmed.starts_with('#') {
        return None;
    }

    let (key, value) = trimmed.split_once('=')?;
    let lower_key = key.trim().to_ascii_lowercase();
    lower_key
        .starts_with("file")
        .then_some(value.trim())
        .filter(|value| !value.is_empty())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_pls_file_entries() {
        let text = "[playlist]\r\nFile1=song.mp3\r\nTitle1=Sample\r\nFile2=http://example.test/live.mp3\r\n";
        let parsed = parse_pls_text(text, Path::new(r"C:\media\list.pls"));

        assert_eq!(parsed.len(), 2);
        assert_eq!(parsed[0], PathBuf::from(r"C:\media\song.mp3"));
        assert_eq!(parsed[1], PathBuf::from("http://example.test/live.mp3"));
    }
}
