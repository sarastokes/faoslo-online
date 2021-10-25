function initialize()
    % INITIALIZE
    %
    % Syntax:
    %   initialize()
    %
    % History:
    %   25Oct2021 - SSP
    % ---------------------------------------------------------------------

    thisDir = [fileparts(mfilename('fullpath')), filesep];

    if exist([thisDir, filesep, 'parameters.txt'], 'file')
        % Should we overwrite?
        out = questdlg('Overwrite parameters.txt file?', 'Overwrite Dialog',...
            'Yes', 'No', 'Cancel', 'Yes');
        if ismember(out, {'No', 'Cancel'})
            return
        end
    end

    fijiDir = uigetdir(cd, 'Pick FIJI installation directory');

    % Open file, discard existing contents
    fid = fopen([thisDir, filesep, 'parameters.txt'], 'w');
    fprintf(fid, ['fijiDir=', fijiDir, '\n']);
    fprintf(fid, ['repoDir=', thisDir, '\n']);
    fclose(fid);
