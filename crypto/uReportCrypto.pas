unit uReportCrypto;

{ A report, sealed to a key only the collector holds.

  The bin a report is uploaded to has no login: its address is published (it
  has to be - the program has no server of its own, see uReport.pas), and
  anyone who has that address can read whatever is sitting in it for as long
  as it lives.  So what goes in the bin is not the report - it is the report
  encrypted, and the address being public costs nothing.

  ECIES - Elliptic Curve Integrated Encryption Scheme, from CryptoLib4Pascal
  (Xor-el, MIT; see ../crypto/README.md for the whole arrangement, including
  the one file this project had to fix to build it on Linux).  A fresh
  ephemeral key pair is generated for every report, agreed with the one
  public key below to derive a one-time AES-256 key and HMAC-SHA-256 key,
  and the plaintext is never seen by anyone who does not hold the matching
  private key.  That key is not here and never will be - see below.

  The envelope this writes is [16-byte IV][ephemeral public key][AES-CBC
  ciphertext][HMAC tag], all four run together with no separators, because
  their lengths are all either fixed or self-describing to the reader on the
  other end.  Verified by round trip, and by feeding a corrupted envelope
  back through and confirming it is refused rather than silently accepted -
  see selftest.pas beside this. }

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

{ Encrypt Plain to the report collector's public key.  Never fails on valid
  input; returns an empty array only if something is fundamentally wrong
  with the library underneath (which selftest.pas exists to catch before it
  ever reaches here). }
function EncryptReportBytes(const Plain: TBytes): TBytes;

implementation

uses
  ClpECC, ClpIECC,
  ClpIHMac, ClpHMac,
  ClpIESEngine, ClpIIESEngine,
  ClpICipherParameters,
  ClpIECDHBasicAgreement, ClpECDHBasicAgreement,
  ClpParametersWithIV, ClpIParametersWithIV,
  ClpKdf2BytesGenerator, ClpIKdf2BytesGenerator,
  ClpECKeyPairGenerator, ClpIECKeyPairGenerator,
  ClpECKeyGenerationParameters, ClpIECKeyGenerationParameters,
  ClpECPublicKeyParameters, ClpIECPublicKeyParameters,
  ClpSecureRandom, ClpISecureRandom,
  ClpECDomainParameters, ClpIECDomainParameters,
  ClpIBufferedBlockCipher, ClpPaddedBufferedBlockCipher,
  ClpIESWithCipherParameters, ClpIIESWithCipherParameters,
  ClpEphemeralKeyPairGenerator, ClpIEphemeralKeyPairGenerator,
  ClpBlockCipherModes, ClpIBlockCipherModes,
  ClpKeyEncoder, ClpIKeyEncoder,
  ClpAesEngine, ClpIAesEngine,
  ClpDigestUtilities,
  ClpCustomNamedCurves, ClpIX9ECParameters;

const
  { secp256r1 (NIST P-256).  Any curve CryptoLib4Pascal's custom table
    resolves would do for what this needs; this is the one everything else
    calling itself "modern EC crypto" is also built on. }
  CURVE_NAME = 'secp256r1';

  { The collector's public key: a compressed EC point, 33 bytes, generated
    once by tools/reportkeygen.pas (never published, like the collector
    itself) and pasted here.  Public on purpose - this is the half that is
    supposed to be everywhere.  Whoever holds the matching private key,
    generated at the same time and kept only where the collector runs, is
    the only reader.

    Losing that private key does not un-write this constant - it would mean
    every report sent from that day on is sealed to a lock nobody has the
    key to any more.  There is no second copy of it anywhere. }
  REPORT_PUBLIC_KEY_HEX =
    '02F5DC2E1A3AEE051C6D39DB981EE1F65472AB9CF9E9B921EB079B684117C58FAE';

function HexToBytes(const S: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(S) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(S, I * 2 + 1, 2));
end;

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

function EncryptReportBytes(const Plain: TBytes): TBytes;
var
  X9: IX9ECParameters;
  Domain: IECDomainParameters;
  Q: IECPoint;
  Pub: IECPublicKeyParameters;
  Gen: IECKeyPairGenerator;
  EphGen: IEphemeralKeyPairGenerator;
  Eng: IIESEngine;
  Params: IIESWithCipherParameters;
  Rnd: ISecureRandom;
  IV, Body: TBytes;
begin
  Result := nil;
  try
    X9 := TCustomNamedCurves.GetByName(CURVE_NAME);
    if X9 = nil then Exit;
    Domain := TECDomainParameters.Create(X9.Curve, X9.G, X9.N, X9.H)
      as IECDomainParameters;

    Q := X9.Curve.DecodePoint(HexToBytes(REPORT_PUBLIC_KEY_HEX));
    Pub := TECPublicKeyParameters.Create(Q, Domain) as IECPublicKeyParameters;

    Gen := TECKeyPairGenerator.Create;
    Gen.Init(TECKeyGenerationParameters.Create(Domain,
      TSecureRandom.Create as ISecureRandom) as IECKeyGenerationParameters);
    { the point compressed, so a message costs 33 bytes for its ephemeral
      key rather than 65 - the reader on the other end knows the curve, so
      an X and a sign bit is all the point needs }
    EphGen := TEphemeralKeyPairGenerator.Create(Gen,
      TKeyEncoder.Create(True) as IKeyEncoder);

    Rnd := TSecureRandom.Create as ISecureRandom;
    SetLength(IV, 16);
    Rnd.NextBytes(IV);

    Eng := MakeEngine;
    { the derivation and encoding vectors are left nil: this is a sealed box
      between exactly two parties who already agree on everything the
      scheme needs, and there is nothing further to bind into the key
      derivation that either side could not already forge if they wanted to }
    Params := TIESWithCipherParameters.Create(nil, nil, 256, 256)
      as IIESWithCipherParameters;
    Eng.Init(Pub, TParametersWithIV.Create(Params, IV) as IParametersWithIV,
      EphGen);
    Body := Eng.ProcessBlock(Plain, 0, Length(Plain));

    SetLength(Result, Length(IV) + Length(Body));
    Move(IV[0], Result[0], Length(IV));
    if Length(Body) > 0 then
      Move(Body[0], Result[Length(IV)], Length(Body));
  except
    { encryption does not get to take a report down with it - see the note
      at the top of uReport.pas.  An empty result tells the caller to treat
      this report the way any other network failure is treated. }
    Result := nil;
  end;
end;

end.
