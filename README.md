# SaveFigure: Matlab vector figure export

SaveFigure is a Matlab utility which provides aesthetically pleasing figure export which provides a few essential features not present in Matlab's built in figure export or any known utility on the FileExchange:

- instant export to multiple formats, including PDF, SVG, EPS, PNG, while ensuring that all formats look identical
- identical output on multiple platforms (Linux and MacOS currently supported, Windows support should not be difficult to add, contact me if interested)
- preserves alpha blending and transparency on patches, lines, markers, etc.
- sets or preserves nicely rendered fonts (specified in options)
- preserves vector graphics

# Installation

SaveFigure requires ImageMagick and inkscape to be installed and accessible from the command line in order to run. The easiest way to accomplish this is to run:

Linux:
`sudo apt-get install inkscape image-magick`

Mac:
`brew install inkscape image-magick`

# Usage

Save to specific file type:
`saveFigure('foo.pdf');`
`saveFigure('foo.png', gcf);`

Save to set of file types, return full file names:
`fileNameList = saveFigure('foo', gcf, 'ext', {'pdf', 'png', 'svg', 'fig', 'eps', 'hires.png'});`

If fileName has no extension, the figure will be saved in multiple formats as specified by the 'ext' parameter value pair. If no 'ext' is specified, the default list is `{'pdf', 'png', 'fig'}`.

# Method

SaveFigure at its core is built atop an updated version of Jeurg Schwizer's excellent [plot2svg utility](http://www.mathworks.com/matlabcentral/fileexchange/7401-scalable-vector-graphics--svg--export-of-figures) which converts figures into SVG files. Most of Jeurg's code is included within saveFigure, but I've changed a few things to make it compatible with the new hg2 graphics library introduced in R2014a. I've also changed a few things with patch object rendering to improve the SVG rendering aesthetics.

After running plot2svg internally, saveFigure calls out to Inkscape to convert the SVG into a PDF file, and then to image-magick's convert utility to convert PDF into other requested formats. I've found Inkscape's SVG to PDF conversion to be more reliable than image-magick's.
 
# Known limitations

- Because plot2svg manually reproduces Matlab figure in SVG format, some of the newer plotting tools released in R2014b are not fully supported yet. They can be added easily, but this requires crawling through Matlab's graphics object hierarchy and converting into an equivalent SVG format.
- Notably, legends are not currently supported in new versions of Matlab, though this hopefully won't be too difficult to add back in.

