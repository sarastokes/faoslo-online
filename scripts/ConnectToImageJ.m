% CONNECTTOIMAGEJ
%
% Description:
%   Check whether ImageJ is running, if not connect
%
% Requires:
%   - User preferences file with 'fijiDir' set (see README.md)
%   - FIJI with ImageJ-MATLAB plugin 
%
% History:
%   24Oct2021 - SSP
%   29Oct2021 - SSP - Removed hard-coded directories, macro installs
%   03Nov2021 - SSP - Coverage for situations where ImageJ was open before
% -------------------------------------------------------------------------

try 
    % Previous ImageJ connection
    if isempty(ij.IJ.getInstance())
        run('getUserPreferences.m');
        addpath(fijiDir);
        ImageJ;
    end
catch
    % No previous ImageJ connection
    run('getUserPreferences.m');
    addpath(fijiDir);
    ImageJ;
end
