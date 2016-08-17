function demo_saveFigure()    

    % Plot scatter plot with alpha blending
    randseed(1); figure(1); clf;
    N = 500; dx = randn(N, 1); dy = randn(N, 1);
    h = plot(dx, dy, 'o', 'MarkerFaceColor', [0.6 0.6 1], 'LineWidth', 0.1, 'MarkerEdgeColor', 'w', 'MarkerSize', 8);
    setMarkerOpacity(h, 0.3, 0.3);
    hold on
    N = 500; dx = randn(N, 1) + 1; dy = randn(N, 1);
    h = plot(dx, dy, 'o', 'MarkerFaceColor', [1 0.6 0.6], 'LineWidth', 0.1, 'MarkerEdgeColor', 'w', 'MarkerSize', 8);
    setMarkerOpacity(h, 0.3, 0.3);
    
    xlabel('Param 1'); ylabel('Param 2'); title('SaveFigure Demo');
    box off; axis equal;

    saveFigure('demoScatter.pdf', 'painters', true)


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

    saveFigure('demoTimeseries.pdf');
end

%% errorshade code

function [hl, hs] = errorshade(x, ym, ye, color, varargin)
% [ha] = shadeYInterval(x, y1, y2, varargin)
% shadeYInterval draws two lines on a plot and shades the area between those
% lines. ParamValues are same as for fill command (e.g. FaceColor,
% EdgeColor)
%

    p = inputParser();
    p.addParameter('showLine', true, @islogical);
    p.addParameter('errorColor', [], @(x) true);
    p.addParameter('lineArgs', {}, @iscell);
    p.addParameter('shadeArgs', {}, @iscell);
    p.addParameter('axh', [], @(x) true);
    p.addParameter('lineAlpha', 1, @isscalar);
    p.addParameter('errorAlpha', 1, @isscalar);
    p.addParameter('z', 0, @isscalar); % used for visual stacking on 2-d plots
    p.CaseSensitive = false;
    p.parse(varargin{:}); 
    
    z = p.Results.z;

    if isempty(p.Results.axh)
        axh = newplot;
    else
        axh = p.Results.axh;
    end
    
    y1 = ym - ye;
    y2 = ym + ye;
    
    if all(isnan(y1) | isnan(y2))
        hl = NaN;
        hs = NaN;
        return;
    end

    % plot the shaded area
    x = makerow(x);
    y1 = makerow(y1);
    y2 = makerow(y2);

    % desaturate the color for shading if not translucent
    if isempty(p.Results.errorColor)
        if p.Results.errorAlpha < 1
            shadeColor = color;
        else
            shadeColor = 1 - (1-color)*0.5;
        end
    else
        shadeColor = p.Results.errorColor;
    end
    
    % need to split the vecs
    nanMask = isnan(y1) | isnan(y2);
    offset = 1;
    while(offset < numel(x))
        % find next non-nan sample
        newOffset = find(~nanMask(offset:end), 1, 'first');
        if isempty(newOffset)
            break;
        end
        
        offset = offset+newOffset-1;
        nextNaN = find(nanMask(offset:end), 1, 'first');
        if isempty(nextNaN)
            regionEnd = numel(x);
        else
            regionEnd = nextNaN+offset - 2;
        end
        
        regionStart = offset;
        mask = regionStart:regionEnd;
        
        [hs] = shadeSimple(axh, x(mask), y1(mask), y2(mask), z, 'FaceColor', shadeColor, ...
            'alpha', p.Results.errorAlpha, p.Results.shadeArgs{:});
       
        offset = regionEnd + 1;
    end

    hold(axh, 'on');
    if p.Results.showLine
        if z ~=0
            zv = z*ones(size(v));
            hl = plot(x, ym, zv, 'Color', color, 'Parent', axh, p.Results.lineArgs{:});
        else
            hl = plot(x, ym, 'Color', color, 'Parent', axh, p.Results.lineArgs{:});
        end
        setLineOpacity(hl, p.Results.lineAlpha);
    else
        hl = NaN;
    end
    
end

function [ha] = shadeSimple(axh, x, y1, y2, z, varargin)

    p = inputParser();
    p.addParameter('FaceColor', [0.8 0.8 1], @(x) true);
    p.addParameter('EdgeColor', 'none', @(x) true);
    p.addParameter('alpha', 1, @isscalar);
    p.KeepUnmatched = false;
    p.parse(varargin{:});

    xv = [x, fliplr(x)];
    yv = [y1, fliplr(y2)];
    zv = z * ones(size(xv));

    ha = patch(xv, yv, zv, 'k', 'Parent', axh);
    set(ha, 'FaceColor', p.Results.FaceColor, ...
        'EdgeColor', p.Results.EdgeColor, 'Parent', axh, 'FaceAlpha', p.Results.alpha);

    % hide shading from legend
    set(get(get(ha, 'Annotation'), 'LegendInformation'), 'IconDisplayStyle', 'off');

    set(axh, 'Layer', 'top')

end


function vec = makerow( vec )
% convert vector to row vector

% leave size == [1 0] alone too
if(size(vec, 1) > size(vec,2) && isvector(vec)) && ~(size(vec, 2) == 0 && size(vec, 1) == 1)
    vec = vec';
end

if size(vec, 1) == 0 && size(vec, 2) == 1
    vec = vec';
end

end

