{ A trimmed copy, for the one file in vendor-fixes/ that needs an include of
  this name to sit right beside it.  The original is CryptoLib4Pascal's own
  Include/CryptoLib.inc (MIT, Xor-el) - this keeps only what a Linux/FPC
  build actually reads: the Delphi-compatibility mode switch, the checks
  off, pointer math on.  See ../README.md. }
{$IFDEF FPC}
{$I CryptoLibHelper.inc}
{$MODE delphi}
{$IF DEFINED(UNIX)}
   {$IF DEFINED(LINUX)}
      {$DEFINE CRYPTOLIB_HAS_GETRANDOM}
   {$IFEND}
{$IFEND}
{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}
{$POINTERMATH ON}
{$WARNINGS OFF}
{$HINTS OFF}
{$NOTES OFF}
{$ENDIF FPC}
