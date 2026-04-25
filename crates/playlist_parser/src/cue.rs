use std::path::{Path, PathBuf};

pub(crate) fn parse_cue_text(text: &str, cue_path: &Path) -> Vec<PathBuf> {
    let base_dir = cue_path.parent().unwrap_or_else(|| Path::new(""));

    text.lines()
        .filter_map(parse_cue_file_line)
        .filter_map(|file_name| resolve_cue_media_path(base_dir, &file_name))
        .collect()
}

fn parse_cue_file_line(line: &str) -> Option<String> {
    let trimmed = line.trim();
    let rest = trimmed.strip_prefix("FILE")?.trim_start();

    if let Some(quoted) = rest.strip_prefix('"') {
        let end = quoted.find('"')?;
        let file_name = quoted[..end].trim();
        return (!file_name.is_empty()).then(|| file_name.to_owned());
    }

    let mut parts = rest.rsplitn(2, char::is_whitespace);
    parts.next()?;
    let file_name = parts.next().unwrap_or(rest).trim();
    (!file_name.is_empty()).then(|| file_name.to_owned())
}

fn resolve_cue_media_path(base_dir: &Path, file_name: &str) -> Option<PathBuf> {
    let path = PathBuf::from(file_name);
    if path.exists() {
        return Some(path);
    }

    let fallback_name = path.file_name()?;
    let fallback_path = base_dir.join(fallback_name);
    fallback_path.exists().then_some(fallback_path)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::text::read_text_lossy;
    use std::fs;
    use std::io::Write;

    #[test]
    fn parses_quoted_file_lines() {
        assert_eq!(
            parse_cue_file_line("  FILE \"Track 01.flac\" WAVE  "),
            Some("Track 01.flac".to_owned())
        );
    }

    #[test]
    fn parses_unquoted_file_lines() {
        assert_eq!(
            parse_cue_file_line("FILE track01.wav WAVE"),
            Some("track01.wav".to_owned())
        );
    }

    #[test]
    fn ignores_non_file_lines() {
        assert_eq!(parse_cue_file_line("TRACK 01 AUDIO"), None);
    }

    #[test]
    fn resolves_relative_media_files() {
        let root =
            std::env::temp_dir().join(format!("playasa_playlist_parser_{}", std::process::id()));
        let _ = fs::remove_dir_all(&root);
        fs::create_dir_all(&root).expect("create temp dir");

        let media = root.join("Track 01.flac");
        fs::File::create(&media).expect("create media");
        let cue = root.join("album.cue");
        let mut cue_file = fs::File::create(&cue).expect("create cue");
        writeln!(cue_file, "FILE \"Track 01.flac\" WAVE").expect("write cue");

        let parsed = parse_cue_text(&read_text_lossy(&cue).expect("read cue"), &cue);
        assert_eq!(parsed, vec![media]);

        fs::remove_dir_all(root).expect("remove temp dir");
    }
}
