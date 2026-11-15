# Berkeley DB version

Every CorgiCoin build links **Berkeley DB 4.8.30**, built from source by `contrib/build-bdb48.sh` (static, checksum pinned). Windows
always did; Linux and macOS builds used the distribution's or Homebrew's version (5.3 and 18.x) until this change.

Why one version: a database environment or index file made by a newer BDB cannot be opened by 4.8, while 4.8's can be opened by the
newer ones. A wallet moved between platforms built on different versions could fail to open.

## Moving to a build with 4.8 from one built with 5.3 or later (Linux, macOS)

Checked on Ubuntu 24.04 with the 5.3 build and the 4.8 build:

* `wallet.dat` itself opens in 4.8 once the old environment is out of the way.
* `blkindex.dat` and the `database/` directory do not (`DB_RUNRECOVERY`, "error 22").

So, once, with the old version stopped:

1. Copy `wallet.dat` somewhere safe (and `dumpwallet` to a file if the wallet is unlocked and you want a second copy).
2. Delete `database/`, `db.log` and `blkindex.dat` from the data directory. Keep `wallet.dat` and the `blk*.dat` files.
3. Start the new version with `-reindex`. It rebuilds the block index from the block files.

A new data directory (a fresh install) needs none of this. Going from 4.8 to a build that uses 5.3 or later works without any step
(the newer versions read 4.8's files), but the files are then upgraded and 4.8 cannot read them again.
