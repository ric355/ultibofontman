# TFontManager for Ultibo - Direct access to TrueType fonts on OpenVG

This libary is a combination of:
* A port to Ultibo of the original font2openvg application
* Some new classes to support loading of new TrueType fonts without having to recompile your application.

A demonstration application showing how to use it can be found here:
https://github.com/ric355/ultibottf

To make loading of TTF files possible, and to avoid screwing up the translation, I made a pretty much direct translation of the original C++ Font2OpenVG code. This code is all found in fontconv.pas, which contains a class that can load in a TTF file, convert it to OpenVG paths (same format as the include files that are produced by my previous Ultibo edition of Font2OpenVG) and additionally can save the converted format back to disk in a '.bin' file, which is quicker to load for future uses of the font. This class also contains code to create a '.inc' file so that converted fonts can still be compiled directly into the binary as before if that's all you need.

# Application Interface
The application interface, which seamlessly presents converted fonts without the caller knowing whether conversion is happening or not, is provided in the form of TFontManager which is found in fontman.pas.

TFontManager takes a folder name (no trailing slash) in its only constructor parameter. You can then call GetFont() to get a PVGShapesFontInfo pointer to use with VGShapes() calls. Note that as with any other VGShapes function, you must ensure that calls are made from the main thread, and that the OpenVG layer you want to use the font on is is set before any calls are made to TFontManager.GetFont().  The demo application demonstrates this with two layers. You must call GetFont() for each layer you will be using the font on. The font handles are not shareable between layers (that's an OpenVG thing too; nothing to do with me).

TFontManager.GetFont() first checks its internal list to see if the requested font has already been loaded and converted. If not present it looks for a '.bin' file to load (i.e. a pre-converted font), and if that is not present it looks for a '.ttf' file. If a full conversion is required, the '.bin' file is written back to disk so that on next reboot the conversion does not need to be repeated.

# Licensing
fontconv.pas is a derivative work, based on the original Font2OpenVG code developed by Hybrid Graphics limited. See https://github.com/mgthomas99/font2openvg  Therefore the licensing for this unit is whatever their licensing states in that regard.

fontman.pas is free to use in its entirety.
