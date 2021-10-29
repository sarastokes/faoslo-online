function lineValue = readProperty(filePath, header)
    % READPROPERTY  
    %
    % Description:
    %   Read specific property from parameter file
    %
    % Syntax:
    %   lineValue = readProperty(filePath, header)
    %
    % History:
    %   26Oct2021 - SSP - moved from ao.core.Dataset
    % -------------------------------------------------------------
    
    fid = fopen(filePath, 'r');
    if fid == -1
        warning('File %s could not be opened', filePath);
        lineValue = 'NaN'; 
        return
    end
    
    lineValue = [];
    tline = fgetl(fid);
    while ischar(tline)
        ind = strfind(tline, header);
        if ~isempty(ind)
            lineValue = tline(ind + numel(header) : end);
            break
        else
            tline = fgetl(fid);
        end
    end
    fclose(fid);
        