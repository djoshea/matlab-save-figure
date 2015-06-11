function setMarkerOpacity(s, faceAlpha, edgeAlpha)
% setMarkerOpacity(s, faceAlpha, [edgeAlpha=faceAlpha])

if nargin < 3
    edgeAlpha = faceAlpha;
end

for i = 1:length(s)
    % old version, simply tag it as translucent for saveFigure to pick
    % up during SVG authoring
    
    userdata = get(s(i),'UserData');
    userdata.svg.MarkerFaceAlpha = faceAlpha;
    userdata.svg.MarkerEdgeAlpha = edgeAlpha;
    set(s(i),'UserData', userdata);
        
    if ~verLessThan('matlab', '8.4')
        mh = s.MarkerHandle;
        if isa(mh, 'matlab.graphics.GraphicsPlaceholder')
            drawnow;
            mh = s.MarkerHandle;
        end
        
        if ~isempty(mh.EdgeColorData)
            mh.EdgeColorData(4) = uint8(edgeAlpha*255);
        end
        if ~isempty(mh.FaceColorData)
            mh.FaceColorData(4) = uint8(faceAlpha*255);
        end
    end

end