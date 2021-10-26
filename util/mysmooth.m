function y = mysmooth(y, smoothFac, varargin)
    % MYSMOOTH
    %
    % Description: 
    %   Pads vector before smoothing to avoid edge effects
    %
    % Use matches the builtin Matlab function: SMOOTH
    %
    % History:
    %   11Nov2020 - SSP
    % ---------------------------------------------------------------------

    if size(y, 1) == 1
        padVal = [0, smoothFac];
    elseif size(y, 2) == 1
        padVal = [smoothFac, 0];
    else
        error('Input a vector');
    end

    y = padarray(y, padVal, mean(y), 'both');
    y = smooth(y, smoothFac, varargin);
    y(1:smoothFac) = [];
    y(end-smoothFac+1:end) = [];

    
