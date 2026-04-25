use std::panic::{catch_unwind, AssertUnwindSafe};

use crate::path::wide_path_from_ptr;
use crate::wide::encode_wide;
use crate::zip::list_zip_entries;

#[repr(C)]
pub struct PlayasaArchiveEntry {
    pub ptr: *const u16,
    pub len: usize,
}

#[repr(C)]
pub struct PlayasaArchiveEntryList {
    pub items: *mut PlayasaArchiveEntry,
    pub len: usize,
}

#[no_mangle]
pub extern "C" fn playasa_archive_list_zip(path: *const u16) -> PlayasaArchiveEntryList {
    let result = catch_unwind(AssertUnwindSafe(|| unsafe { list_zip_impl(path) }));

    match result {
        Ok(list) => list,
        Err(_) => empty_entry_list(),
    }
}

#[no_mangle]
pub extern "C" fn playasa_archive_free_entry_list(list: PlayasaArchiveEntryList) {
    let _ = catch_unwind(AssertUnwindSafe(|| unsafe {
        free_entry_list(list);
    }));
}

unsafe fn list_zip_impl(path: *const u16) -> PlayasaArchiveEntryList {
    if path.is_null() {
        return empty_entry_list();
    }

    wide_path_from_ptr(path)
        .ok()
        .and_then(|path| list_zip_entries(&path).ok())
        .map(to_entry_list)
        .unwrap_or_else(empty_entry_list)
}

fn to_entry_list(entries: Vec<String>) -> PlayasaArchiveEntryList {
    if entries.is_empty() {
        return empty_entry_list();
    }

    let mut ffi_entries = Vec::with_capacity(entries.len());
    for entry in entries {
        let wide = encode_wide(&entry);
        let leaked = Box::leak(wide);
        let len = leaked.len();
        let ptr = leaked.as_ptr();
        ffi_entries.push(PlayasaArchiveEntry { ptr, len });
    }

    let mut boxed = ffi_entries.into_boxed_slice();
    let len = boxed.len();
    let items = boxed.as_mut_ptr();
    std::mem::forget(boxed);

    PlayasaArchiveEntryList { items, len }
}

fn empty_entry_list() -> PlayasaArchiveEntryList {
    PlayasaArchiveEntryList {
        items: std::ptr::null_mut(),
        len: 0,
    }
}

unsafe fn free_entry_list(list: PlayasaArchiveEntryList) {
    if list.items.is_null() || list.len == 0 {
        return;
    }

    let entries = Box::from_raw(std::slice::from_raw_parts_mut(list.items, list.len));
    for entry in entries.iter() {
        if !entry.ptr.is_null() && entry.len > 0 {
            let slice = std::slice::from_raw_parts_mut(entry.ptr as *mut u16, entry.len);
            drop(Box::from_raw(slice));
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_null_path() {
        let list = playasa_archive_list_zip(std::ptr::null());
        assert!(list.items.is_null());
        assert_eq!(list.len, 0);
    }
}
