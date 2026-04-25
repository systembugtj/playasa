use std::fs;
use std::path::Path;

#[cfg(windows)]
use std::ffi::OsString;
#[cfg(windows)]
use std::os::windows::ffi::OsStringExt;

const WCHAR_PATH_LIMIT: usize = 32768;

pub(crate) fn read_text_lossy(path: &Path) -> std::io::Result<String> {
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

#[cfg(windows)]
pub(crate) unsafe fn wide_path_from_ptr(path: *const u16) -> Result<std::path::PathBuf, ()> {
    if path.is_null() {
        return Err(());
    }

    let mut len = 0usize;
    while len < WCHAR_PATH_LIMIT {
        if *path.add(len) == 0 {
            let wide = std::slice::from_raw_parts(path, len);
            return Ok(std::path::PathBuf::from(OsString::from_wide(wide)));
        }
        len += 1;
    }

    Err(())
}

#[cfg(not(windows))]
pub(crate) unsafe fn wide_path_from_ptr(_path: *const u16) -> Result<std::path::PathBuf, ()> {
    Err(())
}
