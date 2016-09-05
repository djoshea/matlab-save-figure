function setLineOpacity(s, alpha)
% setLineOpacity(hLine, alpha)

%     [edge, face] = deal(cell(numel(s), 1));
    for i = 1:numel(s)
        
        % tag it as translucent for saveFigure to
        % pick up during SVG authoring
%         userdata = get(s(i),'UserData');
%         userdata.svg.LineAlpha = alpha;
%         set(s(i),'UserData', userdata);
            
        if ~verLessThan('matlab', '8.4')
%             % first cache marker opacity
%             if isempty(s(i).MarkerHandle) && ~isa(s(i).MarkerHandle, 'matlab.graphics.GraphicsPlaceholder')
%                 edge{i} = s(i).MarkerHandle.EdgeColorData;
%                 face{i} = s(i).MarkerHandle.FaceColorData;
%             end
            
            % use RGBA color specification
            s(i).Color(4) = alpha;
            
%              % keep transparent
%             addlistener(s(i),'MarkedClean',...
%                 @(ObjH, EventData) keepAlpha(ObjH, EventData, faceAlpha, edgeAlpha));
        end
    end
    
%     drawnow;
%     
%     for i = 1:length(s)
%         if ~isempty(edge{i})
%             s(i).MarkerHandle.EdgeColorData = edge;
%             s(i).MarkerHandle.FaceColorData = face;
%         end
%     end

end
% 
% function keepAlpha(src, ~, faceAlpha, edgeAlpha)  
%     mh = src.MarkerHandle;
%     if ~isempty(mh.EdgeColorData)
%         mh.EdgeColorType = 'truecoloralpha';
%         mh.EdgeColorData(4) = uint8(edgeAlpha*255);
%     end
%     if ~isempty(mh.FaceColorData)
%         mh.FaceColorType = 'truecoloralpha';
%         mh.FaceColorData(4) = uint8(faceAlpha*255);
%     end
% end
% 
