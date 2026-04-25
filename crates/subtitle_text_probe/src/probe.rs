use std::fs::File;
use std::io::{self, Read};
use std::path::Path;

use crate::encoding::detect_encoding;
use crate::format::detect_format;

const PROBE_READ_LIMIT: usize = 64 * 1024;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(crate) struct ProbeResult {
    pub(crate) encoding: i32,
    pub(crate) format_hint: i32,
    pub(crate) confidence: i32,
}

pub(crate) fn probe_bytes(bytes: &[u8]) -> ProbeResult {
    let (encoding, encoding_confidence) = detect_encoding(bytes);
    let (format_hint, format_confidence) = detect_format(bytes);

    ProbeResult {
        encoding,
        format_hint,
        confidence: encoding_confidence.max(format_confidence),
    }
}

pub(crate) fn probe_file(path: &Path) -> io::Result<ProbeResult> {
    let mut file = File::open(path)?;
    let mut bytes = Vec::with_capacity(PROBE_READ_LIMIT);
    file.by_ref()
        .take(PROBE_READ_LIMIT as u64)
        .read_to_end(&mut bytes)?;
    Ok(probe_bytes(&bytes))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::encoding::{ENCODING_UNKNOWN, ENCODING_UTF16_LE, ENCODING_UTF8};
    use crate::format::{FORMAT_SRT, FORMAT_UNKNOWN, FORMAT_WEBVTT};

    #[test]
    fn probes_utf8_srt_bytes() {
        let result = probe_bytes(b"1\n00:00:01,000 --> 00:00:02,000\nHi");
        assert_eq!(result.encoding, ENCODING_UTF8);
        assert_eq!(result.format_hint, FORMAT_SRT);
        assert!(result.confidence >= 90);
    }

    #[test]
    fn probes_utf16_bom_without_format_guess() {
        let result = probe_bytes(b"\xff\xfe1\0");
        assert_eq!(result.encoding, ENCODING_UTF16_LE);
        assert_eq!(result.format_hint, FORMAT_UNKNOWN);
        assert_eq!(result.confidence, 100);
    }

    #[test]
    fn reports_unknown_for_binary_data() {
        let result = probe_bytes(&[0xff, 0x00, 0xfe, 0x00]);
        assert_eq!(result.encoding, ENCODING_UNKNOWN);
    }

    #[test]
    fn probes_webvtt_bytes() {
        let result = probe_bytes(b"WEBVTT\n\n00:00.000 --> 00:01.000\nHi");
        assert_eq!(result.format_hint, FORMAT_WEBVTT);
    }
}
