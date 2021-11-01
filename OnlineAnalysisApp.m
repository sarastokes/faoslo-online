classdef OnlineAnalysisApp < handle

    % Properties used by ImageJ-MATLAB in the base workspace
    properties (SetAccess = private)
        experimentDir   % Base directory for experiments
        newImage        % Newly acquired image (for registration)
        videoName       % Newly acquired video (for analysis)
    end

    % Properties with set functions
    properties (SetAccess = private)
        newVideo        % Epoch video
        tform           % affine2d transform
    end

    % Temporary properties associated with current video(s)
    properties (SetAccess = private)
        imBase
        roiBase         % ROI segmentation for target image
        numROIs         % Number of ROIs
        
        imReg           % Target image registered to new image
        roiReg          % ROIs registered to new image
        
        xpts            % X-axis (in seconds)
        tdata           % Time domain data
        fpts            % X-axis (frequency domain)
        fdata           % Frequency domain data
    end

    % User interface properties
    properties (Hidden, SetAccess = private)
        figureHandle
        imHandle
        baseHandle
        currentRoiIdx

        smoothData
        usingLEDs
        frequencyDomain
        heldData
    end
    
    properties (Hidden, Constant)
        ROI_INCREMENT = 10;
        FRAME_RATE = 25.3;
    end
    
    % Information that persists across videos
    properties (Hidden, SetAccess = private)
        prefs
        dataCache 
        stimTable
    end

    methods 
        function obj = OnlineAnalysisApp()
            obj.experimentDir = uigetdir(cd, 'Pick Experiment folder');
            addpath(genpath(obj.experimentDir));
            cd(obj.experimentDir);
            obj.experimentDir = [obj.experimentDir, filesep];
            
            % Make sure connection with ImageJ exists...
            fprintf('Opening ImageJ...\n');
            evalin('base', 'run(''ConnectToImageJ.m'')');
            % Send relevant variables to the base workspace
            assignin('base', 'experimentDir', obj.experimentDir);

            try
                obj.imBase = imread([obj.experimentDir, 'TargetImage.tif']);
            catch
                obj.imBase = imread([obj.experimentDir, 'TargetImage.png']);
            end
            obj.roiBase = dlmread([obj.experimentDir, 'TargetRois.txt']);
            obj.numROIs = max(obj.roiBase(:));
            
            obj.currentRoiIdx = 1;
            obj.smoothData = false;
            obj.frequencyDomain = false;
            obj.usingLEDs = false;

            obj.dataCache = containers.Map();
            obj.stimTable = [];

            % Initialize preferences
            obj.prefs = containers.Map();
            obj.prefs('signal1') = 1500;
            obj.prefs('signal2') = 2700;
            obj.prefs('bkgdWindow1') = 1;
            obj.prefs('bkgdWindow2') = 240;
            obj.prefs('AutoY') = true;
            obj.prefs('AutoX') = true;
            obj.prefs('yLim1') = -1;
            obj.prefs('yLim2') = 1;
            obj.prefs('xLim1') = 0;
            obj.prefs('xLim2') = 1500;
            
            obj.createUi();
        end
    end

    % Methods used from base workspace to accomodate ImageJ-MATLAB
    methods
        function setTransform(obj, tform)
            % SETTRANSFORM
            % -------------------------------------------------------------
            assert(isa(tform, 'affine2d'), 'Transform must be type affine2d');
            obj.tform = tform;
        end

        function setNewVideo(obj, newVideo)
            % SETNEWVIDEO
            % -------------------------------------------------------------
            obj.newVideo = newVideo;
            warning('off', 'MATLAB:imagesci:tiffmexutils:libtiffWarning');
            warning('off', 'imageio:tiffmexutils:libtiffWarning');
            if isa(obj.newVideo, 'TIFFStack')
                obj.newVideo = obj.newVideo(:,:,:);
            end
        end
    end
    
    methods (Access = private)
        function onKeyPress(obj, ~, evt)
            % ONKEYPRESS
            % -------------------------------------------------------------
            switch evt.Key
                case 'leftarrow'
                    newRoi = obj.currentRoiIdx - obj.ROI_INCREMENT;
                    if newRoi > 0
                        obj.currentRoiIdx = newRoi;
                        obj.showROIs();
                    end
                case 'rightarrow'
                    newRoi = obj.currentRoiIdx + obj.ROI_INCREMENT;
                    if newRoi < obj.numROIs
                        obj.currentRoiIdx = newRoi;
                        obj.showROIs();
                    end
                case 's'
                    if ~obj.smoothData
                        obj.smoothData = true;
                    else
                        obj.smoothData = false;
                    end
                    if ~isempty(obj.tdata) && ~obj.frequencyDomain
                        obj.showROIs();
                    end
                case 'f'
                    if ~obj.frequencyDomain
                        obj.frequencyDomain = true;
                        if ~isempty(obj.tdata) && isempty(obj.fdata)
                            obj.getFrequencyDomain();
                        end
                    else
                        obj.frequencyDomain = false;
                    end
                    if ~isempty(obj.tdata)
                        obj.showROIs();
                    end
            end
        end
        
        function onPush_loadNewData(obj, ~, ~)
            % ONPUSH_LOADNEWDATA
            % -------------------------------------------------------------
            
            % Change current directory to expected new image directory
            cd([obj.experimentDir, filesep, 'Vis']);
            [newImageName, newImagePath, ind] = uigetfile('*.avi',... 
                'Load registered video data');
            cd(obj.experimentDir);
            if ind == 0
                return;
            end
            
            x = strfind(newImageName, 'vis_');
            obj.videoName = newImageName(x:x+7);
                        
            % Check cache for video
            if isKey(obj.dataCache, obj.videoName)
                obj.tdata = obj.dataCache(obj.videoName);
                obj.fdata = [];
                return
            end
            
            % Send relevant variables to base workspace for ImageJ
            assignin('base', 'newImageName', newImageName);
            assignin('base', 'newImagePath', newImagePath);
            
            % Import video and image
            evalin('base', 'run(''ConvertAvi2Tif.m'')');
            
            obj.newImage = imread([newImagePath, filesep, strrep(newImageName, '.avi', '.tif')]);

            obj.registerData();

            obj.processData();
                        
            % Update the data cache
            obj.dataCache(obj.videoName) = obj.tdata;

            % Update the listbox 
            h = findByTag(obj.figureHandle, 'DataList');
            h.String = obj.dataCache.keys;
            h.Value = cellfind(h.String, obj.videoName);
            
            % Show plots of the ROIs
            obj.showROIs();
            title(findByTag(obj.figureHandle, 'ax_1'), obj.videoName,...
                'Interpreter', 'none', 'FontSize', 8);

            % Get stimulus name, if available
            try
                stimName = obj.getStimulusName();
            catch  % No stimulus or unrecognized format
                stimName = "Unknown";
            end
            
            if isempty(obj.stimTable)
                obj.stimTable = table(obj.name2id(obj.videoName), stimName,...
                    'VariableNames', {'EpochID', 'Stimulus'});
            else
                obj.stimTable{end+1, :} = [obj.name2id(obj.videoName), stimName];
            end
            
            h = findByTag(obj.figureHandle, 'List_Stim');
            h.String = unique(obj.stimTable.Stimulus);
        end
        
        function onSelect_Dataset(obj, src, ~)
            % ONSELECT_DATASET
            % -------------------------------------------------------------
            obj.videoName = src.String(src.Value);
            obj.videoName = obj.videoName{:};
            obj.tdata = obj.dataCache(obj.videoName);
            if obj.frequencyDomain
                obj.getFrequencyDomain();
            end
            title(findByTag(obj.figureHandle, 'ax_1'), obj.videoName);
            obj.showROIs();
        end   
        
        function onSelect_Stimulus(obj, src, ~)
            % ONSELECT_STIMULUS
            % -------------------------------------------------------------
            
            stimName = src.String{src.Value};
            
            ind = obj.stimTable.Stimulus == string(stimName);
            IDs = obj.stimTable{ind, 'EpochID'};
            
            newData = zeros(size(obj.tdata, 1), size(obj.tdata, 2), numel(IDs));
            for i = 1:numel(IDs)
                newData(:, :, i) = obj.dataCache(['vis_', int2fixedwidthstr(IDs(i), 4)]);
            end
            obj.tdata = mean(newData, 3);
            
            if obj.frequencyDomain
                obj.getFrequencyDomain();
            else
                obj.fData = [];
            end
            obj.videoName = stimName;
            obj.showROIs();
            title(findByTag(obj.figureHandle, 'ax_1'), obj.videoName);
        end
              
        function onCheck_HoldData(obj, src, ~)
            % ONCHECK_HOLDDATA
            % -------------------------------------------------------------
            
            if src.Value
                obj.heldData = obj.tdata;
                for i = 1:obj.ROI_INCREMENT
                    ax = obj.getNumberedAxis(i);
                    hNew = copyobj(findByTag(ax, 'SignalLine'), ax);
                    hNew.Tag = 'HeldLine';
                    hNew.Color = [0 0.5 0];
                end
            else
                obj.heldData = [];
                h = findall(obj.figureHandle, 'Tag', 'HeldLine');
                delete(h);
            end
        end

        function onCheck_AutoAxis(obj, src, ~)
            % ONCHECK_AUTOAXIS
            % -------------------------------------------------------------
            
            obj.prefs(src.Tag) = src.Value;

            if src.Value
                flag = 'off';
            else
                flag = 'on';
            end

            set(findByTag(obj.figureHandle, [lower(src.Tag(end)), 'Lim1']),...
                'Enable', flag);
            set(findByTag(obj.figureHandle, [lower(src.Tag(end)), 'Lim2']),...
                'Enable', flag);
        end

        function onCheck_UsingLEDs(obj, src, ~)
            obj.usingLEDs = src.Value;
        end

        function onChanged_Number(obj, src, ~)
            % ONCHANGED_NUMBER
            %   Generic callback to validate numeric inputs to edit fields
            % -------------------------------------------------------------
            
            tf = ao.online.ui.UiUtility.isValidNumber(src.String);
            if tf 
                set(src, 'ForegroundColor', 'k');
                obj.prefs(src.Tag) = str2double(src.String);
            else  % Change color to notify user of invalid input
                set(src, 'ForegroundColor', 'r');
            end
        end

        function onPush_Update(obj, ~, ~)
            % ONPUSH_UPDATE  
            %   Update prefs and replot results
            % -------------------------------------------------------------

            prefLayout = findByTag(obj.figureHandle, 'PrefLayout');
            
            h = findall(prefLayout, 'Style', 'edit');
            for i = 1:numel(h)
                obj.prefs(h(i).Tag) = str2double(h(i).String);
            end    
            obj.prefs('AutoY') = get(findByTag(prefLayout, 'AutoY'), 'Value'); 
            obj.showROIs();      
        end
    end
    
    methods 
        function ax = getNumberedAxis(obj, ind)
            % GETNUMBEREDAXIS
            %   Returns handle to axis #ind
            % -------------------------------------------------------------
            ax = findByTag(obj.figureHandle, ['ax_', num2str(ind)]);
        end
        
        function getFrequencyDomain(obj)
            % GETFREQUENCYDOMAIN
            % -------------------------------------------------------------
            obj.fdata = [];
            for i = 1:size(obj.tdata, 1)
                [p, obj.fpts] = ao.online.signalPowerSpectrum(...
                    obj.tdata(i, obj.prefs('signal1'):obj.prefs('signal2')),...
                    obj.FRAME_RATE);
                obj.fdata = cat(1, obj.fdata, p);
            end
        end
        
        function showROIs(obj)
            % SHOWROIS
            % -------------------------------------------------------------
            for i = 1:obj.ROI_INCREMENT
                idx = obj.currentRoiIdx + i - 1;
                ax = findobj(obj.figureHandle, 'Tag', sprintf('ax_%u', i));               
                h = findobj(ax, 'Tag', 'SignalLine');
                
                if idx > obj.numROIs
                    h.YData = zeros(size(h.YData));
                    if ~isempty(obj.heldData)
                        set(findByTag(ax, 'HeldLine'),... 
                            'YData', zeros(size(h.YData)));
                    end
                    ylabel(ax, ''); 
                    ylim(ax, [-1 1]);
                    continue
                end
                
                if ~obj.frequencyDomain                
                    h.XData = obj.xpts;             
                    if obj.smoothData 
                        h.YData = mysmooth(obj.tdata(idx, :), 100);
                    else
                        h.YData = obj.tdata(idx, :);
                    end
                    maxVal = max(abs(h.YData));
                
                    if ~isempty(obj.heldData)
                        h2 = findobj(ax, 'Tag', 'HeldLine');
                        if obj.smoothData
                            h2.YData = mysmooth(obj.heldData(idx, :), 100);
                        else
                            h2.YData = obj.heldData(idx, :);
                        end
                        maxVal = max([maxVal, max(abs(h2.YData))]);
                    end
                    if ~obj.prefs('AutoX')
                        xlim(ax, [floor(obj.xpts(1)), ceil(obj.xpts(end))]);
                    end
                    
                    if maxVal ~= 0  % missing ROI
                        makeYAxisSymmetric(ax);
                        set(ax, 'YTick', -maxVal:0.25:maxVal, 'YTickLabel', {});
                    end
                else
                    set(h, 'XData', obj.fpts, 'YData', obj.fdata(idx,:));
                    if ~obj.prefs('AutoX')
                        xlim(ax, [0, obj.FRAME_RATE/2]);
                    end
                    ylim(ax, 'auto');
                end
                
                % Generic plot appearance
                ylabel(ax, sprintf('ROI %u', idx));
                grid(ax, 'on');

                if ~obj.prefs('AutoY')
                    ylim(ax, [obj.prefs('yLim1'), obj.prefs('yLim2')]);
                    set(ax, 'YTick', obj.prefs('yLim1'):0.25:obj.prefs('yLim2'));
                end
                if ~obj.prefs('AutoX')
                    xlim(ax, [obj.prefs('xLim1'), obj.prefs('xLim2')]);
                end
            end
        end
        
        function registerData(obj)
            % REGISTERDATA
            % 
            % Description:
            %   Run SIFT reg in ImageJ from base workspace, handle results
            % -------------------------------------------------------------
            
            evalin('base', 'run(''DoSIFTRegistration.m'')');
            obj.tform = evalin('base', 'tform');
            
            newRefObj = imref2d(size(obj.newImage));
            baseRefObj = imref2d(size(obj.imBase));
            obj.roiReg = imwarp(obj.roiBase, baseRefObj, obj.tform,...
                'OutputView', newRefObj,...
                'interp', 'nearest');
            obj.imReg = imwarp(obj.imBase, baseRefObj, obj.tform,...
                'OutputView', newRefObj);
            
            % Plot the new image with registered ROIs
            cla(obj.imHandle);
            ao.online.roiOverlay(imadjust(obj.newImage), obj.roiReg,...
                'Parent', obj.imHandle);
            title(obj.imHandle, sprintf('%s - Registration Quality = %.3f',... 
                obj.videoName, ssim(obj.imReg, obj.newImage)),...
                'Interpreter', 'none');
            imshowpair(obj.imReg, obj.newImage, 'Parent', obj.baseHandle);
            title(obj.baseHandle, sprintf('%s - Registration Quality = %.3f',... 
                obj.videoName, ssim(obj.imReg, obj.newImage)),...
                'Interpreter', 'none');
        end

        function processData(obj)
            % PROCESSDATA
            %
            % Description:
            %   Process data determines how incoming videos are processed 
            %   and ultimately assigned to obj.data
            % -------------------------------------------------------------
            
            h = findall(obj.figureHandle, 'Tag', 'ZeroLine');
        
            [obj.tdata, obj.xpts] = ao.online.roiSignals(...
                obj.newVideo, obj.roiReg, obj.FRAME_RATE,... 
                [obj.prefs('bkgdWindow1') obj.prefs('bkgdWindow2')], false);
            obj.tdata(isnan(obj.tdata)) = 0;
            
            if ~obj.frequencyDomain
                for i = 1:numel(h)
                    h(i).XData = [floor(obj.xpts(1)), ceil(obj.xpts(end))];
                end
            else
                
                for i = 1:numel(h)
                    h(i).XData = [0 obj.FRAME_RATE/2];
                end
            end
        end

        function stimName = getStimulusName(obj)
            % EXTRACTEPOCHATTRIBUTES
            % 
            % Description:
            %   Load stimulus name from attributes file
            % -------------------------------------------------------------

            % Get stimulus parameter path
            expName = strsplit(obj.experimentDir, filesep);
            expIDs = strsplit(expName{end-1}, '_');
            source = expIDs{1}; 
            source = source(end-2:end);
            if ~obj.usingLEDs
                fileName = sprintf('%s_%s_ref_%s.txt', ...
                    source, expIDs{2}, obj.videoName(end-3:end));
            else
                expDate = expIDs{2};
                fileName = sprintf('%s_%s_ref_%s_%s_%s#%s_%s.txt',...
                    source, expDate, expDate(1:4), expDate(5:6), expDate(7:8),...
                    obj.videoName(end-2:end), obj.videoName(end-2:end));
            end
            filePath = [obj.experimentDir, filesep, 'Ref', filesep, fileName];

            % Pull the stimulus file name
            stimulusFileName = readProperty(filePath, 'Trial file name = ');
            txt = strsplit(stimulusFileName, filesep);
            stimName = txt{end};
            stimName = erase(stimName, '.txt');
            stimName = string(stimName);
        end
    end

    methods (Access = private)
        function createUi(obj)
            % CREATEUI
            %   Initialize user interface
            % -------------------------------------------------------------
            
            obj.figureHandle = figure(...
                'Name', 'Online Analysis',...
                'NumberTitle', 'off',...
                'DefaultUicontrolBackgroundColor', 'w',...
                'DefaultUicontrolFontSize', 10,...
                'Menubar', 'none',...
                'Toolbar', 'none',...
                'Color', 'w',...
                'KeyPressFcn', @obj.onKeyPress);
            obj.figureHandle.Position = screenCenter(...
                obj.figureHandle.Position(3), 1.5 * obj.figureHandle.Position(4));

            mainLayout = uix.HBox('Parent', obj.figureHandle,...
                'BackgroundColor', 'w');
            tabGroup = uitabgroup('Parent', mainLayout);
            
            % MAIN TAB: Left top panel with images
            t = uitab(tabGroup, 'Title', 'Main');
            imLayout = uix.VBox(...
                'Parent', uipanel(t, 'BackgroundColor', 'w'),...
                'BackgroundColor', 'w',...
                'Tag', 'imLayout');
            obj.baseHandle = axes(uipanel(imLayout, 'BackgroundColor', 'w'));
            % ao.online.roiOverlay(obj.imBase, obj.roiBase,...
            %     'Parent', obj.baseHandle);
            % axis(baseAxis, 'tight');
            % axis(obj.baseHandle, 'equal');
            % axis(baseAxis, 'off');
            % title(obj.baseHandle, 'Reference Image');

            obj.imHandle = axes(uipanel(imLayout, 'BackgroundColor', 'w'));
            
            uix.Empty('Parent', imLayout,...
                'BackgroundColor', 'w');
            
            % MAIN TAB: Left bottom panel with controls
            dataLayout = uix.HBox('Parent', imLayout,...
                'BackgroundColor', 'w');
            dataLayoutA = uix.VBox('Parent', dataLayout,...
                'BackgroundColor', 'w');
            uicontrol(dataLayoutA, 'Style', 'text',... 
                'String', 'Existing Data:');
            uicontrol(dataLayoutA, 'Style', 'listbox',...
                'Tag', 'DataList',...
                'Callback', @obj.onSelect_Dataset);
            uicontrol(dataLayoutA, 'Style', 'push',...
                'String', 'Load New Data',...
                'Callback', @obj.onPush_loadNewData);
            set(dataLayoutA, 'Heights', [17 -1 20]);
            dataLayoutB = uix.VBox('Parent', dataLayout,...
                'BackgroundColor', 'w');
            uicontrol(dataLayoutB,... 
                'Style', 'check',...
                'String', 'Hold Data',...
                'Tag', 'Check_HoldData',...
                'Callback', @obj.onCheck_HoldData);
            uicontrol(dataLayoutB,...
                'Style', 'list',...
                'Tag', 'List_Stim',...
                'Callback', @obj.onSelect_Stimulus);
            set(dataLayoutB, 'Heights', [15 -1]);
            set(imLayout, 'Heights', [-1 -1 10 120]);

            % PREFS
            t = uitab(tabGroup, 'Title', 'Prefs');
            
            prefLayout = uix.VBox(...
                'Parent', uipanel(t, 'BackgroundColor', 'w'),...
                'Tag', 'PrefLayout',...
                'BackgroundColor', 'w');
            uicontrol(prefLayout,...
                'Style', 'text',...
                'FontSize', 14,...
                'String', 'USER PREFERENCES');
            heights = 25;
            
            uix.Empty('Parent', prefLayout,...
                'BackgroundColor', 'w');
            xaxisLayout = uix.HBox('Parent', prefLayout);
            uicontrol(xaxisLayout,...
                'Style', 'check',...
                'String', 'Auto X Axis',...
                'Value', true,...
                'Tag', 'AutoX',...
                'Callback', @obj.onCheck_AutoAxis);
            ao.online.ui.UiUtility.horizontalBoxWithTwoCells(...
                xaxisLayout, 'X Axis Limits:',...
                'xLim1', 'xLim2',...
                'Enable', 'off',...
                'Callback', @obj.onChanged_Number);
            set(xaxisLayout, 'Widths', [-1 -2]);
            heights = [heights, -1, 40];
            
            uix.Empty('Parent', prefLayout,...
                'BackgroundColor', 'w');
            yaxisLayout = uix.HBox('Parent', prefLayout);
            uicontrol(yaxisLayout,...
                'Style', 'check',...
                'String', 'Auto Y Axis',...
                'Value', true,...
                'Tag', 'AutoY',...
                'Callback', @obj.onCheck_AutoAxis);
            ao.online.ui.UiUtility.horizontalBoxWithTwoCells(...
                yaxisLayout, 'Y Axis Limits:',...
                'yLim1', 'yLim2',...
                'Enable', 'off',...
                'Callback', @obj.onChanged_Number);
            set(yaxisLayout, 'Widths', [-1 -2]);
            heights = [heights, 15, 40];
            
            
            % Parameters to set before importing new data
            uix.Empty('Parent', prefLayout,...
                'BackgroundColor', 'w');                        
            uicontrol(prefLayout,...
                'Style', 'text',...
                'FontWeight', 'bold',...
                'FontSize', 12,...
                'String', 'Set before importing new data:');
            heights = [heights, -2, 20];

            uix.Empty('Parent', prefLayout,...
                'BackgroundColor', 'w');
            
            uicontrol(prefLayout,...
                'Style', 'check',...
                'String', 'Using LEDs',...
                'Value', false,...
                'Callback', @obj.onCheck_UsingLEDs);
            heights = [heights, 10, 25];
            
            uix.Empty('Parent', prefLayout,...
                'BackgroundColor', 'w');
            ao.online.ui.UiUtility.horizontalBoxWithTwoCells(...
                prefLayout, 'Signal window (in frames):',...
                'signal1', 'signal2',...
                'Callback', @obj.onChanged_Number);
            heights = [heights, -1, 40];
            
            uix.Empty('Parent', prefLayout,...
                'BackgroundColor', 'w');
            
            [h1, h2] = ao.online.ui.UiUtility.horizontalBoxWithTwoCells(...
                prefLayout, 'Background window (in frames):',...
                'bkgdWindow1', 'bkgdWindow2',...
                'Callback', @obj.onChanged_Number);
            h1.String = num2str(obj.prefs('bkgdWindow1'));
            h2.String = num2str(obj.prefs('bkgdWindow2'));
            uicontrol(prefLayout,...
                'Style', 'text',...
                'String', '0 0 = no background subtraction');
            heights = [heights, -1, 40, 20];
           
            uix.Empty('Parent', prefLayout,...
                'BackgroundColor', 'w');

            uicontrol(prefLayout,...
                'Style', 'push',...
                'String', 'Update Prefs',...
                'Callback', @obj.onPush_Update);
            heights = [heights, -1, 30];
            assignin('base', 'heights', heights);
            
            set(prefLayout, 'Heights', heights);

            h = findall(prefLayout, 'Style', 'edit');
            for i = 1:numel(h)
                h(i).String = num2str(obj.prefs(h(i).Tag));
            end
            
            % PLOTS: Right panel with ROI plots
            plotLayout = uix.VBox('Parent', mainLayout,...
                'BackgroundColor', 'w');
            for i = 1:obj.ROI_INCREMENT
                ax = axes(uipanel(plotLayout, 'BackgroundColor', 'w'),...
                    'Tag', sprintf('ax_%u', i));
                hold(ax, 'on');
                if i < obj.ROI_INCREMENT
                    set(ax, 'XTickLabel', []);
                end
                plot(ax, [0 1], [0 0],... 
                    'LineWidth', 0.75,... 
                    'Color', [0.45 0.45 0.45],...
                    'Tag', 'ZeroLine');
                plot(ax, [0 1], [0 0],... 
                    'LineWidth', 1.5,... 
                    'Color', [0 0 0.3],...
                    'Tag', 'SignalLine');
            end
            
            set(mainLayout, 'Widths', [-1 -0.75]);
        end
    end
    
    methods (Static) 
        function repoDir = getRepoDir()
            % GETREPODIR
            % -------------------------------------------------------------
            repoDir = fileparts(mfilename('fullpath'));
        end
        
        function ID = name2id(vidName)
            % NAME2ID
            % -------------------------------------------------------------
            ID = str2double(vidName(end-2:end));
        end

        function vidName = id2name(ID)
            % ID2NAME
            % -------------------------------------------------------------
            vidName = ['vis_', int2fixedwidthstr(ID, 4)];
        end
    end
end 