use std::path::PathBuf;

#[cfg(windows)]
use std::ffi::OsString;
#[cfg(windows)]
use std::os::windows::ffi::OsStringExt;

const WCHAR_PATH_LIMIT: usize = 32768;

#[cfg(windows)]
pub(crate) unsafe fn wide_path_from_ptr(path: *const u16) -> Result<PathBuf, ()> {
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
pub(crate) unsafe fn wide_path_from_ptr(_path: *const u16) -> Result<PathBuf, ()> {
    Err(())
}
