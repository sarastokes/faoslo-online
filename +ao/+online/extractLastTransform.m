function tform = extractLastTransform(str)
    % EXTRACTLASTTRANSFORM
    %
    % Description:
    %   Get last transformation matrix from saved ImageJ log and convert to
    %   an affine2d transform
    % 
    % Syntax:
    %   tform = extractLastTransform(str)
    %
    % Inputs:
    %   str         char
    %       Log output from SIFT reg or .txt file containing output
    %
    % History:
    %   24Oct2021 - SSP
    %   29Oct2021 - SSP - Support for direct char input
    % ---------------------------------------------------------------------

    header = 'Transformation Matrix: AffineTransform[[';

    if isfile(str)
        fid = fopen(str, 'r');
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
    else
        ind1 = strfind(str, header);       
        str = str(ind1(end) + numel(header) : end);
        ind2 = strfind(str, newline);
        str = str(1:ind2(1) - 1);
        
        str = erase(str, ']');
        str = erase(str, '[');
        str = erase(str, ',');
        t = strsplit(str, ' ');
    end

    T = cellfun(@str2double, t);
    T = reshape(T, [3 2]);
    tform = affine2d([T, [0 0 1]']);
