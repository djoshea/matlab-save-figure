# SaveFigure: Matlab vector figure export

SaveFigure is a Matlab utility which provides aesthetically pleasing figure export which provides a few essential features not present in Matlab's built in figure export or any known utility on the FileExchange:

- instant export to multiple formats, including PDF, SVG, EPS, PNG, while ensuring that all formats look identical
- identical output on multiple platforms (Linux and MacOS currently supported, Windows support should not be difficult to add, contact me if interested)
- preserves alpha blending and transparency on patches, lines, markers, etc.
- sets or preserves nicely rendered fonts (specified in options)
- preserves vector graphics

This code is essentially a nice wrapper around [Juerg Schwizer's](http://www.zhinst.com/blogs/schwizer/) plot2svg utility. The advantage of this approach is that we have complete control of figure output and appearance; the disadvantage is that it requires a complete reconstruction of the figure as an SVG, and so the code will have to be kept up to date as Matlab adds new graphics objects (e.g. `stem`, `histogram`, `legend`). 

I've found the outputs to be more consistent, more faithful to the on-screen displayed figure, and more aesthetically pleasing than other excellent alternatives, including [export_fig](http://www.mathworks.com/matlabcentral/fileexchange/23629-export-fig) by Oliver Woodward and Yair Altman and [savefig](http://www.mathworks.com/matlabcentral/fileexchange/10889-savefig) by Peder Axensten. 

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

# Demo

From `demo_saveFigure`:

```
% Plot scatter plot with alpha blending
randseed(1); figure(1); clf;
N = 500; dx = randn(N, 1); dy = randn(N, 1);
h = plot(dx, dy, 'o', 'MarkerFaceColor', [0.6 0.6 1], 'LineWidth', 0.1, 'MarkerEdgeColor', 'w', 'MarkerSize', 8);
setMarkerOpacity(h, 0.3, 0.6);
hold on
N = 500; dx = randn(N, 1) + 1; dy = randn(N, 1);
h = plot(dx, dy, 'o', 'MarkerFaceColor', [1 0.6 0.6], 'LineWidth', 0.1, 'MarkerEdgeColor', 'w', 'MarkerSize', 8);
setMarkerOpacity(h, 0.3, 0.6);

xlabel('Param 1'); ylabel('Param 2'); title('SaveFigure Demo');
box off; axis equal;

saveFigure('demoScatter.png')
```

![](https://github.com/djoshea/matlab-save-figure/blob/master/demoScatter.png)

```
% Plot timeseries with translucent error regions
randseed(2);
K = 6; N = 1000; t = (0:N-1) - 100;
y = sgolayfilt(randn(N, K), 3, 99, [], 1);
ye = sgolayfilt(randn(N, K) * 0.5, 3, 99, [], 1);

figure(2), clf; hold on;
cmap = parula(K);
for k = 1:K
    % errorshade defined below
    errorshade(t, y(:, k), ye(:, k), cmap(k, :), 'errorAlpha', 0.5, 'lineAlpha', 0.9);
end

box off; xlim([0 800]);
xlabel('Time'); ylabel('Signal'); title('SaveFigure Demo');

saveFigure('demoTimeseries.png');
```

![](https://github.com/djoshea/matlab-save-figure/blob/master/demoTimeseries.png)


# Method

SaveFigure at its core is built atop an updated version of Jeurg Schwizer's excellent [plot2svg utility](http://www.mathworks.com/matlabcentral/fileexchange/7401-scalable-vector-graphics--svg--export-of-figures) which converts figures into SVG files. Most of Jeurg's code is included within saveFigure, but I've changed a few things to make it compatible with the new hg2 graphics library introduced in R2014a. I've also changed a few things with patch object rendering to improve the SVG rendering aesthetics.

After running plot2svg internally, saveFigure calls out to Inkscape to convert the SVG into a PDF file, and then to image-magick's convert utility to convert PDF into other requested formats. I've found Inkscape's SVG to PDF conversion to be more reliable than image-magick's.
 
# Line and Marker Opacity

Included in the repo are two utilities `setLineOpacity` and `setMarkerOpacity` which will set the opacity of lines and markers in plots, respectively.

`setLineOpacity(hLine, edgeAlpha)`

and 

`setMarkerOpacity(hLine, markerFaceAlpha, markerEdgeAlpha)`

In newer versions of MATLAB, this opacity setting will occur directly on the graphics handle and alter the appearance of the Matlab figure. In older versions of Matlab where these opacity settings are not supported, these settings will be stored in the UserHandle of the figure, where saveFigure will search for the setting upon saving. Thus, the opacity will not be visible in Matlab but will be reflected in the saved PDF, PNG, or EPS file.

# Known limitations

- Because plot2svg manually reproduces Matlab figure in SVG format, some of the newer plotting tools released in R2014b are not fully supported yet. They can be added easily, but this requires crawling through Matlab's graphics object hierarchy and converting into an equivalent SVG format.
- Notably, legends are not currently supported in new versions of Matlab, though this hopefully won't be too difficult to add back in.

# Credit

saveFigure internally relies heavily on (and includes within it) code from:

- [plot2svg](http://www.mathworks.com/matlabcentral/fileexchange/7401-scalable-vector-graphics--svg--export-of-figures) by [Juerg Schwizer](http://www.zhinst.com/blogs/schwizer/)
- [copyfig](http://www.mathworks.com/matlabcentral/fileexchange/23629-export-fig) by Oliver Woodford and (Yair Altman)[http://undocumentedmatlab.com]
- [GetFullPath](http://www.mathworks.com/matlabcentral/fileexchange/28249-getfullpath) by Jan Simon
