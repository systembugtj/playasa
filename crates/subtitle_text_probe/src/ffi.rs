use std::panic::{catch_unwind, AssertUnwindSafe};

use crate::path::wide_path_from_ptr;
use crate::probe::{probe_file, ProbeResult};

#[repr(C)]
pub struct PlayasaSubtitleTextProbe {
    pub encoding: i32,
    pub format_hint: i32,
    pub confidence: i32,
}

impl From<ProbeResult> for PlayasaSubtitleTextProbe {
    fn from(result: ProbeResult) -> Self {
        Self {
            encoding: result.encoding,
            format_hint: result.format_hint,
            confidence: result.confidence,
        }
    }
}

#[no_mangle]
pub extern "C" fn playasa_subtitle_probe_text(path: *const u16) -> PlayasaSubtitleTextProbe {
    let result = catch_unwind(AssertUnwindSafe(|| unsafe { probe_text_impl(path) }));

    match result {
        Ok(probe) => probe,
        Err(_) => empty_probe(),
    }
}

unsafe fn probe_text_impl(path: *const u16) -> PlayasaSubtitleTextProbe {
    if path.is_null() {
        return empty_probe();
    }

    wide_path_from_ptr(path)
        .ok()
        .and_then(|path| probe_file(&path).ok())
        .map(PlayasaSubtitleTextProbe::from)
        .unwrap_or_else(empty_probe)
}

fn empty_probe() -> PlayasaSubtitleTextProbe {
    PlayasaSubtitleTextProbe {
        encoding: 0,
        format_hint: 0,
        confidence: 0,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_null_path() {
        let result = playasa_subtitle_probe_text(std::ptr::null());
        assert_eq!(result.encoding, 0);
        assert_eq!(result.format_hint, 0);
        assert_eq!(result.confidence, 0);
    }
}
