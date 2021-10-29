function makeYAxisSymmetric(ax, roundToNearest)
    % MAKEYAXISSYMMETRIC
    %
    % Syntax:
    %   makeYAxisSymmetric(ax, roundToNearest)
    %
    % Inputs:
    %   ax          Axis handle
    % Optional inputs:
    %   roundToNearest      float (default = [])
    %       For 0.25, ylimits will round up to nearest 0.25
    %
    % History:
    %   26Oct2021 - SSP
    % ---------------------------------------------------------------------

    ylim(ax, 'auto');
    y = get(ax, 'YLim');
    maxVal = max(abs(y));

    if nargin == 2
        ind = 1 / roundToNearest;
        maxVal = ceil(ind*maxVal) / ind;
    end

    ylim(ax, maxVal * [-1 1]);