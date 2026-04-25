use std::ffi::{c_char, CStr};
use std::panic::{catch_unwind, AssertUnwindSafe};

use crate::file::md5_file_hex;
use crate::md5::{expected_hex_len, md5_hex};
use crate::path::wide_path_from_ptr;

const HASH_ALGO_MD5: i32 = 0;
const DIGEST_WITH_NUL_LEN: usize = 33;

#[no_mangle]
pub extern "C" fn hash_file(
    mode: *const c_char,
    algo: i32,
    path: *const u16,
    out: *mut c_char,
    len: *mut i32,
) {
    let result = catch_unwind(AssertUnwindSafe(|| unsafe {
        hash_file_impl(mode, algo, path, out, len)
    }));

    if result.is_err() {
        unsafe {
            write_failure(out, len);
        }
    }
}

#[no_mangle]
pub extern "C" fn hash_data(mode: *const c_char, algo: i32, buff: *mut c_char, len: *mut i32) {
    let result = catch_unwind(AssertUnwindSafe(|| unsafe {
        hash_data_impl(mode, algo, buff, len)
    }));

    if result.is_err() {
        unsafe {
            write_failure(buff, len);
        }
    }
}

#[no_mangle]
pub extern "C" fn hash_data_v2(
    mode: *const c_char,
    algo: i32,
    input: *const u8,
    input_len: i32,
    out: *mut c_char,
    out_len: *mut i32,
) {
    let result = catch_unwind(AssertUnwindSafe(|| unsafe {
        hash_data_v2_impl(mode, algo, input, input_len, out, out_len)
    }));

    if result.is_err() {
        unsafe {
            write_failure(out, out_len);
        }
    }
}

unsafe fn hash_file_impl(
    mode: *const c_char,
    algo: i32,
    path: *const u16,
    out: *mut c_char,
    len: *mut i32,
) {
    if !is_supported_request(mode, algo) || path.is_null() || out.is_null() || len.is_null() {
        write_failure(out, len);
        return;
    }

    match wide_path_from_ptr(path)
        .and_then(|path| md5_file_hex(path).map_err(|_| ()))
        .and_then(|hex| write_hex_output(&hex, out, len))
    {
        Ok(()) => {}
        Err(()) => write_failure(out, len),
    }
}

unsafe fn hash_data_impl(mode: *const c_char, algo: i32, buff: *mut c_char, len: *mut i32) {
    if !is_supported_request(mode, algo) || buff.is_null() || len.is_null() || *len < 0 {
        write_failure(buff, len);
        return;
    }

    // Legacy ABI uses `len` as the input byte count and reuses `buff` for the
    // 32-byte hex digest. Existing C++ callers allocate a much larger buffer.
    let input = std::slice::from_raw_parts(buff.cast::<u8>(), *len as usize);
    let hex = md5_hex(input);

    if write_hex_output(&hex, buff, len).is_err() {
        write_failure(buff, len);
    }
}

unsafe fn hash_data_v2_impl(
    mode: *const c_char,
    algo: i32,
    input: *const u8,
    input_len: i32,
    out: *mut c_char,
    out_len: *mut i32,
) {
    if !is_supported_request(mode, algo)
        || (input.is_null() && input_len != 0)
        || input_len < 0
        || out.is_null()
        || out_len.is_null()
        || *out_len < DIGEST_WITH_NUL_LEN as i32
    {
        write_failure(out, out_len);
        return;
    }

    let input = if input_len == 0 {
        &[]
    } else {
        std::slice::from_raw_parts(input, input_len as usize)
    };
    let hex = md5_hex(input);

    if write_hex_output(&hex, out, out_len).is_err() {
        write_failure(out, out_len);
    }
}

unsafe fn is_supported_request(mode: *const c_char, algo: i32) -> bool {
    if algo != HASH_ALGO_MD5 || mode.is_null() {
        return false;
    }

    CStr::from_ptr(mode)
        .to_bytes()
        .iter()
        .all(|byte| byte.is_ascii())
}

unsafe fn write_hex_output(hex: &str, out: *mut c_char, len: *mut i32) -> Result<(), ()> {
    let hex_len = expected_hex_len();
    if out.is_null() || len.is_null() || hex.len() != hex_len {
        return Err(());
    }

    std::ptr::copy_nonoverlapping(hex.as_ptr(), out.cast::<u8>(), hex_len);
    *out.add(hex_len) = 0;
    *len = hex_len as i32;
    Ok(())
}

unsafe fn write_failure(out: *mut c_char, len: *mut i32) {
    if !out.is_null() {
        *out = 0;
    }
    if !len.is_null() {
        *len = 0;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CString;

    #[test]
    fn hash_data_rewrites_buffer_with_digest() {
        let mode = CString::new("binary").expect("CString");
        let mut buffer = [0i8; 300];
        let input = b"abc";
        for (slot, byte) in buffer.iter_mut().zip(input) {
            *slot = *byte as i8;
        }
        let mut len = input.len() as i32;

        hash_data(mode.as_ptr(), HASH_ALGO_MD5, buffer.as_mut_ptr(), &mut len);

        let digest = unsafe { CStr::from_ptr(buffer.as_ptr()) }
            .to_str()
            .expect("valid digest");
        assert_eq!(len, expected_hex_len() as i32);
        assert_eq!(digest, "900150983cd24fb0d6963f7d28e17f72");
    }

    #[test]
    fn hash_data_rejects_unknown_algorithm() {
        let mode = CString::new("binary").expect("CString");
        let mut buffer = [b'a' as i8; 64];
        let mut len = 1i32;

        hash_data(mode.as_ptr(), 99, buffer.as_mut_ptr(), &mut len);

        assert_eq!(len, 0);
        assert_eq!(buffer[0], 0);
    }

    #[test]
    fn hash_data_v2_hashes_empty_input() {
        let mode = CString::new("binary").expect("CString");
        let mut out = [0i8; DIGEST_WITH_NUL_LEN];
        let mut out_len = out.len() as i32;

        hash_data_v2(
            mode.as_ptr(),
            HASH_ALGO_MD5,
            b"".as_ptr(),
            0,
            out.as_mut_ptr(),
            &mut out_len,
        );

        let digest = unsafe { CStr::from_ptr(out.as_ptr()) }
            .to_str()
            .expect("valid digest");
        assert_eq!(out_len, expected_hex_len() as i32);
        assert_eq!(digest, "d41d8cd98f00b204e9800998ecf8427e");
    }

    #[test]
    fn hash_data_v2_rejects_small_output_buffer() {
        let mode = CString::new("binary").expect("CString");
        let mut out = [b'x' as i8; 32];
        let mut out_len = out.len() as i32;

        hash_data_v2(
            mode.as_ptr(),
            HASH_ALGO_MD5,
            b"abc".as_ptr(),
            3,
            out.as_mut_ptr(),
            &mut out_len,
        );

        assert_eq!(out_len, 0);
        assert_eq!(out[0], 0);
    }

    #[test]
    fn hash_data_v2_rejects_null_input() {
        let mode = CString::new("binary").expect("CString");
        let mut out = [0i8; DIGEST_WITH_NUL_LEN];
        let mut out_len = out.len() as i32;

        hash_data_v2(
            mode.as_ptr(),
            HASH_ALGO_MD5,
            std::ptr::null(),
            3,
            out.as_mut_ptr(),
            &mut out_len,
        );

        assert_eq!(out_len, 0);
    }

    #[test]
    fn hash_data_v2_accepts_null_empty_input() {
        let mode = CString::new("binary").expect("CString");
        let mut out = [0i8; DIGEST_WITH_NUL_LEN];
        let mut out_len = out.len() as i32;

        hash_data_v2(
            mode.as_ptr(),
            HASH_ALGO_MD5,
            std::ptr::null(),
            0,
            out.as_mut_ptr(),
            &mut out_len,
        );

        let digest = unsafe { CStr::from_ptr(out.as_ptr()) }
            .to_str()
            .expect("valid digest");
        assert_eq!(out_len, expected_hex_len() as i32);
        assert_eq!(digest, "d41d8cd98f00b204e9800998ecf8427e");
    }

    #[cfg(windows)]
    #[test]
    fn hash_file_hashes_existing_file() {
        use std::io::Write;
        use std::os::windows::ffi::OsStrExt;

        let path = std::env::temp_dir().join("playasa_sphash_md5_test.txt");
        let mut file = std::fs::File::create(&path).expect("create temp file");
        file.write_all(b"abc").expect("write temp file");
        drop(file);

        let mode = CString::new("file").expect("CString");
        let mut wide: Vec<u16> = path.as_os_str().encode_wide().collect();
        wide.push(0);
        let mut out = [0i8; 64];
        let mut len = 0i32;

        hash_file(
            mode.as_ptr(),
            HASH_ALGO_MD5,
            wide.as_ptr(),
            out.as_mut_ptr(),
            &mut len,
        );

        let digest = unsafe { CStr::from_ptr(out.as_ptr()) }
            .to_str()
            .expect("valid digest");
        assert_eq!(len, expected_hex_len() as i32);
        assert_eq!(digest, "900150983cd24fb0d6963f7d28e17f72");

        std::fs::remove_file(path).expect("remove temp file");
    }
}
