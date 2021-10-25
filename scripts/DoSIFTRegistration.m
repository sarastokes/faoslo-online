% DoSIFTRegistration
% 
% History:
%   24Oct2021 - SSP
% -------------------------------------------------------------------------

TEMP_DIR = 'C:\Users\sarap\Desktop\OnlineReg\';
% Check to see whether this dataset was already processed
if exist([TEMP_DIR, newName(1:end-4), '_transform.txt'], 'file')    
    % Read the saved log output, extract transform, convert to MATLAB affine2d
    tform = extractLastTransform([TEMP_DIR, newName(1:end-4), '_transform.txt']);
    return
end
ij.IJ.run("Install...", "install=C:/Users/sarap/Dropbox/Postdoc/Code/imagej-tools/exportLoggedTransform.ijm");

% Open the reference image in ImageJ
img = ij.IJ.openImage([parentDir, '\Analysis\REF_image.png']);
img.show();

% Open the newly acquired image in ImageJ
newName = [newName(1:end-3), 'tif'];
img2 = ij.IJ.openImage([filePath, filesep, newName]);
img2.show();

% Create a stack with the REF image second 
ij.IJ.run("Images to Stack", "name=NewStack title=[] use keep");
ij.IJ.selectWindow("NewStack");
ij.IJ.run("Reverse");

% Align REF image to new image
ij.IJ.run("Linear Stack Alignment with SIFT", "initial_gaussian_blur=1.60 steps_per_scale_octave=3 minimum_image_size=64 maximum_image_size=1024 feature_descriptor_size=4 feature_descriptor_orientation_bins=8 closest/next_closest_ratio=0.92 maximal_alignment_error=25 inlier_ratio=0.05 expected_transformation=Rigid interpolate show_transformation_matrix");

% Export the transform (printed to ImageJ's log)
ij.IJ.selectWindow(newName);
ij.IJ.run("exportLoggedTransform");

% Read the saved log output, extract transform, convert to MATLAB affine2d
tform = extractLastTransform([TEMP_DIR, newName(1:end-4), '_transform.txt']);

% OnlineAnalysisApp will request the variable 'tform'
