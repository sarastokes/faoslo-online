% ConvertAvi2Tif.m
%
% Open .avi file in ImageJ, save as .tif then open the .tiff file here
% ~25 seconds faster than using MATLAB VideoReader to load the avi directly 
%
% Variables sent to base workspace before analyzing:
% - experimentDir
% - newImageName
% - newImagePath 
%
% Variables sent back to the app:
% - ts
% 
% History:
%   24Oct2021 - SSP
%   01Nov2021 - SSP - Removed need for ConvertAvi2Tif.ijm call
% -------------------------------------------------------------------------

import ij.*;

tiffPath = [experimentDir, filesep, 'Analysis', filesep,... 
    strrep(newImageName, '.avi', '_temp.tiff')];

if ~exist(tiffPath, 'file')
    imv = ij.IJ.openImage([newImagePath, filesep, newImageName]);
    imv.show();
    
    IJ.saveAs("Tiff", java.lang.String(tiffPath));
    IJ.run('Close All');
else
    disp('Found cached .tif file');
end

ts = TIFFStack(tiffPath);
app.setNewVideo(ts);