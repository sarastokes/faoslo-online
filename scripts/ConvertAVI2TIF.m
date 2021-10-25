% Open .avi file in ImageJ, save as .tif then open the .tiff file here
% ~25 seconds faster than using MATLAB VideoReader to load the avi directly 

TEMP_DIR = 'C:\Users\sarap\Desktop\OnlineReg\';
if exist([TEMP_DIR, filesep, strrep(newName, '.avi', '_temp.tiff')], 'file')
    ts = TIFFStack([TEMP_DIR, filesep, strrep(newName, '.avi', '_temp.tiff')]);
    return
end

imv = ij.IJ.openImage([filePath, filesep, newName]);
imv.show();

ij.IJ.run("Install...", "install=C:/Users/sarap/Dropbox/Postdoc/Code/imagej-tools/convertAvi2Tif.ijm");
ij.IJ.run("convertAvi2Tif");

warning('off', 'MATLAB:imagesci:tiffmexutils:libtiffWarning');
ts = TIFFStack([TEMP_DIR, filesep, strrep(newName, '.avi', '_temp.tiff')]);
