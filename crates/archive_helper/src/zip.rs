use std::fs::File;
use std::path::{Component, Path};

use zip::ZipArchive;

pub(crate) fn list_zip_entries(path: &Path) -> Result<Vec<String>, ()> {
    let file = File::open(path).map_err(|_| ())?;
    let mut archive = ZipArchive::new(file).map_err(|_| ())?;
    let mut entries = Vec::new();

    for index in 0..archive.len() {
        let entry = archive.by_index(index).map_err(|_| ())?;
        if entry.is_dir() {
            continue;
        }

        let enclosed = entry.enclosed_name().ok_or(())?;
        entries.push(path_to_archive_name(&enclosed)?);
    }

    Ok(entries)
}

fn path_to_archive_name(path: &Path) -> Result<String, ()> {
    let mut parts = Vec::new();
    for component in path.components() {
        match component {
            Component::Normal(part) => parts.push(part.to_str().ok_or(())?),
            Component::CurDir => {}
            _ => return Err(()),
        }
    }

    if parts.is_empty() {
        return Err(());
    }

    Ok(parts.join("/"))
}

#[cfg(test)]
pub(crate) fn list_zip_entries_from_reader<R>(reader: R) -> Result<Vec<String>, ()>
where
    R: std::io::Read + std::io::Seek,
{
    let mut archive = ZipArchive::new(reader).map_err(|_| ())?;
    let mut entries = Vec::new();

    for index in 0..archive.len() {
        let entry = archive.by_index(index).map_err(|_| ())?;
        if entry.is_dir() {
            continue;
        }

        let enclosed = entry.enclosed_name().ok_or(())?;
        entries.push(path_to_archive_name(&enclosed)?);
    }

    Ok(entries)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::{Cursor, Write};
    use zip::write::SimpleFileOptions;
    use zip::ZipWriter;

    #[test]
    fn lists_regular_and_nested_files() {
        let mut bytes = Cursor::new(Vec::new());
        {
            let mut writer = ZipWriter::new(&mut bytes);
            writer
                .start_file("movie.mp4", SimpleFileOptions::default())
                .expect("start movie");
            writer.write_all(b"movie").expect("write movie");
            writer
                .start_file("subs/movie.srt", SimpleFileOptions::default())
                .expect("start subtitle");
            writer.write_all(b"subtitle").expect("write subtitle");
            writer.finish().expect("finish zip");
        }

        bytes.set_position(0);
        let entries = list_zip_entries_from_reader(bytes).expect("list zip");
        assert_eq!(entries, vec!["movie.mp4", "subs/movie.srt"]);
    }

    #[test]
    fn lists_empty_zip() {
        let mut bytes = Cursor::new(Vec::new());
        {
            let writer = ZipWriter::new(&mut bytes);
            writer.finish().expect("finish empty zip");
        }

        bytes.set_position(0);
        let entries = list_zip_entries_from_reader(bytes).expect("list empty zip");
        assert!(entries.is_empty());
    }

    #[test]
    fn rejects_damaged_zip() {
        let bytes = Cursor::new(b"not a zip".to_vec());
        assert!(list_zip_entries_from_reader(bytes).is_err());
    }

    #[test]
    fn rejects_traversal_entries() {
        let mut bytes = Cursor::new(Vec::new());
        {
            let mut writer = ZipWriter::new(&mut bytes);
            writer
                .start_file("../evil.mp4", SimpleFileOptions::default())
                .expect("start evil");
            writer.write_all(b"evil").expect("write evil");
            writer.finish().expect("finish zip");
        }

        bytes.set_position(0);
        assert!(list_zip_entries_from_reader(bytes).is_err());
    }
}
