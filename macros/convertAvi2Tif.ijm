// convertAvi2Tif.ijm
// 24Oct2021 - SSP

// Hard-code this to reduce user interaction. 
tempDir = "C:/Users/sarap/Desktop/OnlineReg/";

// Before calling this macro, MATLAB will set new image as active window
imageName = getTitle();
xStart = indexOf(imageName, ".avi");
newName = substring(imageName, 0, xStart);

// Save as tiff
saveAs("Tiff", tempDir + newName + "_temp.tiff");
// Close out the images
close();
