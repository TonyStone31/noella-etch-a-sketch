program selftest;

{ Encrypts a few payloads with the real, shipped EncryptReportBytes, and -
  when a private key is given - decrypts them back and checks every byte,
  then corrupts one and checks that it is refused.  The decrypt half is
  written out here rather than as a unit, on purpose: nothing this project
  ships can decrypt a report, only this test tool, which is not published.

    selftest                          encrypt-only sanity checks
    selftest <private key hex>        the full round trip, and the tamper
                                       check - run this after regenerating
                                       keys, using the file reportkeygen
                                       wrote

  Run this whenever uReportCrypto.pas or the vendored library it stands on
  changes. }

{$mode objfpc}{$H+}

uses
  SysUtils,
  uReportCrypto,
  ClpECC, ClpIECC,
  ClpIHMac, ClpHMac,
  ClpIESEngine, ClpIIESEngine,
  ClpIECDHBasicAgreement, ClpECDHBasicAgreement,
  ClpParametersWithIV, ClpIParametersWithIV,
  ClpKdf2BytesGenerator, ClpIKdf2BytesGenerator,
  ClpECPrivateKeyParameters, ClpIECPrivateKeyParameters,
  ClpIESWithCipherParameters, ClpIIESWithCipherParameters,
  ClpECIESPublicKeyParser, ClpIECIESPublicKeyParser,
  ClpPaddedBufferedBlockCipher, ClpIBufferedBlockCipher,
  ClpBlockCipherModes, ClpIBlockCipherModes, ClpAesEngine, ClpIAesEngine,
  ClpDigestUtilities, ClpBigInteger,
  ClpECDomainParameters, ClpIECDomainParameters,
  ClpCustomNamedCurves, ClpIX9ECParameters;

function HexToBytes(const S: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(S) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(S, I * 2 + 1, 2));
end;

{ The mirror of EncryptReportBytes's engine setup - kept separate and
  duplicated on purpose, so a bug in one is not hidden by the same mistake
  in the other. }
function MakeEngine: IIESEngine;
begin
  Result := TIESEngine.Create(
    TECDHBasicAgreement.Create as IECDHBasicAgreement,
    TKdf2BytesGenerator.Create(TDigestUtilities.GetDigest('SHA-256'))
      as IKdf2BytesGenerator,
    THMac.Create(TDigestUtilities.GetDigest('SHA-256')) as IHMac,
    TPaddedBufferedBlockCipher.Create(TCbcBlockCipher.Create(
      TAesEngine.Create as IAesEngine) as ICbcBlockCipher)
      as IBufferedBlockCipher);
end;

function Decrypt(const PrivKeyBytes, Envelope: TBytes;
  out Plain: TBytes): Boolean;
var
  X9: IX9ECParameters;
  Domain: IECDomainParameters;
  D: TBigInteger;
  Priv: IECPrivateKeyParameters;
  Eng: IIESEngine;
  Params: IIESWithCipherParameters;
  IV, Body: TBytes;
begin
  Result := False;
  if Length(Envelope) < 16 then Exit;
  X9 := TCustomNamedCurves.GetByName('secp256r1');
  Domain := TECDomainParameters.Create(X9.Curve, X9.G, X9.N, X9.H)
    as IECDomainParameters;
  D := TBigInteger.Create(1, PrivKeyBytes);
  Priv := TECPrivateKeyParameters.Create(D, Domain) as IECPrivateKeyParameters;

  SetLength(IV, 16);
  Move(Envelope[0], IV[0], 16);
  SetLength(Body, Length(Envelope) - 16);
  if Length(Body) > 0 then Move(Envelope[16], Body[0], Length(Body));

  Eng := MakeEngine;
  Params := TIESWithCipherParameters.Create(nil, nil, 256, 256)
    as IIESWithCipherParameters;
  try
    Eng.Init(Priv, TParametersWithIV.Create(Params, IV) as IParametersWithIV,
      TECIESPublicKeyParser.Create(Domain) as IECIESPublicKeyParser);
    Plain := Eng.ProcessBlock(Body, 0, Length(Body));
    Result := True;
  except
    Result := False;
  end;
end;

var
  Fails: Integer;

procedure Check(Cond: Boolean; const What: string);
begin
  if Cond then WriteLn('  ok    ', What)
  else begin WriteLn('  FAIL  ', What); Inc(Fails); end;
end;

var
  Sizes: array[0..3] of Integer = (0, 1, 6000, 300000);
  I, J: Integer;
  Plain, Env, Back: TBytes;
  PrivKey: TBytes;
  HavePriv: Boolean;
begin
  Fails := 0;
  HavePriv := ParamCount >= 1;
  if HavePriv then PrivKey := HexToBytes(ParamStr(1));

  WriteLn('encrypt-only sanity:');
  for I := 0 to High(Sizes) do
  begin
    SetLength(Plain, Sizes[I]);
    for J := 0 to High(Plain) do Plain[J] := Byte(J mod 251);
    Env := EncryptReportBytes(Plain);
    Check(Length(Env) > Length(Plain), Format('%d bytes -> %d byte envelope',
      [Sizes[I], Length(Env)]));
    { two calls, same plaintext: the envelopes must differ - a fresh
      ephemeral key and a fresh IV every time, never reused }
    if Sizes[I] > 0 then
    begin
      Back := EncryptReportBytes(Plain);
      Check((Length(Back) <> Length(Env)) or not CompareMem(@Back[0],
        @Env[0], Length(Env)), 'two envelopes of the same plaintext differ');
    end;
  end;

  if not HavePriv then
  begin
    WriteLn('(no private key given - skipping the round trip.  Pass the ',
      'hex reportkeygen wrote to check it fully.)');
    Halt(Fails);
  end;

  WriteLn('round trip, with the real private key:');
  for I := 0 to High(Sizes) do
  begin
    SetLength(Plain, Sizes[I]);
    for J := 0 to High(Plain) do Plain[J] := Byte((J * 7 + 3) mod 251);
    Env := EncryptReportBytes(Plain);
    if not Decrypt(PrivKey, Env, Back) then
    begin
      Check(False, Format('%d bytes: decrypt raised', [Sizes[I]]));
      Continue;
    end;
    Check((Length(Back) = Length(Plain)) and
      ((Sizes[I] = 0) or CompareMem(@Back[0], @Plain[0], Length(Plain))),
      Format('%d bytes: round trip byte-exact', [Sizes[I]]));
  end;

  WriteLn('tamper check:');
  SetLength(Plain, 500);
  for J := 0 to High(Plain) do Plain[J] := Byte(J);
  Env := EncryptReportBytes(Plain);
  Env[High(Env)] := Env[High(Env)] xor $FF;   { inside the MAC tag }
  Check(not Decrypt(PrivKey, Env, Back), 'a corrupted envelope is refused');

  if Fails = 0 then WriteLn('all checks passed')
  else WriteLn(Fails, ' check(s) FAILED');
  Halt(Fails);
end.
