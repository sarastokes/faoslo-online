function [p, f] = signalPowerSpectrum(signal, sampleRate, varargin)
    % SIGNALPOWERSPECTRUM
    %
    % Syntax:
    %   [p, f] = signalPowerSpectrum(signal, sampleRate, verbose)
    %
    % Inputs:
    %   signal          vector 
    %       Data for calculating power spectrum
    %   sampleRate      numeric
    %       Samples per second (Hz)
    % Optional inputs:
    %   plot            logical (default = false)
    %       Plot the output 
    %
    % Outputs:
    %   p               vector
    %       Power spectrum
    %   f               vector
    %       Frequencies (from 0 to sampleRate/2)
    %
    % History:
    %   23Aug2020 - SSP
    %   29Oct2021 - SSP - added compatibility with existing plots
    % ---------------------------------------------------------------------

    ip = inputParser();
    ip.CaseSensitive = false;
    addParameter(ip, 'Plot', false, @islogical);
    addParameter(ip, 'Parent', [], @ishandle);
    parse(ip, varargin{:});
    
    ax = ip.Results.Parent;
    plotFlag = ip.Results.Plot;
    
    if ~isempty(ax)
        plotFlag = true;
    end
    
    if ip.Results.Plot && isempty(ip.Results.Parent)
        ax = axes('Parent', figure());
        hold(ax, 'on');
        title('ROI Power Spectrum');
        xlabel('Frequency (Hz)');
    end
    
    y = fft(signal);

    f = (0:(length(y)-1))*(sampleRate/length(y));
    p = abs(y) .^ 2/length(y);

    % For simplicity, keep only half
    f = f(1:floor(numel(f)/2));
    p = p(1:floor(numel(p)/2));

    if plotFlag
        plot(ax, f, p, 'Tag', 'PowerSpectrum');
        xlim([0, sampleRate / 2]);
        grid on;
    end