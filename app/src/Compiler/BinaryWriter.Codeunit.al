/// <summary>
/// Writes binary NAVX .app file headers and performs GUID-to-little-endian integer conversions.
/// Direct port of the proven NavxForge Binary Writer.
/// </summary>
codeunit 50102 "Binary Writer"
{
    Access = Public;

    /// <summary>
    /// Writes the 40-byte NAVX header to the output stream.
    /// Layout: NAVX magic (4B) + header_size=40 (4B) + version=2 (4B) +
    /// GUID bytes_le (16B) + zip_size (4B) + flags=0 (4B) + NAVX magic (4B).
    /// </summary>
    /// <param name="OutStr">The output stream to write the header to.</param>
    /// <param name="PackageGuid">The package GUID (random per build, NOT the App Id).</param>
    /// <param name="ZipSize">The size of the ZIP payload in bytes.</param>
    procedure WriteNavxHeader(var OutStr: OutStream; PackageGuid: Guid; ZipSize: Integer)
    var
        NavxMagic: Integer;
        GuidInts: array[4] of Integer;
    begin
        NavxMagic := 1482047822; // 'NAVX' as LE int32: 4E 41 56 58
        GuidToLEIntegers(PackageGuid, GuidInts);

        OutStr.Write(NavxMagic);   // offset 0:  magic
        OutStr.Write(40);          // offset 4:  header size
        OutStr.Write(2);           // offset 8:  format version
        OutStr.Write(GuidInts[1]); // offset 12: GUID bytes_le [0:3]
        OutStr.Write(GuidInts[2]); // offset 16: GUID bytes_le [4:7]
        OutStr.Write(GuidInts[3]); // offset 20: GUID bytes_le [8:11]
        OutStr.Write(GuidInts[4]); // offset 24: GUID bytes_le [12:15]
        OutStr.Write(ZipSize);     // offset 28: ZIP payload size
        OutStr.Write(0);           // offset 32: flags
        OutStr.Write(NavxMagic);   // offset 36: magic (trailer)
    end;

    /// <summary>
    /// Converts a GUID to 4 little-endian signed integers suitable for binary output via Write(Integer).
    /// The GUID string groups are reordered to match the NAVX bytes_le format.
    /// </summary>
    /// <param name="InputGuid">The GUID to convert.</param>
    /// <param name="Result">Array of 4 signed integers in little-endian byte order.</param>
    procedure GuidToLEIntegers(InputGuid: Guid; var Result: array[4] of Integer)
    var
        GuidStr: Text;
        g1: Text;
        g2: Text;
        g3: Text;
        g4: Text;
        g5: Text;
    begin
        // GUID string: {AABBCCDD-EEFF-GGHH-IIJJ-KKLLMMNNOOPP}
        // bytes_le:     DD CC BB AA  FF EE  HH GG  II JJ  KK LL MM NN OO PP
        //
        // Write(Integer) outputs 4 bytes in LE order. So for integer 0xAABBCCDD,
        // it writes bytes DD CC BB AA. This means:
        //   Int1 = parse g1 as hex directly (bytes_le already reverses g1 for us)
        //   Int2 = parse (g3 + g2) as hex  (reversed group order, LE undoes byte swap)
        //   Int3 = parse reversed(g4 + g5[1..4]) (these bytes are NOT reversed in bytes_le)
        //   Int4 = parse reversed(g5[5..12])     (these bytes are NOT reversed in bytes_le)
        GuidStr := UpperCase(DelChr(Format(InputGuid, 0, 9), '=', '{}'));

        g1 := CopyStr(GuidStr, 1, 8);   // AABBCCDD
        g2 := CopyStr(GuidStr, 10, 4);  // EEFF
        g3 := CopyStr(GuidStr, 15, 4);  // GGHH
        g4 := CopyStr(GuidStr, 20, 4);  // IIJJ
        g5 := CopyStr(GuidStr, 25, 12); // KKLLMMNNOOPP

        // Int1: Write(0xAABBCCDD) -> bytes DD CC BB AA = bytes_le[0..3]
        Result[1] := HexToSignedInt32(g1);

        // Int2: Write(0xGGHHEEFF) -> bytes FF EE HH GG = bytes_le[4..7]
        Result[2] := HexToSignedInt32(g3 + g2);

        // Int3: bytes_le[8..11] = II JJ KK LL (not reversed in bytes_le).
        // Write(0xLLKKJJII) -> bytes II JJ KK LL
        Result[3] := HexToSignedInt32(
            ReverseHexBytes(g4 + CopyStr(g5, 1, 4)));

        // Int4: bytes_le[12..15] = MM NN OO PP (not reversed in bytes_le).
        // Write(0xPPOONNMM) -> bytes MM NN OO PP
        Result[4] := HexToSignedInt32(
            ReverseHexBytes(CopyStr(g5, 5, 8)));
    end;

    /// <summary>
    /// Converts an 8-character hexadecimal string to a signed 32-bit integer.
    /// Handles unsigned-to-signed wrapping for values above 0x7FFFFFFF.
    /// </summary>
    /// <param name="HexStr">An 8-character hexadecimal string (e.g., 'AABBCCDD').</param>
    /// <returns>The signed 32-bit integer representation.</returns>
    procedure HexToSignedInt32(HexStr: Text): Integer
    var
        BigInt: BigInteger;
        i: Integer;
    begin
        // Convert 8-char hex string to BigInteger, then wrap to signed int32
        BigInt := 0;
        for i := 1 to 8 do
            BigInt := BigInt * 16 + HexCharToInt(HexStr[i]);

        // Unsigned-to-signed wrapping for values > 0x7FFFFFFF
        // Cannot use literal 4294967296 (overflows Integer parser),
        // so subtract 2^32 in three steps: 2147483647 + 2147483647 + 2
        if BigInt > 2147483647 then begin
            BigInt := BigInt - 2147483647;
            BigInt := BigInt - 2147483647;
            BigInt := BigInt - 2;
        end;

        exit(BigInt);
    end;

    local procedure ReverseHexBytes(Hex: Text): Text
    begin
        // Reverse byte pairs in an 8-char hex string: "AABBCCDD" -> "DDCCBBAA"
        exit(CopyStr(Hex, 7, 2) + CopyStr(Hex, 5, 2) +
             CopyStr(Hex, 3, 2) + CopyStr(Hex, 1, 2));
    end;

    local procedure HexCharToInt(c: Char): Integer
    begin
        case true of
            (c >= '0') and (c <= '9'):
                exit(c - 48);  // '0' = 48
            (c >= 'A') and (c <= 'F'):
                exit(c - 55);  // 'A' = 65, 65-55 = 10
            (c >= 'a') and (c <= 'f'):
                exit(c - 87);  // 'a' = 97, 97-87 = 10
            else
                Error('Invalid hex character: %1', c);
        end;
    end;
}