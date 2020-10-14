function scale = getFigureSizeScale()

    scale = getenv('FIGURE_SIZE_SCALE');
    if isempty(scale)
        scale = 1;
    else
        scale = str2double(scale);
    end

end
