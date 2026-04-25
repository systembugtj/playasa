use crate::paths::encode_path;
use std::path::{Path, PathBuf};

pub(crate) const MPC_KEY_TYPE: i32 = 1;
pub(crate) const MPC_KEY_LABEL: i32 = 2;
pub(crate) const MPC_KEY_FILENAME: i32 = 3;
pub(crate) const MPC_KEY_SUBTITLE: i32 = 4;
pub(crate) const MPC_KEY_VIDEO: i32 = 5;
pub(crate) const MPC_KEY_AUDIO: i32 = 6;
pub(crate) const MPC_KEY_VINPUT: i32 = 7;
pub(crate) const MPC_KEY_VCHANNEL: i32 = 8;
pub(crate) const MPC_KEY_AINPUT: i32 = 9;
pub(crate) const MPC_KEY_COUNTRY: i32 = 10;

pub(crate) struct OwnedMpcField {
    pub(crate) index: i32,
    pub(crate) key: i32,
    pub(crate) value: Option<Vec<u16>>,
    pub(crate) number: i64,
}

impl OwnedMpcField {
    fn text(index: i32, key: i32, value: String) -> Self {
        Self {
            index,
            key,
            value: Some(value.encode_utf16().collect()),
            number: 0,
        }
    }

    fn path(index: i32, key: i32, value: PathBuf) -> Self {
        Self {
            index,
            key,
            value: Some(encode_path(&value)),
            number: 0,
        }
    }

    fn number(index: i32, key: i32, value: &str) -> Self {
        Self {
            index,
            key,
            value: None,
            number: value.parse::<i64>().unwrap_or(0),
        }
    }
}

pub(crate) fn parse_mpc_text(text: &str, mpc_path: &Path) -> Vec<OwnedMpcField> {
    let mut lines = text.lines();
    if lines.next() != Some("MPCPLAYLIST") {
        return Vec::new();
    }

    let base_dir = mpc_path.parent().unwrap_or_else(|| Path::new(""));
    lines
        .filter_map(|line| parse_mpc_line(line, base_dir))
        .collect()
}

fn parse_mpc_line(line: &str, base_dir: &Path) -> Option<OwnedMpcField> {
    let mut parts = line.splitn(3, ',');
    let index = parts.next()?.parse::<i32>().ok()?;
    let key = parts.next()?;
    let value = parts.next()?.trim_end_matches('\r');
    if index == 0 {
        return None;
    }

    match key {
        "type" => Some(OwnedMpcField::number(index, MPC_KEY_TYPE, value)),
        "label" => Some(OwnedMpcField::text(index, MPC_KEY_LABEL, value.to_owned())),
        "filename" => Some(OwnedMpcField::path(
            index,
            MPC_KEY_FILENAME,
            resolve_mpc_path(base_dir, value),
        )),
        "subtitle" => Some(OwnedMpcField::path(
            index,
            MPC_KEY_SUBTITLE,
            resolve_mpc_path(base_dir, value),
        )),
        "video" => Some(OwnedMpcField::text(index, MPC_KEY_VIDEO, value.to_owned())),
        "audio" => Some(OwnedMpcField::text(index, MPC_KEY_AUDIO, value.to_owned())),
        "vinput" => Some(OwnedMpcField::number(index, MPC_KEY_VINPUT, value)),
        "vchannel" => Some(OwnedMpcField::number(index, MPC_KEY_VCHANNEL, value)),
        "ainput" => Some(OwnedMpcField::number(index, MPC_KEY_AINPUT, value)),
        "country" => Some(OwnedMpcField::number(index, MPC_KEY_COUNTRY, value)),
        _ => None,
    }
}

fn resolve_mpc_path(base_dir: &Path, value: &str) -> PathBuf {
    let path = PathBuf::from(value);
    if path.is_absolute() || value.contains(':') {
        path
    } else {
        base_dir.join(path)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_mpc_playlist_fields() {
        let mpc = "MPCPLAYLIST\r\n1,type,0\r\n1,label,Sample\r\n1,filename,video.mp4\r\n1,subtitle,sub.srt\r\n1,vinput,2\r\n";
        let fields = parse_mpc_text(mpc, Path::new(r"C:\media\list.mpcpl"));

        assert_eq!(fields.len(), 5);
        assert_eq!(fields[0].index, 1);
        assert_eq!(fields[0].key, MPC_KEY_TYPE);
        assert_eq!(fields[0].number, 0);
        assert_eq!(fields[1].key, MPC_KEY_LABEL);
        assert_eq!(
            String::from_utf16(fields[1].value.as_ref().expect("label")).expect("utf16"),
            "Sample"
        );
        assert_eq!(fields[4].key, MPC_KEY_VINPUT);
        assert_eq!(fields[4].number, 2);
    }

    #[test]
    fn rejects_mpc_without_header() {
        let fields = parse_mpc_text("1,type,0\r\n", Path::new(r"C:\media\list.mpcpl"));
        assert!(fields.is_empty());
    }
}
