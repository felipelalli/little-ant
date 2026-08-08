use age::secrecy::SecretString;
use std::cell::RefCell;
use std::io::{Read, Write};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::ptr;
use std::slice;
use zeroize::Zeroize;

thread_local! {
    static LAST_ERROR: RefCell<String> = const { RefCell::new(String::new()) };
}

const OK: i32 = 0;
const INVALID_INPUT: i32 = 1;
const ENCRYPTION_FAILED: i32 = 2;
const DECRYPTION_FAILED: i32 = 3;
const PANIC_CAUGHT: i32 = 4;

fn set_error(message: impl Into<String>) {
    LAST_ERROR.with(|slot| *slot.borrow_mut() = message.into());
}

unsafe fn input<'a>(pointer: *const u8, length: usize) -> Result<&'a [u8], i32> {
    if length == 0 {
        return Ok(&[]);
    }
    if pointer.is_null() {
        set_error("null input pointer");
        return Err(INVALID_INPUT);
    }
    Ok(slice::from_raw_parts(pointer, length))
}

fn passphrase(pointer: *const u8, length: usize) -> Result<SecretString, i32> {
    let bytes = unsafe { input(pointer, length)? };
    if bytes.is_empty() {
        set_error("empty passphrase");
        return Err(INVALID_INPUT);
    }
    let owned = bytes.to_vec();
    match String::from_utf8(owned) {
        Ok(value) => Ok(SecretString::from(value)),
        Err(error) => {
            let mut rejected = error.into_bytes();
            rejected.zeroize();
            set_error("passphrase is not valid UTF-8");
            Err(INVALID_INPUT)
        }
    }
}

fn return_bytes(mut value: Vec<u8>, output: *mut *mut u8, output_len: *mut usize) -> i32 {
    if output.is_null() || output_len.is_null() {
        value.zeroize();
        set_error("null output pointer");
        return INVALID_INPUT;
    }
    let boxed = value.into_boxed_slice();
    let length = boxed.len();
    let pointer = Box::into_raw(boxed) as *mut u8;
    unsafe {
        *output = pointer;
        *output_len = length;
    }
    OK
}

#[no_mangle]
pub extern "C" fn lant_age_encrypt(
    passphrase_ptr: *const u8,
    passphrase_len: usize,
    plaintext_ptr: *const u8,
    plaintext_len: usize,
    output: *mut *mut u8,
    output_len: *mut usize,
) -> i32 {
    match catch_unwind(AssertUnwindSafe(|| {
        let secret = passphrase(passphrase_ptr, passphrase_len)?;
        let plaintext = unsafe { input(plaintext_ptr, plaintext_len)? };
        let mut recipient = age::scrypt::Recipient::new(secret);
        recipient.set_work_factor(18);
        let encryptor =
            age::Encryptor::with_recipients(std::iter::once(&recipient as &dyn age::Recipient))
                .map_err(|error| {
                    set_error(format!("age encryption setup failed: {error}"));
                    ENCRYPTION_FAILED
                })?;
        let mut ciphertext = Vec::new();
        {
            let mut writer = encryptor.wrap_output(&mut ciphertext).map_err(|error| {
                set_error(format!("age encryption setup failed: {error}"));
                ENCRYPTION_FAILED
            })?;
            writer.write_all(plaintext).map_err(|error| {
                set_error(format!("age encryption failed: {error}"));
                ENCRYPTION_FAILED
            })?;
            writer.finish().map_err(|error| {
                set_error(format!("age encryption finalization failed: {error}"));
                ENCRYPTION_FAILED
            })?;
        }
        Ok(return_bytes(ciphertext, output, output_len))
    })) {
        Ok(Ok(code)) => code,
        Ok(Err(code)) => code,
        Err(_) => {
            set_error("age backend panicked");
            PANIC_CAUGHT
        }
    }
}

#[no_mangle]
pub extern "C" fn lant_age_decrypt(
    passphrase_ptr: *const u8,
    passphrase_len: usize,
    ciphertext_ptr: *const u8,
    ciphertext_len: usize,
    output: *mut *mut u8,
    output_len: *mut usize,
) -> i32 {
    match catch_unwind(AssertUnwindSafe(|| {
        let secret = passphrase(passphrase_ptr, passphrase_len)?;
        let ciphertext = unsafe { input(ciphertext_ptr, ciphertext_len)? };
        let decryptor = age::Decryptor::new(ciphertext).map_err(|error| {
            set_error(format!("invalid age ciphertext: {error}"));
            DECRYPTION_FAILED
        })?;
        let mut identity = age::scrypt::Identity::new(secret);
        identity.set_max_work_factor(18);
        let mut reader = decryptor
            .decrypt(std::iter::once(&identity as &dyn age::Identity))
            .map_err(|error| {
                set_error(format!("age decryption failed: {error}"));
                DECRYPTION_FAILED
            })?;
        let mut plaintext = Vec::new();
        reader.read_to_end(&mut plaintext).map_err(|error| {
            set_error(format!("age payload read failed: {error}"));
            DECRYPTION_FAILED
        })?;
        Ok(return_bytes(plaintext, output, output_len))
    })) {
        Ok(Ok(code)) => code,
        Ok(Err(code)) => code,
        Err(_) => {
            set_error("age backend panicked");
            PANIC_CAUGHT
        }
    }
}

#[no_mangle]
pub extern "C" fn lant_age_free(pointer: *mut u8, length: usize) {
    if pointer.is_null() {
        return;
    }
    unsafe {
        let raw = ptr::slice_from_raw_parts_mut(pointer, length);
        let mut value = Box::from_raw(raw);
        value.zeroize();
    }
}

#[no_mangle]
pub extern "C" fn lant_age_last_error(buffer: *mut u8, capacity: usize) -> usize {
    LAST_ERROR.with(|slot| {
        let message = slot.borrow();
        let bytes = message.as_bytes();
        let count = bytes.len().min(capacity);
        if count > 0 && !buffer.is_null() {
            unsafe { ptr::copy_nonoverlapping(bytes.as_ptr(), buffer, count) };
        }
        bytes.len()
    })
}
