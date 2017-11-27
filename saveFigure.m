function fileList = saveFigure(varargin)
% saveFigure('filename.pdf', figh)
% fileList = saveFigure('filename', figh, 'ext', {'pdf', 'fig', 'png', 'eps'})
%
% Saves a figure to a variety of formats by automatically determining the
% best approach to take. v20160418. Currently, this looks like:
%
% If Matlab thinks the figure is too complex to use the painters renderer,
% then we save as EPS (using opengl renderer) and convert to PDF using epstopdf,
% then we convert to other formats via imagemagick's convert. If the figure is
% simple enough for painters, then we save as SVG using print -dsvg, then convert
% to pdf using inkscape, then to other formats using imagemagick's convert.
% Obviously this is complicated, but I haven't found the other approaches
% to work consistently.
%
%   * Images look identical across platforms (Mac OS, Linux)
%   * Images look identical across different formats, since all conversion
%       uses tools outside of Matlab
%   * All fonts in figure can be set to any TrueType / OpenType font
%       that is installed on your system and will render correctly
%
% You must install image-magick and inkscape before using, e.g.
%   Ubuntu/Debian: sudo apt-get install imagemagick inkscape
%   Mac via Homebrew: brew install imagemagick inkscape
%   [I would download inkscape on Mac directly, building it takes a while!]
%
% Currently not supported for Windows, though adding this shouldn't be too
% difficult. Mostly just need to get the system() calls to work properly.
%
% If the script cannot find imagemagick's convert, set the environment vars
%
% Required
%
%   name : name for figure(s), in one of the following forms:
%       string :
%           if name has an extension at the end, only that format will be saved
%           if name has no extension at the end, extensions in exts will be
%               added
%       cellstr : each entry corresponds to one extension, names must have
%           valid extendsion
%       struct : field value .(ext) will be used for each extension ext
%
% Optional:
%
%   figh : figure handle, [default=gcf]
%
% Param / Value pairs:
%
%   ext : list of extensions to use when name does not have extension already,
%           default={'pdf', 'png', 'svg'}.
%           Options include: 'fig', 'png', 'svg', 'eps', 'pdf'
%
%   quiet : print status messages [default = true]
%
% Usage Examples:
%  saveFigure('figureName.pdf');
%  fileList = saveFigure('figureName', gcf, 'ext', {'pdf', 'fig', 'png'});
%  saveFigure('figureName.png', gcf, 'fontName', 'Helvetica');
%
% Dan O'Shea dan@djoshea.com
% (c) 2014-2015
%
% This code internally relies heavily on:
%   plot2svg : Juerg Schwizer [ http://www.zhinst.com/blogs/schwizer/ ]
%   copyfig : Oliver Woodford
%   GetFullPath: Jan Simon
%
extListFull = {'fig', 'png', 'svg', 'eps', 'pdf'};
extListDefault = {'fig', 'pdf', 'png'};

p = inputParser;
p.addOptional('name', '', @(x) ischar(x) || iscellstr(x) || isstruct(x) || isa(x, 'function_handle'));
p.addOptional('figh', gcf, @ishandle);
p.addParameter('ext', [], @(x) ischar(x) || iscellstr(x));
p.addParameter('quiet', true, @islogical);
p.addParameter('notes', '', @ischar);
p.addParameter('resolution', 300, @isscalar);

% set to override resolution to achieve specific pixel width
p.addParameter('rasterWidthPixels', [], @(x) isempty(x) || isscalar(x));

p.addParameter('defaultFont', get(0, 'DefaultAxesFontName'), @ischar);
p.addParameter('preventOutlinedFonts', true, @islogical); % set fonts all to default font to ensure they aren't outlined

p.addParameter('painters', [], @(x) isempty(x) || islogical(x)); % set to true to force vector rendering when otherwise not possible
p.addParameter('upsample', 1, @isscalar); % improve the rendering quality by rendering to a larger SVG canvas then downsampling. especially useful for small markers or figure sizes, set this to 5-10

%     p.KeepUnmatched = true;
p.parse(varargin{:});
hfig = p.Results.figh;
name = p.Results.name;
ext = p.Results.ext;
quiet = p.Results.quiet;
resolution = p.Results.resolution;

hfig.InvertHardcopy = 'off';

if isempty(name)
    name = get(hfig, 'Name');
end

% build a map with .ext = file with ext
fileInfo = containers.Map('KeyType', 'char', 'ValueType', 'char');

% parse name and extensions, build fileInfo map
if isstruct(name)
    fields = fieldnames(name);
    for iF = 1:fields
        fileInfo(fields{iF}) = GetFullPath(name.(fields{iF}));
    end
    
elseif iscell(name) % expect each argument to have extension already
    assert(isempty(ext), 'Extension list invalid with cell name argument');
    [extList] = cellfun(@getExtensionFromFile, name, 'UniformOutput', false);
    for iF = 1:length(extList)
        if ~ismember(extList{iF}, extList)
            error('Could not extract valid extension from file name %s', name{iF});
        end
        fileInfo(extList{iF}) = GetFullPath(name{iF});
    end
    
elseif ischar(name) % may or may not have extension
    
    extFromName = getExtensionFromFile(name);
    if ismember(extFromName, extListFull)
        % single file name with extension
        assert(isempty(ext), 'Extension list invalid when name argument already has extension');
        fileInfo(extFromName) = GetFullPath(name);
    else
        % single file name with no extension, use extension list
        % (default if not found)
        if isempty(ext)
            ext = extListDefault;
        end
        if ~iscell(ext)
            ext = {ext};
        end
        for iE = 1:numel(ext)
            fileInfo(ext{iE}) = GetFullPath(sprintf('%s.%s', name, ext{iE}));
        end
    end
else
    error('Unknown format for argument name');
end

values = fileInfo.values;
[pathFinal, nameFinal] = fileparts(values{1});

% save figure notes
if ~isempty(p.Results.notes)
    notes = p.Results.notes;
    notesFile = fullfile(pathFinal, [nameFinal, '.notes.txt']);
    [fid, msg] = fopen(notesFile, 'w');
    if fid == -1
        error('Error opening notes file %s : %s', notesFile, msg);
    end
    
    fprintf(fid, '%s', notes);
    fprintf(fid, '\n\nSaved on %s\n\nFile list:\n', datestr(now));
    for iKey = 1:fileInfo.Count
        fprintf(fid, '%s\n', values{iKey});
    end
    fclose(fid);
end

% check extensions
extList = fileInfo.keys;
nonSupported = setdiff(extList, extListFull);
if ~isempty(nonSupported)
    error('Non-supported extensions %', strjoin(nonSupported, ', '));
end

fileList = {}; % files saved
tempList = {}; % temp files saved to be deleted

% Save fig format
if fileInfo.isKey('fig')
    file = fileInfo('fig');
    fileList{end+1} = file;
    if ~quiet
        printmsg('fig', file);
    end
    saveas(hfig, file, 'fig');
end

% make sure the size of the figure is WYSIWYG
set(hfig, 'PaperUnits' ,'centimeters');
set(hfig, 'Units', 'centimeters');
%     set(hfig, 'PaperPositionMode', 'auto');
pos = hfig.Position;
figSizeCm = pos(3:4);

% prevent font outlining by setting everything to a boring font here
% these will be patched back to default font in patchSvgFile
if p.Results.preventOutlinedFonts
    figSetFonts(hfig, 'FontName', 'SansSerif');
end

% check the figure complexity and determine which path to take
checker = matlab.graphics.internal.PrintVertexChecker.getInstance();
exceedsLimits = ~checker.exceedsLimits(hfig); %#ok<NASGU>

% change normalized units to data units when possible
% normalized units get messed up when upsampling
axh = findall(hfig, 'Type', 'Axes');
objNormalizedUnits = findall(axh, 'Units', 'normalized', '-not', 'Type', 'Axes');
set(objNormalizedUnits, 'Units', 'data');

% trick Matlab into rendering everything at higher resolution
jc = findobjinternal(hfig, '-isa', 'matlab.graphics.primitive.canvas.JavaCanvas', '-depth', 1);
if isa(jc, 'matlab.graphics.GraphicsPlaceholder')
    warning('Could not determine screen DPI: JavaCanvas not found');
    renderDPI = 72;
else
    origDPI = jc.ScreenPixelsPerInch;
    if p.Results.upsample > 1
        renderDPI = origDPI * p.Results.upsample;
        if ~isempty(jc)
            %             jc.OpenGL = 'off';
            jc.ScreenPixelsPerInch = renderDPI;
            if exist('AutoAxis', 'class')
                AutoAxis.updateFigure();
            end
        end
    else
        renderDPI = origDPI;
    end
end

%     usePainters = true;
%     if usePainters
% start with svg format, convert to pdf, then to other formats
needPdf = any(ismember(setdiff(extList, {'fig', 'svg'}), extList));
needSvg = needPdf || any(ismember(extList, 'svg'));

% save svg format first
if needSvg
    if fileInfo.isKey('svg')
        % use actual file name
        file = fileInfo('svg');
        fileList{end+1} = file;
        if ~quiet
            printmsg('svg', file);
        end
    else
        % use a temp file name
        file = [tempname '.svg'];
        tempList{end+1} = file;
    end
    
    svgFile = file;
    
    % use Matlab's built in svg engine (from Batik Graphics2D for
    % java)
    set(hfig,'Units','pixels');   % All data in the svg-file is saved in pixels
    %             set(hfig, 'Position', round(get(hfig, 'Position')));
    % we specify the resolution because complicated figures will
    % save as an image, though we shouldn't get here
    
    drawnow;
    
    % force painters renderer if requested
    if ~isempty(p.Results.painters) && p.Results.painters
        rendArgs = {'-painters'};
    else
        rendArgs = {};
    end
    print(hfig, rendArgs{:}, sprintf('-r%g', resolution), '-dsvg', file);
    %             print(hfig, '-dsvg', '-painters', file);
    
    % now we have to change the svg header to match the size that
    % we want the output to be because Inkscape doesn't determine
    % this correctly
    widthStr = sprintf('%.3fcm', figSizeCm(1));
    heightStr = sprintf('%.3fcm', figSizeCm(2));
    patchSvgFile(svgFile, widthStr, heightStr, renderDPI / origDPI, p.Results.defaultFont);
end

if needPdf
    if fileInfo.isKey('pdf')
        % use actual file name
        file = fileInfo('pdf');
        fileList{end+1} = file;
        if ~quiet
            printmsg('pdf', file);
        end
    else
        % use a temp file name
        file = [tempname '.pdf'];
        tempList{end+1} = file;
    end
    
    % convert to pdf using inkscape
    convertSvgToPdf(svgFile, file);
    
    pdfFile = file;
end

% cleanup
if ~isempty(jc)
    jc.ScreenPixelsPerInch = origDPI;
end
set(objNormalizedUnits, 'Units', 'normalized');

if p.Results.preventOutlinedFonts
    figSetFonts(hfig, 'FontName', p.Results.defaultFont);
end

% this path never worked particularly well on Mac with fonts
%     else
%         % save to eps, then convert to pdf
%         needPdf = any(ismember(setdiff(extList, {'fig', 'eps'}), extList));
%         needEps = needPdf || any(ismember(extList, 'eps'));
%
%         if needEps
%             if fileInfo.isKey('eps')
%                 % use actual file name
%                 file = fileInfo('eps');
%                 fileList{end+1} = file;
%                 if ~quiet
%                     printmsg('pdf', file);
%                 end
%             else
%                 % use a temp file name
%                 file = [tempname '.eps'];
%                 tempList{end+1} = file;
%             end
%             if ~quiet
%                 printmsg('eps', file);
%             end
%
%             epsFile = file;
%
% %             print(hfig, sprintf('-r%d', resolution), '-depsc', file);
%             print2eps(file, hfig, struct('fontswap', false), sprintf('-r%d', resolution));
%         end
%
%         if needPdf
%             if fileInfo.isKey('pdf')
%                 % use actual file name
%                 file = fileInfo('pdf');
%                 fileList{end+1} = file;
%                 if ~quiet
%                     printmsg('pdf', file);
%                 end
%             else
%                 % use a temp file name
%                 file = [tempname '.pdf'];
%                 tempList{end+1} = file;
%             end
%
%             % convert to pdf using inkscape
%             pdfFile = file;
%             convertEpsToPdf(epsFile, pdfFile);
%         end
%     end

if fileInfo.isKey('png')
    file = fileInfo('png');
    fileList{end+1} = file;
    
    if ~quiet
        printmsg('png', file);
    end
    
    if ~isempty(p.Results.rasterWidthPixels)
        % widthPx == figSizeIn * resolution
        resolution =  p.Results.rasterWidthPixels / (figSizeCm(1) / 2.54);
    end
    convertPdf(pdfFile, file, resolution);
end

%     if fileInfo.isKey('hires.png')
%         file = fileInfo('hires.png');
%         fileList{end+1} = file;
%         if ~quiet
%             printmsg('hires.png', file);
%         end
%
%         convertPdf(pdfFile, file, true);
%     end

%     if fileInfo.isKey('svg') && ~usePainters
%         file = fileInfo('svg');
%         fileList{end+1} = file;
%         if ~quiet
%             printmsg('svg', file);
%         end
%
%         convertPdf(pdfFile, file);
%     end

if fileInfo.isKey('eps')
    file = fileInfo('eps');
    fileList{end+1} = file;
    if ~quiet
        printmsg('eps', file);
    end
    
    convertPdf(pdfFile, file);
end

% delete temporary files
for tempFile = tempList
    delete(tempFile{1});
end

fileList = makecol(fileList);

end

function patchSvgFile(svgFile, widthStr, heightStr, scaleViewBoxBy, fontName)
% 1. replaces first width="..." and height="..." and adds a viewbox to size
%    the SVG file appropriately for Inkscape processing
% 2. adds a small stroke to the outside of patch objects to hide white
% lines

str = fileread(svgFile);

% first we need to know the current size
tokens = regexp(str, 'width="(\d+)"', 'tokens', 'once');
assert(~isempty(tokens), 'Could not find width in SVG file');
widthPx = str2double(tokens{1});
tokens = regexp(str, 'height="(\d+)"', 'tokens', 'once');
assert(~isempty(tokens), 'Could not find height in SVG file');
heightPx = str2double(tokens{1});

viewBoxStr = sprintf('viewBox="0 0 %g %g"', widthPx * scaleViewBoxBy, heightPx * scaleViewBoxBy);

str = regexprep(str, 'width="\d+"', sprintf('width="%s"', widthStr), 'once');
str = regexprep(str, 'height="\d+"', sprintf('height="%s" %s', heightStr, viewBoxStr), 'once');


% replace SansSerif and Dialog with Helvetica
str = regexprep(str, 'font-family:''Dialog''', sprintf('font-family:''%s''', fontName));
str = regexprep(str, 'font-family:''SansSerif''', sprintf('font-family:''%s''', fontName));
str = regexprep(str, 'font-family:sans-serif', sprintf('font-family:''%s''', fontName));

% add a small stroke to paths with no stroke to hide rendering
% issues
str = regexprep(str, '(<path [^/]* style="fill:rgb)(\([0-9,]+\))(;[^/]*)stroke:none;', '$1$2$3stroke:rgb$2; stroke-width:0.1;');

% make sure images aren't blurred
str = regexprep(str, '(<image [^>]*style=")([^>]*>)', '$1image-rendering: pixelated !important; $2');

fid = fopen(svgFile, 'w');
fprintf(fid, '%s', str);
fclose(fid);
end

function convertSvgToPdf(svgFile, pdfFile)
% use Inkscape to convert pdf
%     if ismac
%         inkscapePath = '/usr/local/bin/inkscape';
%         if ~exist(inkscapePath, 'file')
%             error('Could not locate Inkscape at %s', inkscapePath);
%         end
%     else
inkscapePath = getenv('INKSCAPE_PATH');
if isempty(inkscapePath)
    inkscapePath = 'inkscape';
end
%     end

% MATLAB has it's own older version of libtiff.so inside it, so we
% clear that path when calling imageMagick to avoid issues
cmd = sprintf('export LANG=en_US.UTF-8; export LD_LIBRARY_PATH=""; export DYLD_LIBRARY_PATH=""; %s --export-pdf=%s %s', ...
    inkscapePath, escapePathForShell(pdfFile), escapePathForShell(svgFile));
%cmd = sprintf('%s --export-pdf %s %s', inkscapePath, escapePathForShell(pdfFile), escapePathForShell(svgFile));
[status, result] = system(cmd);

if status
    fprintf('Error converting svg file. Is Inkscape configured correctly?\n');
    fprintf(result);
    fprintf('\n');
end
end

function convertEpsToPdf(epsFile, pdfFile)
% use Inkscape to convert pdf
if ismac
    epsToPdfPath = '/Library/TeX/texbin/epstopdf';
else
    epsToPdfPath = 'epstopdf';
end

% MATLAB has it's own older version of libtiff.so inside it, so we
% clear that path when calling imageMagick to avoid issues
cmd = sprintf('export LANG=en_US.UTF-8; export LD_LIBRARY_PATH=""; export DYLD_LIBRARY_PATH=""; %s --res=%d -o=%s %s', ...
    epsToPdfPath, resolution, escapePathForShell(pdfFile), escapePathForShell(epsFile));
%cmd = sprintf('%s --export-pdf %s %s', inkscapePath, escapePathForShell(pdfFile), escapePathForShell(svgFile));
[status, result] = system(cmd);

if status
    fprintf('Error converting svg file. Is Inkscape configured correctly?\n');
    fprintf(result);
    fprintf('\n');
end
end

function convertPdf(pdfFile, file, resolution)
% call imageMagick convert on pdfFile --> file

%     if ismac
%         convertPath = '/usr/local/bin/convert';
%         if ~exist(convertPath, 'file')
%             error('Could not locate convert at %s', convertPath);
%         end
%     else
%             convertPath = 'convert';
%     end

convertPath = getenv('IMAGEMAGICK_CONVERT_PATH');
if isempty(convertPath)
    convertPath = 'convert';
end

% MATLAB has it's own older version of libtiff.so inside it, so we
% clear that path when calling imageMagick to avoid issues
%     cmd = sprintf('export LD_LIBRARY_PATH=""; export DYLD_LIBRARY_PATH=""; convert -verbose -quality 100 -density %d %s -resize %d%% %s', ...
%         density, escapePathForShell(pdfFile), resize, escapePathForShell(file));
cmd = sprintf('export LD_LIBRARY_PATH=""; export DYLD_LIBRARY_PATH=""; %s -verbose -density %d %s -resample %d %s', ...
    convertPath, resolution, escapePathForShell(pdfFile), resolution, escapePathForShell(file));
[status, result] = system(cmd);

if status
    fprintf('Error converting pdf file. Are ImageMagick and Ghostscript installed?\n');
    fprintf(result);
    fprintf('\n');
end
end

function printmsg(ex, file)
fprintf('Saving %s as %s\n', ex, file);
end

function [ext, fileSansExt] = getExtensionFromFile(file)
[fPath, fName, dotext] = fileparts(file);
if ~isempty(dotext)
    if strcmp(dotext, '.png')
        ext = 'png';
    else
        ext = dotext(2:end);
    end
else
    ext = '';
end
fileSansExt = fullfile(fPath, fName);
end

function str = strjoin(strCell, join)
% str = strjoin(strCell, join)
% creates a string by concatenating the elements of strCell, separated by the string
% in join (default = ', ')
%
% e.g. strCell = {'a','b'}, join = ', ' [ default ] --> str = 'a, b'

if nargin < 2
    join = ', ';
end

if isempty(strCell)
    str = '';
else
    if isnumeric(strCell) || islogical(strCell)
        % convert numeric vectors to strings
        strCell = arrayfun(@num2str, strCell, 'UniformOutput', false);
    elseif iscell(strCell)
        strCell = cellfun(@num2str, strCell, 'UniformOutput', false);
    end
    
    strCell = cellfun(@num2str, strCell, 'UniformOutput', false);
    
    str = cellfun(@(str) [str join], strCell, ...
        'UniformOutput', false);
    str = [str{:}];
    str = str(1:end-length(join));
end
end

function path = escapePathForShell(path)
% path = escapePathForShell(path)
% Escape a path to a file or directory for embedding within a shell command
% passed to cmd or unix.

path = strrep(path, ' ', '\ ');
end

function File = GetFullPath(File)
% GetFullPath - Get absolute path of a file or folder [MEX]
% FullName = GetFullPath(Name)
% INPUT:
%   Name: String or cell string, file or folder name with or without relative
%         or absolute path.
%         Unicode characters and UNC paths are supported.
%         Up to 8192 characters are allowed here, but some functions of the
%         operating system may support 260 characters only.
%
% OUTPUT:
%   FullName: String or cell string, file or folder name with absolute path.
%         "\." and "\.." are processed such that FullName is fully qualified.
%         For empty strings the current directory is replied.
%         The created path need not exist.
%
% NOTE: The Mex function calls the Windows-API, therefore it does not run
%   on MacOS and Linux.
%   The magic initial key '\\?\' is inserted on demand to support names
%   exceeding MAX_PATH characters as defined by the operating system.
%
% EXAMPLES:
%   cd(tempdir);                    % Here assumed as C:\Temp
%   GetFullPath('File.Ext')         % ==>  'C:\Temp\File.Ext'
%   GetFullPath('..\File.Ext')      % ==>  'C:\File.Ext'
%   GetFullPath('..\..\File.Ext')   % ==>  'C:\File.Ext'
%   GetFullPath('.\File.Ext')       % ==>  'C:\Temp\File.Ext'
%   GetFullPath('*.txt')            % ==>  'C:\Temp\*.txt'
%   GetFullPath('..')               % ==>  'C:\'
%   GetFullPath('Folder\')          % ==>  'C:\Temp\Folder\'
%   GetFullPath('D:\A\..\B')        % ==>  'D:\B'
%   GetFullPath('\\Server\Folder\Sub\..\File.ext')
%                                   % ==>  '\\Server\Folder\File.ext'
%   GetFullPath({'..', 'new'})      % ==>  {'C:\', 'C:\Temp\new'}
%
% COMPILE: See GetFullPath.c
%   Run the unit-test uTest_GetFullPath after compiling.
%
% Tested: Matlab 6.5, 7.7, 7.8, 7.13, WinXP/32, Win7/64
% Compiler: LCC 2.4/3.8, OpenWatcom 1.8, BCC 5.5, MSVC 2008
% Author: Jan Simon, Heidelberg, (C) 2010-2011 matlab.THISYEAR(a)nMINUSsimon.de
%
% See also Rel2AbsPath, CD, FULLFILE, FILEPARTS.

% $JRev: R-x V:023 Sum:BNPK16hXCfpM Date:22-Oct-2011 00:51:51 $
% $License: BSD (use/copy/change/redistribute on own risk, mention the author) $
% $UnitTest: uTest_GetFullPath $
% $File: Tools\GLFile\GetFullPath.m $
% History:
% 001: 20-Apr-2010 22:28, Successor of Rel2AbsPath.
% 010: 27-Jul-2008 21:59, Consider leading separator in M-version also.
% 011: 24-Jan-2011 12:11, Cell strings, '~File' under linux.
%      Check of input types in the M-version.
% 015: 31-Mar-2011 10:48, BUGFIX: Accept [] as input as in the Mex version.
%      Thanks to Jiro Doke, who found this bug by running the test function for
%      the M-version.
% 020: 18-Oct-2011 00:57, BUGFIX: Linux version created bad results.
%      Thanks to Daniel.

% Initialize: ==================================================================
% Do the work: =================================================================

% #############################################
% ### USE THE MUCH FASTER MEX ON WINDOWS!!! ###
% #############################################

% Difference between M- and Mex-version:
% - Mex-version cares about the limit MAX_PATH.
% - Mex does not work under MacOS/Unix.
% - M is remarkably slower.
% - Mex calls Windows system function GetFullPath and is therefore much more
%   stable.
% - Mex is much faster.

% Disable this warning for the current Matlab session:
%   warning off JSimon:GetFullPath:NoMex
% If you use this function e.g. under MacOS and Linux, remove this warning
% completely, because it slows down the function by 40%!
%warning('JSimon:GetFullPath:NoMex', ...
%  'GetFullPath: Using slow M instead of fast Mex.');

% To warn once per session enable this and remove the warning above:
%persistent warned
%if isempty(warned)
%   warning('JSimon:GetFullPath:NoMex', ...
%           'GetFullPath: Using slow M instead of fast Mex.');
%    warned = true;
% end

% Handle cell strings:
% NOTE: It is faster to create a function @cell\GetFullPath.m under Linux,
% but under Windows this would shadow the fast C-Mex.
if isa(File, 'cell')
    for iC = 1:numel(File)
        File{iC} = GetFullPath(File{iC});
    end
    return;
end

isWIN = strncmpi(computer, 'PC', 2);

% DATAREAD is deprecated in 2011b, but available:
hasDataRead = ([100, 1] * sscanf(version, '%d.%d.', 2) <= 713);

if isempty(File)  % Accept empty matrix as input
    if ischar(File) || isnumeric(File)
        File = cd;
        return;
    else
        error(['JSimon:', mfilename, ':BadInputType'], ...
            ['*** ', mfilename, ': Input must be a string or cell string']);
    end
end

if ischar(File) == 0  % Non-empty inputs must be strings
    error(['JSimon:', mfilename, ':BadInputType'], ...
        ['*** ', mfilename, ': Input must be a string or cell string']);
end

if isWIN  % Windows: --------------------------------------------------------
    FSep = '\';
    File = strrep(File, '/', FSep);
    
    isUNC   = strncmp(File, '\\', 2);
    FileLen = length(File);
    if isUNC == 0                        % File is not a UNC path
        % Leading file separator means relative to current drive or base folder:
        ThePath = cd;
        if File(1) == FSep
            if strncmp(ThePath, '\\', 2)   % Current directory is a UNC path
                sepInd  = strfind(ThePath, '\');
                ThePath = ThePath(1:sepInd(4));
            else
                ThePath = ThePath(1:3);     % Drive letter only
            end
        end
        
        if FileLen < 2 || File(2) ~= ':'  % Does not start with drive letter
            if ThePath(length(ThePath)) ~= FSep
                if File(1) ~= FSep
                    File = [ThePath, FSep, File];
                else  % File starts with separator:
                    File = [ThePath, File];
                end
            else     % Current path ends with separator, e.g. "C:\":
                if File(1) ~= FSep
                    File = [ThePath, File];
                else  % File starts with separator:
                    ThePath(length(ThePath)) = [];
                    File = [ThePath, File];
                end
            end
            
        elseif isWIN && FileLen == 2 && File(2) == ':'   % "C:" => "C:\"
            % "C:" is the current directory, if "C" is the current disk. But "C:" is
            % converted to "C:\", if "C" is not the current disk:
            if strncmpi(ThePath, File, 2)
                File = ThePath;
            else
                File = [File, FSep];
            end
        end
    end
    
else         % Linux, MacOS: ---------------------------------------------------
    FSep = '/';
    File = strrep(File, '\', FSep);
    
    if strcmp(File, '~') || strncmp(File, '~/', 2)  % Home directory:
        HomeDir = getenv('HOME');
        if ~isempty(HomeDir)
            File(1) = [];
            File    = [HomeDir, File];
        end
        
    elseif strncmpi(File, FSep, 1) == 0
        % Append relative path to current folder:
        ThePath = cd;
        if ThePath(length(ThePath)) == FSep
            File = [ThePath, File];
        else
            File = [ThePath, FSep, File];
        end
    end
end

% Care for "\." and "\.." - no efficient algorithm, but the fast Mex is
% recommended at all!
if contains(File, [FSep, '.'])
    if isWIN
        if strncmp(File, '\\', 2)  % UNC path
            index = strfind(File, '\');
            if length(index) < 4    % UNC path without separator after the folder:
                return;
            end
            Drive            = File(1:index(4));
            File(1:index(4)) = [];
        else
            Drive     = File(1:3);
            File(1:3) = [];
        end
    else  % Unix, MacOS:
        isUNC   = false;
        Drive   = FSep;
        File(1) = [];
    end
    
    hasTrailFSep = (File(length(File)) == FSep);
    if hasTrailFSep
        File(length(File)) = [];
    end
    
    if hasDataRead
        if isWIN  % Need "\\" as separator:
            C = dataread('string', File, '%s', 'delimiter', '\\');  %#ok<REMFF1>
        else
            C = dataread('string', File, '%s', 'delimiter', FSep);  %#ok<REMFF1>
        end
    else  % Use the slower REGEXP in Matlab > 2011b:
        C = regexp(File, FSep, 'split');
    end
    
    % Remove '\.\' directly without side effects:
    C(strcmp(C, '.')) = [];
    
    % Remove '\..' with the parent recursively:
    R = 1:length(C);
    for dd = reshape(find(strcmp(C, '..')), 1, [])
        index    = find(R == dd);
        R(index) = [];
        if index > 1
            R(index - 1) = [];
        end
    end
    
    if isempty(R)
        File = Drive;
        if isUNC && ~hasTrailFSep
            File(length(File)) = [];
        end
        
    elseif isWIN
        % If you have CStr2String, use the faster:
        %   File = CStr2String(C(R), FSep, hasTrailFSep);
        File = sprintf('%s\\', C{R});
        if hasTrailFSep
            File = [Drive, File];
        else
            File = [Drive, File(1:length(File) - 1)];
        end
        
    else  % Unix:
        File = [Drive, sprintf('%s/', C{R})];
        if ~hasTrailFSep
            File(length(File)) = [];
        end
    end
end

end

%% Plot2SVG

function vec = makecol( vec )
% transpose if it's currently a row vector (unless its 0 x 1, keep as is)
    if (size(vec,2) > size(vec, 1) && isvector(vec)) && ~(size(vec, 1) == 0 && size(vec, 2) == 1)
        vec = vec';
    end
    if size(vec, 1) == 1 && size(vec, 2) == 0
        vec = vec';
    end
end

function figSetFonts(varargin)
% figSetFonts(hfig, 'Property', val, ...) or figSetFonts('Property', val, ...)
%
% Applies a set of properties to all text objects in figure hfig (defaults
% to gcf if ommitted).
%
% Example: figSetFonts('FontSize', 18);

p = inputParser;
p.addOptional('hfig', gcf, @ishandle);
p.KeepUnmatched = true;
p.parse(varargin{:});
hfig = p.Results.hfig;

hfont = findobj(hfig, '-property', 'FontName');
set(hfont, p.Unmatched);

% handle all the rest (Title,
htext = findall(hfig, 'Type', 'Text');
set(htext, p.Unmatched);
end




