unit fontconv;

{$mode ObjFPC}{$H+}

(*
Free pascal OpenVG fontconv for Ultibo, Richard Metcalfe, November 2022.

This is a pascal translation of the original Font2OpenVG software produced by
Hybrid Graphics Limited. See  https://github.com/mgthomas99/font2openvg

I had previously produced an interim version of Font2OpenVG which creates a Pascal
file suitable for compiling into Ultibo applications using the $include compiler
directive. This step can now be bypassed (although it is still a valid approach)
and alternatively binary files can be stored on disk containing the same data
and loaded in on demand. This is done by a separate FontManager class which manages
the loading of fonts only when necessary and returning typeface pointers
to the requesting code.

This code adds in the capabilities to re-save the font in a binary format that
is compatible with the aforementioned font manager, although it also generates the
include file as per the old C++ version.

The advantage of this binary file based approach is that you no longer need to
compile fonts into your Ultibo binary, meaning you can add more as and when
needed without any need to recompile your software. They must obviously be
placed in a pre-determined directory and the running software should include a
method of being informed that a new font is to be loaded. That is of course
application dependent and down to your preferences as to how it should work.

Note that the conversion process here retains all of the vector stuff and then
ultimately copies the data into very similar structures before saving to disk.
Although this is not particularly efficient, I have deliberately kept it that way
so that the original algorithm is preserved. This just made it less likely that
I would screw it up somehow when making changes to support saving of the binary
data.

There is some irony in this approach - a binary TTF file is read, translated,
and then dumped out as a binary file again. But the mitigation of this is that
the final binary file produced is in a format suitable for loading directly
into OpenVG within Ultibo via the FontManager class I have built.

The Font Manager supports direct loading of TTF files but they must go through
the additioal processing required to convert them into a format suitable for
OpenVG. This may or may not be OK for your application depending upon what it
does.

The use of "generic" and "specialize" and "operator" keywords allows this
implementation to be pretty similar to the original alogorithm (which uses
C++ templates and Vectors with operator overloading). This is the main reason
why I was able to re-express it in Pascal without having much of an idea of
how the underlying dataset actually works.

See FontMan.pas for the TFontManager code, and the example application
FontManSample which pulls it all together.

*)


interface

uses
  freetypeh,
  SysUtils;


const
  NGLYPHS = 500;
  {$ifdef windows}
  SLASH = '\';
  {$endif}
  {$ifdef linux}
  SLASH = '/';
  {$else}
  // ultibo
  SLASH = '\';
  {$endif}


type
  generic TVector<T> = class
    items: array of T;
    Count: integer;
    function GetItem(i: integer): T;
    procedure SetItem(i: integer; aitem: T);
    procedure push_back(Value: T);
    procedure resize(newsize: integer);
    constructor Create;
    destructor Destroy; override;
    property size: integer read Count;
    property Index[i: integer]: T read GetItem write SetItem; default;
  end;

  TVector2 = class
    magic: integer;
    x: double;
    y: double;
    constructor Create(px, py: double);
    function logstr: string;
  end;

  TFontConvIntegerArray = array of integer;
  TFontConvSmallintArray = array of smallint;
  TFontConvByteArray = array of byte;

  TFontConvName = string[50];
  TFontConverter = class
  public
    FLastError : string;
    Ffontname: TFontConvName;
    FFontPath : string;
    FglyphPointsCount: longword;
    FglyphPoints: array of integer;

    FglyphPointIndicesCount: longword;
    FglyphPointIndices: array of integer;

    FglyphInstructionsCount: longword;
    FglyphInstructions: array of byte;

    FglyphInstructionIndicesCount: longword;
    FglyphInstructionIndices: array of integer;

    FglyphInstructionCountsCount: longword;
    FglyphInstructionCounts: array of integer;

    FglyphAdvancesCount: longword;
    FglyphAdvances: array of integer;

    FcharacterMapCount: longword;
    FcharacterMap: array of smallint;

    FglyphCount: integer;
    Fdescender_height: integer;
    Ffont_height: integer;

    Fglobal_miny: double;
    Fglobal_maxy: double;

  public
    constructor Create(fontpath : string);
    destructor Destroy; override;
    function FontConvert(ttfFilename : string) : boolean;
    procedure SaveFontToBin;
    procedure WriteFontToInc;
    procedure LoadFontFromBin;
  published
    property FontName : TFontConvName read FFontName;
    property ConvglyphPointsCount: longword read FglyphPointsCount;
    property ConvglyphPoints: TFontConvIntegerArray read FglyphPoints;
    property ConvglyphPointIndicesCount: longword read FglyphPointIndicesCount;
    property ConvglyphPointIndices: TFontConvIntegerArray read FglyphPointIndices;
    property ConvglyphInstructionsCount: longword read FglyphInstructionsCount;
    property ConvglyphInstructions: TFontConvByteArray read FglyphInstructions;
    property ConvglyphInstructionIndicesCount: longword read FglyphInstructionIndicesCount;
    property ConvglyphInstructionIndices: TFontConvIntegerArray read FglyphInstructionIndices;
    property ConvglyphInstructionCountsCount: longword read FglyphInstructionCountsCount;
    property ConvglyphInstructionCounts: TFontConvIntegerArray read FglyphInstructionCounts;
    property ConvglyphAdvancesCount: longword read FglyphAdvancesCount;
    property ConvglyphAdvances: TFontConvIntegerArray read FglyphAdvances;
    property ConvcharacterMapCount: longword read FcharacterMapCount;
    property ConvcharacterMap: TFontConvSmallintArray read FcharacterMap;
    property ConvglyphCount: integer read FglyphCount;
    property Convdescender_height: integer read Fdescender_height;
    property Convfont_height: integer read Ffont_height;
    property Convglobal_miny: double read Fglobal_miny;
    property Convglobal_maxy: double read Fglobal_maxy;
    property LastError : string read FLastError;
  end;


implementation

operator +(a: TVector2; b: TVector2) r: TVector2;
begin
  r := TVector2.Create(0, 0);
  r.x := a.x + b.x;
  r.y := a.y + b.y;
end;

operator * (a: TVector2; b: double) r: TVector2;
begin
  r := TVector2.Create(0, 0);
  r.x := a.x * b;
  r.y := a.y * b;
end;

constructor TVector2.Create(px, py: double);
begin
  inherited Create;
  magic := 1234;
  x := px;
  y := py;
end;

function TVector2.logstr: string;
begin
  Result := IntToStr(magic) + ' ' + floattostr(x) + ' ' + floattostr(y);
end;

constructor TVector.Create;
begin
  inherited Create;

  Count := 0;
end;

destructor TVector.Destroy;
begin
  setlength(items, 0);

  inherited Destroy;
end;

procedure TVector.push_back(Value: T);
begin
  Inc(Count);
  setlength(items, Count);
  items[Count - 1] := Value;
end;

procedure TVector.resize(newsize: integer);
begin
  setlength(items, newsize);
  Count := newsize;
end;

function TVector.GetItem(i: integer): T;
begin
  Result := Items[i];
end;

procedure TVector.SetItem(i: integer; aitem: T);
begin
  Items[i] := aitem;
end;

function convFTFixed(const x: FT_Pos): double;
begin
  Result := double(x) / 4096.0;
end;

function convFTVector(const v: FT_Vector): TVector2;
begin
  Result := TVector2.Create(convFTFixed(v.x), convFTFixed(v.y));
end;

function isOn(b: byte): boolean;
begin
  Result := b and 1 > 0;
end;


constructor TFontConverter.Create(fontpath : string);
begin
  inherited Create;
  FLastError := '';
  FFontPath := fontpath;
end;

destructor TFontConverter.Destroy;
begin
  setlength(FglyphPoints, 0);
  setlength(FglyphPointIndices, 0);
  setlength(FglyphInstructions, 0);
  setlength(FglyphInstructionIndices, 0);
  setlength(FglyphInstructionCounts, 0);
  setlength(FglyphAdvances, 0);
  setlength(FcharacterMap, 0);

  inherited Destroy;
end;

function TFontConverter.FontConvert(ttfFilename : string) : boolean;
var
  FTLib: PFT_Library;
  faceP: PFT_Face;
  res: integer;
  characterMap: array[0..NGLYPHS - 1] of smallint;
  glyphs: integer = 0;
  glyphIndex: FT_Uint;
  cc: integer;
  advance: double;
  outlineP: PFT_Outline;

  gpvecindices: specialize TVector<integer> = nil;
  givecindices: specialize TVector<integer> = nil;
  gpvecsizes: specialize TVector<integer> = nil;
  givecsizes: specialize TVector<integer> = nil;
  gpvec: specialize TVector<TVector2> = nil;
  givec: specialize TVector<byte> = nil;
  gbbox: specialize TVector<double> = nil;
  advances: specialize TVector<double> = nil;
  pvec: specialize TVector<TVector2> = nil;
  ivec: specialize TVector<byte> = nil;
  minx: double;
  miny: double;
  maxx: double;
  maxy: double;
  s: integer;
  e: integer;
  is_on: boolean;
  last, v, nv: TVector2;
  con: integer;
  pnts: integer;
  i: integer;
  c: integer;
  n: integer;
  asize: integer;
  item: integer;
  filetoopen : string;
begin
  Result := true;

  //init freetype library
  FTLib := nil;
  res := FT_Init_FreeType(FTLib);
  if (res <> 0) then
  begin
    FLastError := 'Unable to initialize freetype library';
    Result := false;
    exit;
  end
  else
  begin
    try
      faceP := nil;
      filetoopen := FFontPath + SLASH + ttfFilename;
      res := FT_New_Face(FTLib, PChar(filetoopen), 0, faceP);

      // generate font name
      FFontname := ExtractFileName(ttfFilename);
      FFontname := LeftStr(FFontname, pos('.', FFontname)-1);

      if (res = 0) then
      begin
        FT_Set_Char_Size(
          faceP,      // handle to face object
          0,          // char_width in 1/64th of points
          64 * 64,    // char_height in 1/64th of points
          96,         // horizontal device resolution
          96);        // vertical device resolution


        gpvecindices := specialize TVector<integer>.Create;
        givecindices := specialize TVector<integer>.Create;
        gpvecsizes := specialize TVector<integer>.Create;
        givecsizes := specialize TVector<integer>.Create;
        gbbox := specialize TVector<double>.Create;
        advances := specialize TVector<double>.Create;

        gpvec := specialize TVector<TVector2>.Create;
        givec := specialize TVector<byte>.Create;

        Fglobal_miny := 1000000.0;
        Fglobal_maxy := -10000000.0;


        for cc := 0 to NGLYPHS - 1 do
        begin
          //initially nonexistent
          characterMap[cc] := -1;

          //discard the first 32 characters
          if (cc < 32) then
            continue;

          glyphIndex := FT_Get_Char_Index(faceP, cc);

          res := FT_Load_Glyph(faceP, glyphIndex, FT_LOAD_NO_BITMAP or
            FT_LOAD_NO_HINTING or FT_LOAD_IGNORE_TRANSFORM);

          if (res = 0) then
          begin
            advance := convFTFixed(faceP^.glyph^.advance.x);
            if (cc = 32) then
            begin
              //space doesn't contain any data
              gpvecindices.push_back(gpvec.size);
              givecindices.push_back(givec.size);

              gpvecsizes.push_back(0);
              givecsizes.push_back(0);

              gbbox.push_back(0);
              gbbox.push_back(0);
              gbbox.push_back(0);
              gbbox.push_back(0);

              advances.push_back(advance);

              //write glyph index to character map
              characterMap[cc] := glyphs;
              Inc(Glyphs);
              continue;
            end;

            pvec := specialize TVector<TVector2>.Create;
            ivec := specialize TVector<byte>.Create;

            outlineP := @FaceP^.glyph^.outline;

            minx := 10000000.0;
            miny := 100000000.0;
            maxx := -10000000.0;
            maxy := -10000000.0;

            s := 0;

            for con := 0 to outlineP^.n_contours - 1 do
            begin
              pnts := 1;
              e := outlineP^.contours[con] + 1;
              last := convFTVector(outlineP^.points[s]);

              //read the contour start point
              ivec.push_back(2);
              pvec.push_back(last);

              i := s + 1;

              while (i <= e) do
              begin
                if (i = e) then
                  c := s
                else
                  c := i;

                if (i = e - 1) then
                  n := s
                else
                  n := i + 1;

                v := convFTVector(outlineP^.points[c]);
                is_on := isOn(Ord(outlineP^.tags[c]));
                if (is_on) then
                begin  //line
                  i += 1;
                  ivec.push_back(4);
                  pvec.push_back(v);
                  pnts += 1;
                end
                else
                begin  //spline
                  if (isOn(Ord(outlineP^.tags[n]))) then
                  begin  //next on
                    nv := convFTVector(outlineP^.points[n]);
                    i += 2;
                  end
                  else
                  begin  //next off, use middle point
                    nv := (v + convFTVector(outlineP^.points[n])) * 0.5;
                    i += 1;
                  end;
                  ivec.push_back(10);
                  pvec.push_back(v);
                  pvec.push_back(nv);
                  pnts += 2;
                end;
                last := nv;
              end;
              ivec.push_back(0);
              s := e;
            end;

            for i := 0 to pvec.size - 1 do
            begin
              if (pvec[i].x < minx) then
                minx := pvec[i].x;
              if (pvec[i].x > maxx) then
                maxx := pvec[i].x;
              if (pvec[i].y < miny) then
                miny := pvec[i].y;
              if (pvec[i].y > maxy) then
                maxy := pvec[i].y;
            end;

            if (pvec.size = 0) then
            begin
              minx := 0.0;
              miny := 0.0;
              maxx := 0.0;
              maxy := 0.0;
            end;

            gpvecindices.push_back(gpvec.size);
            givecindices.push_back(givec.size);

            gpvecsizes.push_back(pvec.size);
            givecsizes.push_back(ivec.size);

            gbbox.push_back(minx);
            gbbox.push_back(miny);
            gbbox.push_back(maxx);
            gbbox.push_back(maxy);
            advances.push_back(advance);

            if (miny < Fglobal_miny) then
              Fglobal_miny := miny;
            if (maxy > Fglobal_maxy) then
              Fglobal_maxy := maxy;

            asize := gpvec.size;
            gpvec.resize(asize + pvec.size);
            for item := 0 to pvec.size - 1 do
              gpvec[asize + item] := pvec[item];

            asize := givec.size;
            givec.resize(asize + ivec.size);

            for item := 0 to ivec.size - 1 do
              givec[asize + item] := ivec[item];

            //write glyph index to character map
            characterMap[cc] := glyphs;
            glyphs += 1;
          end
          else
          begin
            FLastError := 'Failed to load glyph ' + IntToStr(res);
            Result := false;
            exit;
          end;

          if (pvec <> nil) then pvec.Free;
          if (ivec <> nil) then ivec.Free;
        end;
      end
      else
      begin
        FLastError := 'Unable to open typeface; res=' + IntToStr(Res);
        Result := false;
        exit;
      end;

      // move from the vectors to the class variables.
      // some of the code above could write directly into these variables, but I don't
      // want to mess with the algorithm, so this way is just a bit safer.

      FglyphInstructionsCount := givec.size;
      SetLength(FglyphInstructions, FglyphInstructionsCount);
      move(givec.items[0], FglyphInstructions[0], FglyphInstructionsCount*sizeof(byte));

      FglyphInstructionIndicesCount := givecindices.size;
      SetLength(FglyphInstructionIndices, FglyphInstructionIndicesCount);
      move(givecindices.Items[0], FglyphInstructionIndices[0], FglyphInstructionIndicesCount*sizeof(integer));

      FglyphInstructionCountsCount := givecsizes.size;
      SetLength(FglyphInstructionCounts, FglyphInstructionCountsCount);
      move(givecsizes.Items[0], FglyphInstructionCounts[0], FglyphInstructionCountsCount*sizeof(integer));

      FglyphPointIndicesCount := gpvecindices.size;
      SetLength(FglyphPointIndices, FglyphPointIndicesCount);
      move(gpvecindices.Items[0], FglyphPointIndices[0], FglyphPointIndicesCount*sizeof(integer));

      FglyphCount := glyphs;
      FglyphPointsCount := gpvec.size*2;
      SetLength(FglyphPoints, gpvec.size*2);  // this one has 2 entries per item (x,y)

      for i := 0 to gpvec.size - 1 do
      begin
        FglyphPoints[i*2] := trunc(65536.0 * gpvec[i].x);
        FglyphPoints[i*2+1] := trunc(65536.0 * gpvec[i].y);
      end;

      FglyphAdvancesCount := advances.size;
      SetLength(FglyphAdvances, FglyphAdvancesCount);

      for i := 0 to advances.size - 1 do
      begin
        FglyphAdvances[i] := trunc(65536.0 * advances[i]);
      end;

      Fdescender_height := trunc(65536.0 * Fglobal_miny);
      Ffont_height := trunc(65536.0 * Fglobal_maxy);

      FcharacterMapCount := NGLYPHS;
      SetLength(FcharacterMap, NGLYPHS);
      move(characterMap[0], FcharacterMap[0], NGLYPHS*sizeof(smallint));

    finally
      // cleanup library
      FT_Done_FreeType(FTLib);

      // release vectors
      if (gpvecindices <> nil) then gpvecindices.Free;
      if (givecindices <> nil) then givecindices.Free;
      if (gpvecsizes <> nil) then gpvecsizes.Free;
      if (givecsizes <> nil) then givecsizes.Free;
      if (gbbox <> nil) then gbbox.Free;
      if (advances <> nil) then advances.Free;
    end;
  end;
end;

procedure TFontConverter.WriteFontToInc;
var
  i : integer;
  incfile : textfile;
begin
  // generate a .inc file suitable for compiling directly into an ultibo app.
  assignfile(incfile, FFontname + '.inc');
  rewrite(incfile);

  writeln(incfile, 'var '+FFontname+'_glyphInstructionsCount : longword = ' + IntToStr(FglyphInstructionsCount) + ';');
  writeln(incfile);
  writeln(incfile, 'var '+FFontname+'_glyphInstructions : array[0..' + IntToStr(FglyphInstructionsCount - 1) +
    '] of byte = (');
  for i := 0 to FglyphInstructionsCount - 1 do
  begin
    if ((i mod 20) = 0) then
    begin
      if (i>0) then writeln(incfile);
      write(incfile, '    ');
    end;

    if (i = FglyphInstructionsCount - 1) then
      write(incfile, IntToStr(FglyphInstructions[i]) + ' ')
    else
      write(incfile, IntToStr(FglyphInstructions[i]) + ',');
  end;
  writeln(incfile, ');');

  writeln(incfile, 'var '+FFontname+'_glyphInstructionIndicesCount : longword = ' +
                   IntToStr(FglyphInstructionIndicesCount) + ';');
  writeln(incfile);
  writeln(incfile, 'var '+FFontname+'_glyphInstructionIndices : array[0..' +
                   IntToStr(FglyphInstructionIndicesCount - 1) + '] of integer = (');
  for i := 0 to FglyphInstructionIndicesCount - 1 do
  begin
    if ((i mod 20) = 0) then
    begin
      if (i>0) then writeln(incfile);
      write(incfile, '    ');
    end;

    if (i = FglyphInstructionIndicesCount - 1) then
      write(incfile, IntToStr(FglyphInstructionIndices[i]) + ' ')
    else
      write(incfile, IntToStr(FglyphInstructionIndices[i]) + ',');
  end;
  writeln(incfile, ');');

  writeln(incfile, 'var '+FFontname+'_glyphInstructioncountsCount : longword = ' +
                   IntToStr(FglyphInstructionCountsCount) + ';');
  writeln(incfile, '');
  writeln(incfile, 'var '+FFontname+'_glyphInstructionCounts : array[0..' +
                   IntToStr(FglyphInstructionCountsCount - 1) + '] of integer = (');
  for i := 0 to FglyphInstructionCountsCount - 1 do
  begin
    if ((i mod 20) = 0) then
    begin
      if (i>0) then writeln(incfile);
      write(incfile, '    ');
    end;

    if (i = FglyphInstructionCountsCount - 1) then
      write(incfile, IntToStr(FglyphInstructionCounts[i]) + ' ')
    else
      write(incfile, IntToStr(FglyphInstructionCounts[i]) + ',');
  end;
  writeln(incfile, ');');
  writeln(incfile);


  writeln(incfile, 'var '+FFontname+'_glyphPointIndicesCount : longword = ' +
                   IntToStr(FglyphPointIndicesCount) + ';');
  writeln(incfile);
  writeln(incfile, 'var '+FFontname+'_glyphPointIndices : array[0..' + IntToStr(FglyphPointIndicesCount - 1) +
                   '] of integer = (');
  for i := 0 to FglyphPointIndicesCount - 1 do
  begin
    if ((i mod 20) = 0) then
    begin
      if (i>0) then writeln(incfile);
      write(incfile, '    ');
    end;

    if (i = FglyphPointIndicesCount - 1) then
      write(incfile, IntToStr(FglyphPointIndices[i]) + ' ')
    else
      write(incfile, IntToStr(FglyphPointIndices[i]) + ',');
  end;
  writeln(incfile, ');');


  writeln(incfile, 'var '+FFontname+'_glyphPointsCount : longword = ' + IntToStr(FglyphPointsCount div 2) + '*2;');
  writeln(incfile);
  writeln(incfile, 'var '+FFontname+'_glyphPoints : array[0..' + IntToStr(FGlyphPointsCount div 2) +
                   '*2-1] of integer = (');
  for i := 0 to FglyphPointsCount div 2 - 1 do
  begin
    if ((i mod 10) = 0) then
    begin
      if (i>0) then writeln(incfile);
      write(incfile, '    ');
    end;

    if (i = FglyphPointsCount div 2 - 1) then
      write(incfile, IntToStr(FglyphPoints[i*2]) + ',' +
        IntToStr(FglyphPoints[i*2+1]) + ' ')
    else
      write(incfile, IntToStr(FglyphPoints[i*2]) + ',' +
        IntToStr(FglyphPoints[i*2+1]) + ',');
  end;
  writeln(incfile, ');');



  writeln(incfile, 'var '+FFontname+'_glyphAdvancesCount : longword = ' + IntToStr(FglyphAdvancesCount) + ';');
  writeln(incfile);
  writeln(incfile, 'var '+FFontname+'_glyphAdvances : array[0..' + IntToStr(FglyphAdvancesCount - 1) +
                   '] of integer = (');
  for i := 0 to FglyphAdvancesCount - 1 do
  begin
    if ((i mod 20) = 0) then
    begin
      if (i>0) then writeln(incfile);
      write(incfile, '    ');
    end;

    if (i = FglyphAdvancesCount - 1) then
      write(incfile, IntToStr(FglyphAdvances[i]) + ' ')
    else
      write(incfile, IntToStr(FglyphAdvances[i]) + ',');
  end;
  writeln(incfile, ');');
  writeln(incfile);


  writeln(incfile, 'const '+FFontname+'_descender_height : integer = ' +
    IntToStr(trunc(65536.0 * Fglobal_miny)) + ';');
  writeln(incfile, 'const '+FFontname+'_font_height : integer = ' +
    IntToStr(trunc(65536.0 * Fglobal_maxy)) + ';');

  writeln(incfile, 'const '+FFontname+'_glyphCount : integer = ' + IntToStr(FglyphCount) + ';');
  writeln(incfile, 'var '+FFontname+'_characterMapCount : longword = 499;');
  writeln(incfile, '');


  writeln(incfile, 'const '+FFontname+'_characterMap : array[0..499] of smallint = (');
  for i := 0 to NGLYPHS - 1 do
  begin
    if ((i mod 20) = 0) then
    begin
      if (i>0) then writeln(incfile);
      write(incfile, '    ');
    end;

    if (i = NGLYPHS - 1) then
      write(incfile, IntToStr(FcharacterMap[i]) + ' ')
    else
      write(incfile, IntToStr(FcharacterMap[i]) + ',');
  end;
  writeln(incfile, ');');

  closefile(incfile);
end;

procedure TFontConverter.SaveFontToBin;
var
  f : file of byte;
begin
  // we can now save the above in a .bin file.

  assignfile(f, FFontPath + SLASH + FFontName+'.bin');
  rewrite(f);

  blockwrite(f, Ffontname[0], 51);
  blockwrite(f, FglyphPointsCount, sizeof(FglyphPointsCount));
  blockwrite(f, FglyphPoints[0], FglyphPointsCount * sizeof(integer));

  blockwrite(f, FglyphPointIndicesCount, sizeof(FglyphPointIndicesCount));
  blockwrite(f, FglyphPointIndices[0], FglyphPointIndicesCount * sizeof(integer));

  blockwrite(f, FglyphInstructionsCount, sizeof(FglyphInstructionsCount));
  blockwrite(f, FglyphInstructions[0], FglyphInstructionsCount * sizeof(byte));

  blockwrite(f, FglyphInstructionIndicesCount, sizeof(FglyphInstructionIndicesCount));
  blockwrite(f, FglyphInstructionIndices[0], FglyphInstructionIndicesCount * sizeof(integer));

  blockwrite(f, FglyphInstructioncountsCount, sizeof(FglyphInstructioncountsCount));
  blockwrite(f, FglyphInstructioncounts[0], FglyphInstructioncountsCount * sizeof(integer));

  blockwrite(f, FglyphAdvancesCount, sizeof(FglyphAdvancesCount));
  blockwrite(f, FglyphAdvances[0], FglyphAdvancesCount * sizeof(integer));

  blockwrite(f, FcharacterMapCount, sizeof(FcharacterMapCount));
  blockwrite(f, FcharacterMap[0], FcharacterMapCount * sizeof(smallint));

  blockwrite(f, FglyphCount, sizeof(FglyphCount));
  blockwrite(f, Fdescender_height, sizeof(Fdescender_height));
  blockwrite(f, Ffont_height, sizeof(Ffont_height));


  closefile(f);
end;

procedure TFontConverter.LoadFontFromBin;
var
  f : file of byte;
begin
  if (fileexists(FFontPath + SLASH + FFontName+'.bin')) then
  begin
    assignfile(f, FFontPath + SLASH + FFontName+'.bin');
    reset(f);

    blockread(f, fontname[0], 51);
    blockread(f, FglyphPointsCount, sizeof(FglyphPointsCount));
    setlength(FglyphPoints, FglyphPointsCount);
    blockread(f, FglyphPoints[0], FglyphPointsCount*sizeof(integer));

    blockread(f, FglyphPointIndicesCount, sizeof(FglyphPointIndicesCount));
    setlength(FglyphPointIndices, FglyphPointIndicesCount);
    blockread(f, FglyphPointIndices[0], FglyphPointIndicesCount * sizeof(integer));

    blockread(f, FglyphInstructionsCount, sizeof(FglyphInstructionsCount));
    setlength(FglyphInstructions, FglyphInstructionsCount);
    blockread(f, FglyphInstructions[0], FglyphInstructionsCount * sizeof(byte));

    blockread(f, FglyphInstructionIndicesCount, sizeof(FglyphInstructionIndicesCount));
    setlength(FglyphInstructionIndices, FglyphInstructionIndicesCount);
    blockread(f, FglyphInstructionIndices[0], FglyphInstructionIndicesCount * sizeof(integer));

    blockread(f, FglyphInstructioncountsCount, sizeof(FglyphInstructioncountsCount));
    setlength(FglyphInstructioncounts, FglyphInstructioncountsCount);
    blockread(f, FglyphInstructioncounts[0], FglyphInstructioncountsCount * sizeof(integer));

    blockread(f, FglyphAdvancesCount, sizeof(FglyphAdvancesCount));
    setlength(FglyphAdvances, FglyphAdvancesCount);
    blockread(f, FglyphAdvances[0], FglyphAdvancesCount * sizeof(integer));

    blockread(f, FcharacterMapCount, sizeof(FcharacterMapCount));
    setlength(FcharacterMap, FcharacterMapCount);
    blockread(f, FcharacterMap[0], FcharacterMapCount * sizeof(smallint));

    blockread(f, FglyphCount, sizeof(FglyphCount));
    blockread(f, Fdescender_height, sizeof(Fdescender_height));
    blockread(f, Ffont_height, sizeof(Ffont_height));

    closefile(f);
  end;
end;

end.
