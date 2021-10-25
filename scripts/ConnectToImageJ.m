% Check whether ImageJ is running, if not connect and install macros

if ~exist('IJM', 'var')
    addpath('C:/Users/sarap/Documents/FIJI/Fiji.app/scripts/');
    ImageJ;
    ij.IJ.run("Install...", "install=C:/Users/sarap/Dropbox/Postdoc/Code/imagej-tools/exportLoggedTransform.ijm");
    ij.IJ.run("Install...", "install=C:/Users/sarap/Dropbox/Postdoc/Code/imagej-tools/convertAvi2Tif.ijm");
end