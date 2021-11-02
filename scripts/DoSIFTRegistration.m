% DoSIFTRegistration
% 
% History:
%   24Oct2021 - SSP
%   29Oct2021 - SSP - Removed call to imagej macro
% -------------------------------------------------------------------------

% Variables sent to base workspace before analyzing:
% - experimentDir
% - newImageName
% - newImagePath

% Variables to send back to app:
% - tform

import ij.*;

analysisDir = [experimentDir, filesep, 'Analysis', filesep];
    
% Open the reference image in ImageJ
img = IJ.openImage([experimentDir, filesep, 'TargetImage.png']);
img.show();

% Open the newly acquired image in ImageJ
newImageName = [newImageName(1:end-3), 'tif'];
img2 = ij.IJ.openImage([newImagePath, filesep, newImageName]);
img2.show();

% Create a stack with the Target image second 
IJ.run("Images to Stack", "name=NewStack title=[] use keep");
IJ.selectWindow("NewStack");
IJ.run("Reverse");

% Align Target image to new image
IJ.run("Linear Stack Alignment with SIFT", "initial_gaussian_blur=1.60 steps_per_scale_octave=3 minimum_image_size=64 maximum_image_size=1024 feature_descriptor_size=4 feature_descriptor_orientation_bins=8 closest/next_closest_ratio=0.92 maximal_alignment_error=25 inlier_ratio=0.05 expected_transformation=Rigid interpolate show_transformation_matrix");

% Export the transform (printed to ImageJ's log)
IJ.selectWindow(newImageName);
str = char(IJ.getLog());

% Extract transform from Log output and convert to MATLAB affine2d
tform = extractLastTransform(str);

% Close out all the windows
IJ.run('Close All');

% Send to OnlineAnalysisApp
app.setTransform(tform);

