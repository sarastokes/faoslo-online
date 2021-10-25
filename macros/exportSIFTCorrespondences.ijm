// exportSIFTCorrespondences.ijm
// 23Oct2021 - SSP

// Hard-code this to reduce user interaction. 
saveDir = "C:/Users/sarap/Desktop/";

// Active window set by MATLAB before calling macro
imageTitle = getTitle();

run("Measure");
selectWindow("Results");
saveAs("Results", saveDir + imageTitle + ".csv");
// saveAs("Results", "C:/Users/sarap/Desktop/MyNewResults.csv");