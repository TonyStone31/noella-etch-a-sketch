{ A one-file fix for a name that does not match itself.

  CryptoLib4Pascal's own ClpECC.pas asks for a unit called
  ClpIPreCompCallback.  The file that answers to that name on disk is
  ClpIPreCompCallBack.pas - a capital B in "Back" that the file on disk has
  and the uses clause does not.  Pascal identifiers are case-insensitive, so
  the two spellings are the same unit as far as the language is concerned,
  and this builds without complaint on Windows, where the filesystem agrees.
  On Linux it does not: FPC opens files by the exact name it is given, so
  the unit is "not found" - not broken, just spelled two ways at once by
  its own author.

  This is that file, spelled the other way, so a build here finds a
  ClpIPreCompCallback on the very first line and never goes looking for the
  real one.  It is listed in etchasketch.lpi's search paths ahead of
  CryptoLib4Pascal's own Interfaces folder for exactly that reason - see the
  note there.

  The three lines that matter are copied from Xor-el's original, MIT,
  unchanged in substance.  See ../README.md. }
unit ClpIPreCompCallback;

{$I ../Include/CryptoLib.inc}

interface

uses
  ClpIPreCompInfo;

type
  IPreCompCallback = interface(IInterface)
    ['{3C0F2A0E-B396-4F0A-82B4-690F204D27ED}']
    function Precompute(const existing: IPreCompInfo): IPreCompInfo;
  end;

implementation

end.
