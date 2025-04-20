# Images Used in Joomla Branches Tester Documentation

Software architecture images are:
* Stored in their original format as OpenOffice Draw (ODG) files and used as SVGs.
* Designed to work in both light and dark color modes.
* Using Joomla logo colors and the Ubuntu font.
* Avoid using transparency, as it may not be displayed correctly in Firefox and Safari.

To create one of the three SVGs from the corresponding ODG file format:
1. Export in OpenOffice Draw as a PDF with the following options:
   * **General** – Embed Standard Fonts
   * **Graphics** – Lossless Compression
2. Convert the PDF to SVG using the command line tool `pdf2svg`.
3. Modify the SVG file to use `<svg ... width="100%" height="auto" ...>`

To create the social preview image on macOS:
```
brew install librsvg
brew install imagemagick
rsvg-convert -w 1280 -h 640 --keep-aspect-ratio --background-color=transparent joomla-branches-tester.svg > TMP.png
magick TMP.png -gravity center -background transparent -extent 1280x640 joomla-branches-tester.png
rm TMP.png
```
