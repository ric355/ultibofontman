unit fontman;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils,
  vgshapes,
  fontconv;

type
  TFontDescription = class
  private
    fontname : string[50];
    glyphPointsCount : longword;
    glyphPoints : array of integer;

    glyphPointIndicesCount : longword;
    glyphPointIndices : array of integer;

    glyphInstructionsCount : longword;
    glyphInstructions : array of byte;

    glyphInstructionIndicesCount : longword;
    glyphInstructionIndices : array of integer;

    glyphInstructionCountsCount : longword;
    glyphInstructionCounts : array of integer;

    glyphAdvancesCount : longword;
    glyphAdvances : array of integer;

    characterMapCount : longword;
    characterMap : array of smallint;

    glyphCount : integer;
    descender_height : integer;
    font_height : integer;

    FFilename : string;
  public
    constructor Create(afilename : string);
    destructor Destroy; override;
    procedure LoadFontFromBin;
    procedure MoveFontFromConve(aConv : TFontConverter);
    function LoadIntoCurrentOpenVGLayer : PVGShapesFontInfo;
  end;

  TFontDescriptionList = class(TStringList)
  protected
  public
  end;

  TFontManager = class
  private
    FFontsLoaded : TFontDescriptionList;
    FFontsDirectory : string;
    FLastError : string;
  public
    constructor Create(fontsdirectory : string);
    destructor Destroy; override;
    function GetFont(fontname : string) : PVGShapesFontInfo;
    property LastError : string read FLastError;
  end;

var
  GlobalFontManager : TFontManager;


implementation

constructor TFontDescription.Create(afilename : string);
begin
  inherited Create;

  FFilename := afilename;
end;

destructor TFontDescription.Destroy;
var
  layer : longint;
begin
  setlength(glyphPoints, 0);
  setlength(glyphPointIndices, 0);
  setlength(glyphInstructions, 0);
  setlength(glyphInstructionIndices, 0);
  setlength(glyphInstructioncounts, 0);
  setlength(glyphAdvances, 0);
  setlength(characterMap, 0);

  // unload from every layer.
  for layer := 0 to VGSHAPES_MAXLAYERS-1 do
  begin
    VGShapesSetLayer(layer);
    VGShapesUnloadAppFont(fontname);
  end;

  inherited Destroy;
end;

procedure TFontDescription.MoveFontFromConve(aConv : TFontConverter);
begin
  fontname := aConv.FontName;

  glyphPointsCount :=  aConv.ConvglyphPointsCount;
  setlength(glyphPoints, glyphPointsCount);
  move(aConv.ConvglyphPoints[0], glyphPoints[0], glyphPointsCount*sizeof(integer));

  glyphPointIndicesCount := aConv.ConvglyphPointIndicesCount;
  setlength(glyphPointIndices, glyphPointIndicesCount);
  move(aConv.ConvglyphPointIndices[0], glyphPointIndices[0], glyphPointIndicesCount * sizeof(integer));

  glyphInstructionsCount := aConv.ConvglyphInstructionsCount;
  setlength(glyphInstructions, glyphInstructionsCount);
  move(aConv.ConvglyphInstructions[0], glyphInstructions[0], glyphInstructionsCount * sizeof(byte));

  glyphInstructionIndicesCount := aConv.ConvglyphInstructionIndicesCount;
  setlength(glyphInstructionIndices, glyphInstructionIndicesCount);
  move(aConv.ConvglyphInstructionIndices[0], glyphInstructionIndices[0], glyphInstructionIndicesCount * sizeof(integer));

  glyphInstructioncountsCount := aConv.ConvglyphInstructioncountsCount;
  setlength(glyphInstructioncounts, glyphInstructioncountsCount);
  move(aConv.ConvglyphInstructioncounts[0], glyphInstructioncounts[0], glyphInstructioncountsCount * sizeof(integer));

  glyphAdvancesCount := aConv.ConvglyphAdvancesCount;
  setlength(glyphAdvances, glyphAdvancesCount);
  move(aConv.ConvglyphAdvances[0], glyphAdvances[0], glyphAdvancesCount * sizeof(integer));

  characterMapCount := aConv.ConvcharacterMapCount;
  setlength(characterMap, characterMapCount);
  move(aConv.ConvcharacterMap[0], characterMap[0], characterMapCount * sizeof(smallint));

  glyphCount := aConv.ConvglyphCount;
  descender_height := aConv.Convdescender_height;
  font_height := aConv.Convfont_height;
end;

procedure TFontDescription.LoadFontFromBin;
var
  f : file of byte;
  s : string[50];
  i : integer;
  len : byte;
  b : byte;
begin
  assignfile(f, FFilename);
  reset(f);

  blockread(f, fontname[0], 51);
  blockread(f, glyphPointsCount, sizeof(glyphPointsCount));
  setlength(glyphPoints, glyphPointsCount);
  blockread(f, glyphPoints[0], glyphPointsCount*sizeof(integer));

  blockread(f, glyphPointIndicesCount, sizeof(glyphPointIndicesCount));
  setlength(glyphPointIndices, glyphPointIndicesCount);
  blockread(f, glyphPointIndices[0], glyphPointIndicesCount * sizeof(integer));

  blockread(f, glyphInstructionsCount, sizeof(glyphInstructionsCount));
  setlength(glyphInstructions, glyphInstructionsCount);
  blockread(f, glyphInstructions[0], glyphInstructionsCount * sizeof(byte));

  blockread(f, glyphInstructionIndicesCount, sizeof(glyphInstructionIndicesCount));
  setlength(glyphInstructionIndices, glyphInstructionIndicesCount);
  blockread(f, glyphInstructionIndices[0], glyphInstructionIndicesCount * sizeof(integer));

  blockread(f, glyphInstructioncountsCount, sizeof(glyphInstructioncountsCount));
  setlength(glyphInstructioncounts, glyphInstructioncountsCount);
  blockread(f, glyphInstructioncounts[0], glyphInstructioncountsCount * sizeof(integer));

  blockread(f, glyphAdvancesCount, sizeof(glyphAdvancesCount));
  setlength(glyphAdvances, glyphAdvancesCount);
  blockread(f, glyphAdvances[0], glyphAdvancesCount * sizeof(integer));

  blockread(f, characterMapCount, sizeof(characterMapCount));
  setlength(characterMap, characterMapCount);
  blockread(f, characterMap[0], characterMapCount * sizeof(smallint));

  blockread(f, glyphCount, sizeof(glyphCount));
  blockread(f, descender_height, sizeof(descender_height));
  blockread(f, font_height, sizeof(font_height));

  closefile(f);
end;

function TFontDescription.LoadIntoCurrentOpenVGLayer : PVGShapesFontInfo;
begin
  Result := VGShapesLoadAppFont(fontname,
         @glyphPoints[0],
         @glyphPointIndices[0],
         @glyphInstructions[0],
         @glyphInstructionIndices[0],
         @glyphInstructionCounts[0],
         @glyphAdvances[0],
         @characterMap[0],
         glyphCount,
         descender_height,
         font_height);
end;

constructor TFontManager.Create(fontsdirectory : string);
begin
  inherited Create;

  FFontsDirectory := fontsdirectory;
  FFontsLoaded := TFontDescriptionList.Create;
end;

destructor TFontManager.Destroy;
var
  i : integer;
begin
  for i := 0 to FFontsLoaded.Count - 1 do
    TFontDescription(FFontsLoaded[i]).Free;

  FFontsLoaded.Free;

  inherited Destroy;
end;

function TFontManager.GetFont(fontname : string) : PVGShapesFontInfo;
var
  TypeFaceP : PVGShapesFontInfo;
  FontDesc : TFontDescription;
  i : integer;
  FontConv : TFontConverter;
begin
  Result := nil;
  FLastError := '';

  // uses current layer. Font is likely aready loaded.
  TypeFaceP := VGShapesGetAppFontByName(fontname);

  if (TypeFaceP = nil) then
  begin
    // Not loaded on this layer, so check to see if the font data file has already been loaded.
    i := FFontsLoaded.IndexOf(fontname);
    if (i >= 0) then
    begin
      FontDesc := TFontDescription(FFontsLoaded.Objects[i]);
      TypeFaceP := FontDesc.LoadIntoCurrentOpenVGLayer;
    end
    else
    if (FileExists(FFontsDirectory + '\'+fontname+'.bin')) then
    begin
      // font data wasn't already loaded but is on disk. load in the data.
      FontDesc := TFontDescription.Create(FFontsDirectory + '\'+fontname+'.bin');
      FontDesc.LoadFontFromBin;
      i := FFontsLoaded.Add(fontname);
      FFontsLoaded.Objects[i] := FontDesc;

      TypeFaceP := FontDesc.LoadIntoCurrentOpenVGLayer;
    end
    else
    if (FileExists(FFontsDirectory + '\' + fontname + '.ttf')) then
    begin
      // font data wasn't loaded, is not in a .bin file, but is in a ttf file.
      // we can load it in and perform the conversion to .bin.
      try
        FontConv := TFontConverter.Create(FFontsDirectory);
        if (not FontConv.FontConvert(fontname + '.ttf')) then
        begin
          FLastError := FontConv.LastError;
          exit;
        end;

        // save font to bin file so that on next boot it is there already converted.
        FontConv.SaveFontToBin;

        // although we have saved the .bin file, after just converting it's quicker
        // to move the data from the font converter directly.
        // on next boot the .bin file will be loaded as no conversion will occur.

        FontDesc := TFontDescription.Create(FFontsDirectory + '\'+fontname+'.bin');
        FontDesc.MoveFontFromConve(FontConv);
        FontConv.Free;
        i := FFontsLoaded.Add(fontname);
        FFontsLoaded.Objects[i] := FontDesc;

        TypeFaceP := FontDesc.LoadIntoCurrentOpenVGLayer;
      except
        FLastError := 'Exception in ttf convert ' + inttohex(longword(exceptaddr), 8);
        exit;
      end;
    end
    else
      TypeFaceP := nil;
  end;

  Result := TypeFaceP;
end;


initialization

end.

