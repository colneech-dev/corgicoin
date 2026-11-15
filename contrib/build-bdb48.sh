#!/bin/sh
# Build Berkeley DB 4.8.30 as a static library into a prefix, the one BDB version every CorgiCoin release links so that a
# wallet.dat made on one platform opens on every other (5.x and later upgrade the database environment on open, and 4.8 then
# refuses it). Usage: contrib/build-bdb48.sh <prefix>
# Then: cmake .. -DBERKELEYDB_INCLUDE_DIR=<prefix>/include -DBERKELEYDB_LIBRARY=<prefix>/lib/libdb_cxx.a
set -e
PREFIX=${1:?usage: build-bdb48.sh <prefix>}
SHA256=e0491a07cdb21fb9aa82773bbbedaeb7639cbd0e7f96147ab46141e0045db72a
URL=https://download.oracle.com/berkeley-db/db-4.8.30.tar.gz
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
if command -v curl >/dev/null 2>&1; then curl -fsSL -o db.tar.gz "$URL"; else wget -q -O db.tar.gz "$URL"; fi
if command -v sha256sum >/dev/null 2>&1; then SUM=$(sha256sum db.tar.gz | cut -d' ' -f1); else SUM=$(shasum -a 256 db.tar.gz | cut -d' ' -f1); fi
[ "$SUM" = "$SHA256" ] || { echo "db-4.8.30.tar.gz has the wrong checksum: $SUM"; exit 1; }
tar xzf db.tar.gz
cd db-4.8.30
# the names clash with compiler builtins in gcc 5+ and clang
sed -i.old 's/__atomic_compare_exchange/__atomic_compare_exchange_db/' dbinc/atomic.h
sed -i.old 's/atomic_init/atomic_init_db/' dbinc/atomic.h mp/mp_region.c mp/mp_mvcc.c mp/mp_fget.c mutex/mut_method.c mutex/mut_tas.c
cd build_unix
# the 2009 config.guess does not know Apple silicon: say what it is
EXTRA=
case "$(uname -s)-$(uname -m)" in
    Darwin-arm64) EXTRA="--build=arm-apple-darwin" ;;
esac
../dist/configure --enable-cxx --disable-shared --disable-replication --with-pic --prefix="$PREFIX" $EXTRA
make -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)"
make install_lib install_include
ln -sf libdb_cxx-4.8.a "$PREFIX/lib/libdb_cxx.a"
ln -sf libdb-4.8.a "$PREFIX/lib/libdb.a"
echo "Berkeley DB 4.8.30 installed in $PREFIX"
