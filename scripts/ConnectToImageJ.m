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
    % Previous ImageJ connection in matlab session
    if isempty(ij.IJ.getInstance())
        fijiDir = getpref('ao_tools', 'fiji_path');
        addpath(fijiDir);
        ImageJ;
    end
catch
    % No previous ImageJ connection
    try 
        fijiDir = getpref('ao_tools', 'fiji_path'); 
    catch
        error('No fiji_path preference found! See README');
    end
    addpath(fijiDir);
    ImageJ;
end
