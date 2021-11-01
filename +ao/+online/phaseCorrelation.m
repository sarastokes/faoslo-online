function [tform, imReg] = phaseCorrelation(im1, im2)
    % RUNPHASECORRELATION
    %  
    % Syntax:
    %   [imReg, tform] = runPhaseCorrelation(im1, im2)
    %
    % Description:
    %   Register im2 to im1 with phase correlation
    %
    % History:
    %   28Feb2021 - SSP
    %-----------------------------------------------------------

    fixedRefObj = imref2d(size(im1));
    movingRefObj = imref2d(size(im2));

    tform = imregcorr(im2, movingRefObj, im1, fixedRefObj,...
        'Transform', 'similarity',...
        'Window', true);
        
    if nargout == 2
        imReg = imwarp(im2, movingRefObj, tform,...
            'OutputView', fixedRefObj);
    end