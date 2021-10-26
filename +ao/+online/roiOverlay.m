function [h, h2] = roiOverlay(im, rois, varargin)
    % ROIOVERLAY
    %
    % Syntax:
    %    [h, h2] = roiOverlay(im, rois, varargin)
    %
    % Inputs:
    %   im              double (will be converted if not)
    %       Image to overlay rois
    %   rois            struct or 2D matrix
    %       Roi structure or output of labelmatrix
    % Optional key/value inputs:
    %   Parent          axes handle
    %       Axis target for image, otherwise new figure is created
    %   Colormap        char or Nx3 matrix (default = 'gray')
    %       Colormap to use for base image
    %
    % Outputs:
    %   h               matlab.graphics.primitive.Image
    %       Handle to imagesc image containing rois
    %   h2              matlab.graphics.primitive.Image
    %       Handle to image underlying the rois
    %
    % See also:
    %   LABELMATRIX
    %
    % History:
    %   10Aug2020 - SSP
    %   23Aug2020 - SSP - Options to specify axis and base colormap
    %   25Oct2021 - SSP - Debug: specified 'ax' to imshow
    % ---------------------------------------------------------------------

    im = im2double(im);
    
    if isstruct(rois)  % roi structure
        roiMasks = labelmatrix(rois);
    else
        roiMasks = rois;
    end
    
    ip = inputParser();
    ip.CaseSensitive = false;
    addParameter(ip, 'Parent', [], @ishandle);
    addParameter(ip, 'Colormap', 'gray', @(x) isnumeric(x) || ischar(x));
    parse(ip, varargin{:});

    ax = ip.Results.Parent;
    if isempty(ax)
        ax = axes('Parent', figure());
    end

    cmap = ip.Results.Colormap;
    if ischar(cmap)
        cmap = colormap(cmap);
    end
   
    % Ensure mask will be highest value in colormap
    im = im / max(max(im));
    im = im * 0.98;

    % Binarize roi image
    roiMasks(roiMasks ~= 0) = 1;

    h2 = imshow(im, 'Parent', ax); hold(ax, 'on');
    cmap = [cmap; 0 1 1];
    colormap(ax, cmap);

    h = imagesc(ax, roiMasks);
    h.AlphaData = 0.3 * (roiMasks > 0);
    