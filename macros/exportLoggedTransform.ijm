// exportLoggedTransform.ijm
// 24Oct2021 - SSP

// Before calling this macro, MATLAB will set new image as active window
imageName = getTitle();
xStart = indexOf(imageName, ".tif");
imageName = substring(imageName, 0, xStart);
close();

// Save log contents contianing printed transformation matrix
selectWindow("Log");
saveAs("Text", "C:/Users/sarap/Desktop/OnlineReg/" + imageName + "_transform.txt");

// Close open images
selectWindow("Aligned 2 of 2");
close();
selectWindow("REF_image.png");
close();
selectWindow("NewStack");
close();


// Clear log 
print("\\Clear");
print("Exported transform as " + imageName + "_transform.txt");
