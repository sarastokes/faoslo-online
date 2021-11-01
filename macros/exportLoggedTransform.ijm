// exportLoggedTransform.ijm
// 24Oct2021 - SSP

// Before calling this macro, MATLAB will set new image as active window
imageName = getTitle();
xStart = indexOf(imageName, ".tif");
imageName = substring(imageName, 0, xStart);
// thisDir = File.getDefaultDir();
// print(thisDir);

close();

// Save log contents contianing printed transformation matrix
selectWindow("Log");
// saveAs("Text", thisDir + File.separator + imageName + "_transform.txt");
saveAs("Text", "C:/Users/sarap/Desktop/OnlineReg/" + imageName + "_transform.txt");

// Close open images
selectWindow("Aligned 2 of 2");
close();
selectWindow("TargetImage.png");
close();
selectWindow("NewStack");
close();


// Clear log 
print("\\Clear");
print("Exported transform as " + imageName + "_transform.txt");
