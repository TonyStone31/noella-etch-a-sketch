# Encrypting a report before it leaves the machine

A bug report goes to a public, unauthenticated postbox - a Filebin bin whose
address is itself published in this repository (`docs/bug-report-endpoint.json`)
so the program never needs a server of its own.  That address, and every one
it has ever had, sits in git history forever.  Filebin bins have no login:
anyone who has the address can read what is in one, for as long as it lives.

So the report is encrypted before it is uploaded, to a key only the
collector holds.  The bin can be as public as it likes; what is in it is
not.

## What is here

| | |
|---|---|
| `uReportCrypto.pas` | ours - the public key, and the one function the shipped program calls: `EncryptReportBytes`. |
| `vendor-fixes/` | one file, and why it exists - see below. |

## Whose code this stands on

Not vendored - referenced as sibling clones, the same arrangement as
[LazInk](../README.md).  All three are Xor-el's, all three MIT:

* **[CryptoLib4Pascal](https://github.com/Xor-el/CryptoLib4Pascal)** - the
  actual cryptography.  ECIES - Elliptic Curve Integrated Encryption Scheme -
  built on real primitives (EC key agreement, AES, HMAC), tested against
  known vectors.  This is not something to hand-roll, and there was no need
  to: it does the sealed-box pattern we want already.
* **[HashLib4Pascal](https://github.com/Xor-el/HashLib4Pascal)** - the
  digests CryptoLib4Pascal builds its HMAC and key derivation on.  A
  dependency of a dependency; nothing here calls it directly.
* **[SimpleBaseLib4Pascal](https://github.com/Xor-el/SimpleBaseLib4Pascal)** -
  base16/32/58/64 encoders CryptoLib4Pascal's ASN.1 layer wants.  Same
  relationship: pulled in, never called from here.

Clone all three next to this folder - `../CryptoLib4Pascal`,
`../HashLib4Pascal`, `../SimpleBaseLib4Pascal` - and `build.sh` finds them.
Nothing is shipped: these are FPC units, compiled into the one executable
like any other unit in this repository.  A user's copy of the program is
exactly as small as it always was.

## The one thing we had to fix to build it on Linux

`vendor-fixes/Interfaces/ClpIPreCompCallback.pas` exists because
CryptoLib4Pascal's own `ClpECC.pas` asks for a unit called
`ClpIPreCompCallback`, and the file that answers to that name on disk is
spelled `ClpIPreCompCallBack.pas` - a capital B in "Back" the `uses` clause
does not have.  Pascal identifiers are case-insensitive, so the two
spellings are the same unit to the compiler, and this builds without a
murmur on Windows, where the filesystem agrees with the compiler.  On Linux
it does not: FPC opens files by the exact name it is given, and the unit is
reported "not found" - not broken, just spelled two ways at once by its own
author.

The fix is the file spelled the other way, and it works only because of
where `etchasketch.lpi` puts it: `crypto/vendor-fixes/Interfaces` is listed
in the search path *ahead of* CryptoLib4Pascal's own `Interfaces` folder, so
a build finds our correctly-spelled copy first and never goes looking for
the real one.  Its two include files are trimmed copies of
`CryptoLib4Pascal/CryptoLib/src/Include/{CryptoLib,CryptoLibHelper}.inc` -
kept to what a Linux/FPC build actually reads, MIT, Xor-el's - which the
shim needs beside it because its own `{$I ../Include/...}` line has to find
something.

Worth reporting upstream; hasn't been yet.  Nothing here depends on that -
if it is ever fixed there, this file becomes dead weight that can be
deleted, and nothing else changes.

## How a report actually travels

1. The program builds the report exactly as it always has - the text body,
   and the screenshot, if any.
2. `uReport.SendReport` / `SendBinary` hand each one to
   `EncryptReportBytes` before it goes on the wire.  ECIES, ephemeral key
   per message, AES-256-CBC, HMAC-SHA-256 - a sealed box: anyone can write
   to it, using the public key baked into every copy of this program, and
   only the private key opens it.
3. What lands in the bin is opaque.  The bin's address being public costs
   nothing now.
4. The collector (`tools/fetch-reports.pas`, never published - see its own
   header) tries to decrypt what it fetches with the private key it holds
   locally, before any of its existing checks run.  A report from an
   up-to-date program decrypts and is validated exactly as before, on the
   plaintext.  Anything that does not decrypt falls back to the collector's
   old plain-text path, so a report already in flight when this shipped is
   not simply lost.

**What this changes and what it does not.**  This is confidentiality, not
authentication.  The public key ships in every binary and is trivial to
read out of one, so encrypting something to it proves nothing about who
sent it - a targeted, deliberate abuser can encrypt garbage exactly as
easily as a real report, and it will decrypt just fine and meet the
collector's existing content checks exactly as before.  What this buys is
narrower and still worth having: nobody but the collector can read what a
legitimate report says while it sits in a bin whose address is, and always
will be, public.  The MAC does mean a corrupted or merely-guessed-at
ciphertext fails to decrypt at all, which quietly drops accidental noise
that never went through real encryption - but that is a side effect, not
the point.

## The keys

Generated once by `tools/reportkeygen.pas` (never published, like the
collector).  The public half is a 33-byte compressed point, pasted into
`uReportCrypto.pas` as a constant - fine to be as public as the source code
it sits in.  The private half decrypts every report ever sent and lives
only where the collector runs; losing it means every future report is
unreadable, and there is no second copy to fall back on.
