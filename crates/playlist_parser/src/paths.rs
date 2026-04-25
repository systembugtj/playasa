use std::path::{Path, PathBuf};

#[cfg(windows)]
use std::os::windows::ffi::OsStrExt;

#[cfg(windows)]
pub(crate) fn encode_path(path: &Path) -> Vec<u16> {
    path.as_os_str().encode_wide().collect()
}

#[cfg(not(windows))]
pub(crate) fn encode_path(_path: &Path) -> Vec<u16> {
    Vec::new()
}

pub(crate) fn resolve_playlist_entry(base_dir: &Path, value: &str) -> Option<PathBuf> {
    let trimmed = value.trim().trim_matches('"');
    if trimmed.is_empty() {
        return None;
    }

    let path = PathBuf::from(trimmed);
    if is_url_like(trimmed) || path.is_absolute() || trimmed.contains(':') {
        Some(path)
    } else {
        Some(base_dir.join(path))
    }
}

fn is_url_like(value: &str) -> bool {
    value.contains("://") || value.starts_with("//")
}
