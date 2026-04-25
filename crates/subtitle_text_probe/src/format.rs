pub(crate) const FORMAT_UNKNOWN: i32 = 0;
pub(crate) const FORMAT_SRT: i32 = 1;
pub(crate) const FORMAT_ASS_SSA: i32 = 2;
pub(crate) const FORMAT_WEBVTT: i32 = 3;

pub(crate) fn detect_format(bytes: &[u8]) -> (i32, i32) {
    let text = String::from_utf8_lossy(strip_utf8_bom(bytes));
    let normalized = text.replace("\r\n", "\n").replace('\r', "\n");
    let trimmed = normalized.trim_start();

    if trimmed.starts_with("WEBVTT") {
        return (FORMAT_WEBVTT, 100);
    }
    if has_ass_header(trimmed) {
        return (FORMAT_ASS_SSA, 100);
    }
    if has_srt_timeline(trimmed) {
        return (FORMAT_SRT, 90);
    }

    (FORMAT_UNKNOWN, 0)
}

fn strip_utf8_bom(bytes: &[u8]) -> &[u8] {
    if bytes.starts_with(&[0xef, 0xbb, 0xbf]) {
        &bytes[3..]
    } else {
        bytes
    }
}

fn has_ass_header(text: &str) -> bool {
    text.lines().take(8).any(|line| {
        let line = line.trim();
        line.eq_ignore_ascii_case("[Script Info]")
            || line.eq_ignore_ascii_case("[V4 Styles]")
            || line.eq_ignore_ascii_case("[V4+ Styles]")
    })
}

fn has_srt_timeline(text: &str) -> bool {
    text.lines()
        .take(16)
        .any(|line| line.contains("-->") && line.contains(':') && line.contains(','))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn detects_common_subtitle_formats() {
        assert_eq!(
            detect_format(b"WEBVTT\n\n00:00.000 --> 00:01.000\nHi").0,
            FORMAT_WEBVTT
        );
        assert_eq!(
            detect_format(b"[Script Info]\nTitle: demo").0,
            FORMAT_ASS_SSA
        );
        assert_eq!(
            detect_format(b"1\n00:00:01,000 --> 00:00:02,000\nHi").0,
            FORMAT_SRT
        );
    }
}
