// SPDX-License-Identifier: MIT OR Apache-2.0

use super::State;
use anyhow::{ensure, Context, Result};
use fs2::FileExt;
use std::{
    fs::{File, OpenOptions},
    io::Write,
    os::unix::fs::OpenOptionsExt,
    path::{Path, PathBuf},
    sync::{Arc, Mutex},
};
use tempfile::NamedTempFile;

/// The process lock covers the directory entry even when state.json is replaced.
pub struct Store {
    path: PathBuf,
    directory: File,
    cached: Mutex<Option<Arc<State>>>,
    _lock: File,
}

impl Store {
    fn lock(dir: &Path) -> Result<Self> {
        let directory = File::open(dir).context("open reader state directory")?;
        let lock = OpenOptions::new()
            .create(true)
            .truncate(false)
            .read(true)
            .write(true)
            .mode(0o600)
            .open(dir.join("reader.lock"))?;
        lock.try_lock_exclusive()
            .context("state is already in use")?;
        Ok(Self {
            path: dir.join("state.json"),
            directory,
            cached: Mutex::new(None),
            _lock: lock,
        })
    }

    /// Serving always requires an existing, valid state file.
    pub fn open(dir: &Path) -> Result<Self> {
        let store = Self::lock(dir)?;
        store.snapshot()?;
        Ok(store)
    }

    pub fn create(dir: &Path, init: impl FnOnce() -> Result<State>) -> Result<Self> {
        let mut store = Self::lock(dir)?;
        ensure!(!store.path.try_exists()?, "destination already initialized");
        let mut state = init()?;
        state.reconcile_hap_grants(false)?;
        state.validate()?;
        store.stage(&state)?.persist_noclobber(&store.path)?;
        store.directory.sync_all()?;
        *store.cached.get_mut().expect("state lock poisoned") = Some(Arc::new(state));
        Ok(store)
    }

    fn stage(&self, state: &State) -> Result<NamedTempFile> {
        let mut tmp = NamedTempFile::new_in(self.path.parent().expect("state file has a parent"))?;
        serde_json::to_writer(&mut tmp, state)?;
        tmp.flush()?;
        tmp.as_file().sync_all()?;
        Ok(tmp)
    }

    fn replace(&self, state: &State) -> Result<()> {
        self.stage(state)?.persist(&self.path)?;
        self.directory
            .sync_all()
            .context("sync reader state directory")
    }

    fn current<'a>(&self, cache: &'a mut Option<Arc<State>>) -> Result<&'a Arc<State>> {
        if let Some(state) = cache {
            return Ok(state);
        }
        // A previous rename may have succeeded before the directory sync failed.
        // Establish durability and read the visible file before authorizing again.
        self.directory
            .sync_all()
            .context("sync reader state directory")?;
        let file = File::open(&self.path).context("open existing reader state")?;
        let mut state: State = serde_json::from_reader(file)?;
        let reconciled = state.reconcile_hap_grants(false)?;
        state.validate()?;
        if reconciled {
            self.replace(&state)?;
        }
        Ok(cache.insert(Arc::new(state)))
    }

    pub fn snapshot(&self) -> Result<Arc<State>> {
        let mut cache = self.cached.lock().expect("state lock poisoned");
        Ok(Arc::clone(self.current(&mut cache)?))
    }

    pub fn update<T>(&self, change: impl FnOnce(&mut State) -> Result<T>) -> Result<T> {
        let mut cache = self.cached.lock().expect("state lock poisoned");
        let current = self.current(&mut cache)?.as_ref();
        let mut next = current.clone();
        let result = change(&mut next)?;
        if next != *current {
            next.revision = current
                .revision
                .checked_add(1)
                .context("revision overflow")?;
            next.validate()?;
            *cache = None;
            self.replace(&next)?;
            *cache = Some(Arc::new(next));
        }
        Ok(result)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::{os::fd::OwnedFd, os::unix::net::UnixStream};

    #[test]
    fn exclusive_create_and_failed_transaction_preserve_identity() -> Result<()> {
        let dir = tempfile::tempdir()?;
        assert!(Store::open(dir.path()).is_err());
        let store = Store::create(dir.path(), || Ok(State::fresh()))?;
        let before = store.snapshot()?;
        assert!(Store::open(dir.path()).is_err());
        assert!(store
            .update(|s| {
                s.hap.accessory.public_key.clear();
                Ok(())
            })
            .is_err());
        drop(store);
        assert!(Store::create(dir.path(), || panic!("must not import again")).is_err());
        let reopened = Store::open(dir.path())?;
        assert_eq!(
            reopened.snapshot()?.hap.accessory.public_key,
            before.hap.accessory.public_key
        );
        Ok(())
    }

    #[test]
    fn failed_directory_sync_blocks_access_until_the_replacement_is_reloaded() -> Result<()> {
        let dir = tempfile::tempdir()?;
        let mut store = Store::create(dir.path(), || Ok(State::fresh()))?;
        let before = store.snapshot()?;
        // fsync on a socket fails while writing and renaming the actual file succeeds.
        let socket = OwnedFd::from(UnixStream::pair()?.0);
        let directory = std::mem::replace(&mut store.directory, File::from(socket));
        assert!(store
            .update(|s| {
                s.hap.accessory.config_version += 1;
                Ok(())
            })
            .is_err());
        let on_disk: State = serde_json::from_reader(File::open(&store.path)?)?;
        assert_eq!(on_disk.revision, before.revision + 1);
        assert!(store.snapshot().is_err());
        assert!(store
            .update::<()>(|_| panic!("stale state reached a writer"))
            .is_err());
        store.directory = directory;
        let current = store.snapshot()?;
        assert_eq!(current.revision, on_disk.revision);
        assert_eq!(
            current.hap.accessory.config_version,
            before.hap.accessory.config_version + 1
        );
        Ok(())
    }
}
