use std::fs;
use std::path::{Path, PathBuf};

#[cfg(windows)]
use std::ffi::OsString;
#[cfg(windows)]
use std::os::windows::ffi::{OsStrExt, OsStringExt};

const WCHAR_PATH_LIMIT: usize = 32768;

#[repr(C)]
pub struct PlayasaPlaylistPath {
    ptr: *mut u16,
    len: usize,
}

#[repr(C)]
pub struct PlayasaPlaylistPathList {
    items: *mut PlayasaPlaylistPath,
    len: usize,
}

#[no_mangle]
pub extern "C" fn playasa_playlist_parse_cue(path: *const u16) -> PlayasaPlaylistPathList {
    let result = std::panic::catch_unwind(|| unsafe { parse_cue_ffi(path) });
    result.unwrap_or_else(|_| empty_path_list())
}

#[no_mangle]
pub extern "C" fn playasa_playlist_free_path_list(list: PlayasaPlaylistPathList) {
    unsafe {
        free_path_list(list);
    }
}

unsafe fn parse_cue_ffi(path: *const u16) -> PlayasaPlaylistPathList {
    let Ok(path) = wide_path_from_ptr(path) else {
        return empty_path_list();
    };
    let Ok(text) = read_text_lossy(&path) else {
        return empty_path_list();
    };

    to_path_list(parse_cue_text(&text, &path))
}

#[cfg(windows)]
unsafe fn wide_path_from_ptr(path: *const u16) -> Result<PathBuf, ()> {
    if path.is_null() {
        return Err(());
    }

    let mut len = 0usize;
    while len < WCHAR_PATH_LIMIT {
        if *path.add(len) == 0 {
            let wide = std::slice::from_raw_parts(path, len);
            return Ok(PathBuf::from(OsString::from_wide(wide)));
        }
        len += 1;
    }

    Err(())
}

#[cfg(not(windows))]
unsafe fn wide_path_from_ptr(_path: *const u16) -> Result<PathBuf, ()> {
    Err(())
}

fn read_text_lossy(path: &Path) -> std::io::Result<String> {
    let bytes = fs::read(path)?;

    if bytes.starts_with(&[0xff, 0xfe]) {
        let units = bytes[2..]
            .chunks_exact(2)
            .map(|chunk| u16::from_le_bytes([chunk[0], chunk[1]]))
            .collect::<Vec<_>>();
        return Ok(String::from_utf16_lossy(&units));
    }

    if bytes.starts_with(&[0xfe, 0xff]) {
        let units = bytes[2..]
            .chunks_exact(2)
            .map(|chunk| u16::from_be_bytes([chunk[0], chunk[1]]))
            .collect::<Vec<_>>();
        return Ok(String::from_utf16_lossy(&units));
    }

    Ok(String::from_utf8_lossy(&bytes).into_owned())
}

fn parse_cue_text(text: &str, cue_path: &Path) -> Vec<PathBuf> {
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

#[cfg(windows)]
fn encode_path(path: &Path) -> Vec<u16> {
    path.as_os_str().encode_wide().collect()
}

#[cfg(not(windows))]
fn encode_path(_path: &Path) -> Vec<u16> {
    Vec::new()
}

fn to_path_list(paths: Vec<PathBuf>) -> PlayasaPlaylistPathList {
    if paths.is_empty() {
        return empty_path_list();
    }

    let mut items = paths
        .into_iter()
        .map(|path| {
            let mut wide = encode_path(&path);
            let len = wide.len();
            let ptr = wide.as_mut_ptr();
            std::mem::forget(wide);
            PlayasaPlaylistPath { ptr, len }
        })
        .collect::<Vec<_>>();

    let len = items.len();
    let ptr = items.as_mut_ptr();
    std::mem::forget(items);
    PlayasaPlaylistPathList { items: ptr, len }
}

const fn empty_path_list() -> PlayasaPlaylistPathList {
    PlayasaPlaylistPathList {
        items: std::ptr::null_mut(),
        len: 0,
    }
}

unsafe fn free_path_list(list: PlayasaPlaylistPathList) {
    if list.items.is_null() || list.len == 0 {
        return;
    }

    let items = Vec::from_raw_parts(list.items, list.len, list.len);
    for item in items {
        if !item.ptr.is_null() && item.len > 0 {
            drop(Vec::from_raw_parts(item.ptr, item.len, item.len));
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
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
