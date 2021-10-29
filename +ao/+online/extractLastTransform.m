function tform = extractLastTransform(fName)
    % EXTRACTLASTTRANSFORM
    %
    % Description:
    %   Get last transformation matrix from saved ImageJ log and convert to
    %   an affine2d transform
    % 
    % Syntax:
    %   tform = extractLastTransform(fName)
    %
    % History:
    %   24Oct2021 - SSP
    % ---------------------------------------------------------------------

    header = 'Transformation Matrix: AffineTransform[[';

    fid = fopen(fName, 'r');
    tline = fgetl(fid);
    while ischar(tline)
        if startsWith(tline, header)
            str = tline(numel(header) + 1 : end);
            str = erase(str, ']');
            str = erase(str, '[');
            str = erase(str, ',');
            t = strsplit(str, ' ');
        end
        tline = fgetl(fid);
    end
    fclose(fid);

    T = cellfun(@str2double, t);
    T = reshape(T, [3 2]);
    tform = affine2d([T, [0 0 1]']);



