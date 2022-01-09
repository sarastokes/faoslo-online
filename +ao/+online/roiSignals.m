function [A, xpts] = roiSignals(imStack, L, sampleRate, bkgdWindow, medianFlag)    
    % ROISIGNALS
    %
    % Description:
    %   Calculates dF/F for multiple ROIs
    %
    % Syntax:
    %   [A, xpts] = roiSignals(imStack, L, sampleRate, bkgdWindow, medianFlag)
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
    %   signal      vector - [N, T]
    %       Average response over time for each ROI
    %   xpts        vector - [1, T]
    %       Time points associated with signal
    %
    % See also:
    %   ROISIGNAL
    % 
    % History:
    %   06Nov2020 - SSP
    %   02Dec2020 - SSP - Added bkgd estimation options
    % ---------------------------------------------------------------------
    if nargin < 4
        bkgdWindow = [];
    end
    if nargin < 5
        medianFlag = false;
    end

    L = double(L);

    roiList = unique(L(:));
    roiList(roiList == 0) = [];
    numROIs = numel(roiList);

    A = [];

    for i = 1:numROIs
        try
            [signal, xpts] = ao.online.roiSignal(imStack, L == roiList(i),... 
                sampleRate, bkgdWindow, medianFlag);
        catch
            signal = zeros([1, size(imStack, 3)]);
        end
        A = cat(1, A, signal);
    end
