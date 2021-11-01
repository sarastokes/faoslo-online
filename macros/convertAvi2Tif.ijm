// convertAvi2Tif.ijm
// 24Oct2021 - SSP
// 01Nov2021 - SSP - No longer necessary

// Hard-code this to reduce user interaction. 
tempDir = "C:/Users/sarap/Desktop/OnlineReg/";
print("Current: ", getDirectory("current"));

// Before calling this macro, MATLAB will set new image as active window
imageName = getTitle();

// Get the file name without the extension
xStart = indexOf(imageName, ".avi");
newName = substring(imageName, 0, xStart);

// Navigate to the analysis directory
// thisDir = getDirectory("image");
// print(thisDir);
// xStart = indexOf(thisDir, "Vis");
// newDir = substring(thisDir, 0, xStart);
// print(newDir);

// print(newDir + "Analysis" + File.separator + newName + "_temp.tiff");


// Save as tiff
saveAs("Tiff", tempDir + newName + "_temp.tiff");
// Close out the images
// close();
