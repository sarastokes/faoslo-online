function [signal, xpts] = roiSignal(imStack, roiMask, sampleRate, bkgdWindow, medianFlag)
    % ROISIGNAL
    %
    % Syntax:
    %   roiSignal(imStack, roiMask, frameRate);
    % 
    % Inputs:
    %   imStack         3D matrix - [X, Y, T]
    %       Raw imaging data stack
    %   roiMask         binary 2D matrix [x, Y]
    %       Mask of designating ROI 
    %   sampleRate      numeric (default = 25)
    %       Samples/frames per second (Hz)
    %   bkgdWindow      vector [1 x 2]
    %       Start and stop frames for background estimate, returns dF/F
    %   medianFlag      logical (default = false)
    %       Use median flag for background estimation instead of mean
    %
    % Outputs:
    %   signal      vector - [1, T]
    %       Average response within ROI over time
    %   xpts        vector - [1, T]
    %       Time points associated with signal 
    %
    % See also:
    %   ROISIGNALPLOT, ROISIGNALS
    % 
    % History:
    %   22Aug2020 - SSP
    %   02Dec2020 - SSP - Added bkgd estimation options
    %   19Dec2020 - SSP - Removed first frame from analysis
    % --------------------------------------------------------------------
    
    % Get xpts while accounting for throwing out first blank frame
    xpts = 1/sampleRate : 1/sampleRate : (size(imStack, 3)+1)/sampleRate;
    xpts(1) = [];

    [a, b] = find(roiMask == 1);
    signal = zeros(numel(a), size(imStack, 3));
    for i = 1:numel(a)
        signal(i, :) = squeeze(imStack(a(i), b(i), :));
    end
    signal = mean(signal);
    
    if nargin >= 4 && ~isempty(bkgdWindow)
        if nargin < 5
            medianFlag = false;
        end
        if medianFlag
            bkgd = median(signal(bkgdWindow(1):bkgdWindow(2)));
        else
            bkgd = mean(signal(bkgdWindow(1):bkgdWindow(2)));
        end
        signal = (signal - bkgd) / bkgd;
    end