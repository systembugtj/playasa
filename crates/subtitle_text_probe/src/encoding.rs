pub(crate) const ENCODING_UNKNOWN: i32 = 0;
pub(crate) const ENCODING_UTF8: i32 = 1;
pub(crate) const ENCODING_UTF8_BOM: i32 = 2;
pub(crate) const ENCODING_UTF16_LE: i32 = 3;
pub(crate) const ENCODING_UTF16_BE: i32 = 4;

const UTF8_BOM: &[u8] = &[0xef, 0xbb, 0xbf];
const UTF16_LE_BOM: &[u8] = &[0xff, 0xfe];
const UTF16_BE_BOM: &[u8] = &[0xfe, 0xff];

pub(crate) fn detect_encoding(bytes: &[u8]) -> (i32, i32) {
    if bytes.starts_with(UTF8_BOM) {
        return (ENCODING_UTF8_BOM, 100);
    }
    if bytes.starts_with(UTF16_LE_BOM) {
        return (ENCODING_UTF16_LE, 100);
    }
    if bytes.starts_with(UTF16_BE_BOM) {
        return (ENCODING_UTF16_BE, 100);
    }
    if bytes.is_empty() {
        return (ENCODING_UNKNOWN, 0);
    }
    if std::str::from_utf8(bytes).is_ok() {
        return (ENCODING_UTF8, utf8_confidence(bytes));
    }

    (ENCODING_UNKNOWN, 0)
}

fn utf8_confidence(bytes: &[u8]) -> i32 {
    if bytes.iter().all(u8::is_ascii) {
        80
    } else {
        95
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn detects_boms_and_utf8() {
        assert_eq!(detect_encoding(b"\xef\xbb\xbfWEBVTT").0, ENCODING_UTF8_BOM);
        assert_eq!(detect_encoding(b"\xff\xfe\0\0").0, ENCODING_UTF16_LE);
        assert_eq!(detect_encoding(b"\xfe\xff\0\0").0, ENCODING_UTF16_BE);
        assert_eq!(detect_encoding("字幕".as_bytes()).0, ENCODING_UTF8);
    }

    #[test]
    fn rejects_invalid_utf8() {
        assert_eq!(detect_encoding(&[0xff, 0xff]).0, ENCODING_UNKNOWN);
    }
}
