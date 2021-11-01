# faoslo-online
Online analysis for calcium imaging with fluorescence adaptive optics scanning laser ophthalmoscopes

## Setup
The analysis software anticipates your experiment directory follows the lab's conventions. Your experiment folder should be arranged as follows:

- ```\Analysis``` - temporary files containing the transformations and file conversions will be saved here. After the experiment and online analysis is over, you are free to keep them for later use or discard them. 
- ```\Ref``` - reflectance PMT channel, contains .txt files with stimulus information. 
- `\Vis` - visible PMT channel, anticipated folder containing newly acquired and registered videos to analyze
- ```TargetImage.tif``` - an image from a previous session for registration with your new data. Use one of the images output from Qiang's software if possible as the properties will most resemble the registered images produced during the experiment. 
- ```TargetRois.txt``` - the ROIs from the target image in a label matrix. 

In the main `faoslo-online` folder, create a file called `getUserPreferences.m` and paste in the following text:
```matlab
fijiDir='';
```
Fill in the full file path to your FIJI installation (the folder called Fiij.app that contains the actual ImageJ application and folders for macros, luts, etc.). This is needed to establish the connection between MATLAB and ImageJ. 


## Use
Open MATLAB and run the following line from the command line: 

```matlab
app = OnlineAnalysisApp();
``` 

You will be prompted to select your experiment file, as described above. 

Before importing data, go to the "Prefs" tab and ensure the settings under the header "Set before importing new data" are accurate. You only need the signal window if you intend to look at the frequency response. The background window dictates the F - F0 calculation. 

Click `Load New Video` to load, register and analyze a new video. Once you have multiple epochs loaded, you can choose which epoch to view on the right list box. If there are stimuli associated with the videos, you can choose them to see an average of all epochs using that stimulus. Use the arrow keys to navigate through the ROIs and `s` to smooth or unsmooth the data. Press `f` to switch to frequency domain. If the keys don't work, click somewhere on the plot side of the window, then try again.

NOTE: A quirk of the software that communicates with MATLAB-ImageJ plugin is that it cannot be easily used from inside a function, only scripts or the command line. For this reason, it was necessary for the app to occasionally use the base workspace. As long as you have the OnlineAnalysisApp open, don't delete the `app` variable you created when instantiating it. If you wanted to open a second instance, make sure to assign it to a different variable. 

## Requirements
- MATLAB 2015a or higher with "MATLAB Support for MinGW-w64 C/C++ Compiler" installed
- FIJI with the [MATLAB-ImageJ](https://sites.imagej.net/MATLAB) plugin installed 

## Dependencies
Other than the requirements above, the `faoslo-online` package stands alone. The following open source toolboxes are included in the `\lib` folder:
- [GUI Layout Toolbox](https://www.mathworks.com/matlabcentral/fileexchange/47982-gui-layout-toolbox)
- [TIFFStack](https://github.com/DylanMuir/TIFFStack)

