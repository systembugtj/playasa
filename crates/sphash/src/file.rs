use std::fs::File;
use std::io::{self, Read};
use std::path::PathBuf;

use crate::md5::{digest_hex, Md5Context};

const READ_BUFFER_LEN: usize = 64 * 1024;

pub(crate) fn md5_file_hex(path: PathBuf) -> io::Result<String> {
    let mut file = File::open(path)?;
    let mut context = Md5Context::new();
    let mut buffer = [0u8; READ_BUFFER_LEN];

    loop {
        let bytes_read = file.read(&mut buffer)?;
        if bytes_read == 0 {
            break;
        }
        context.update(&buffer[..bytes_read]);
    }

    Ok(digest_hex(&context.finalize()))
}
