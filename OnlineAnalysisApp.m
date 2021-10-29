classdef OnlineAnalysisApp < handle

    % Properties that can be accessed by the base workspace
    properties (SetAccess = private)
        experimentDir
        newImage
        videoName
    end

    % Properties with set functions
    properties (SetAccess = private)
        newVideo        % Epoch video
        tform           % affine2d transform
    end

    properties (SetAccess = private)
        imBase
        roiBase         % ROI segmentation for target image
        numROIs         % Number of ROIs
        
        imReg           % Target image registered to new image
        roiReg          % ROIs registered to new image
        
        xpts
        data
    end

    % User interface properties
    properties (Hidden, SetAccess = private)
        figureHandle
        imHandle
        currentRoiIdx
        
        smoothData
        heldData
    end
    
    properties (Hidden, Constant)
        ROI_INCREMENT = 10;
        FRAME_RATE = 25;
        BKGD_WINDOW = [1 240];
    end
    
    properties (Hidden, Access = private)
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
            obj.dataCache = containers.Map();
            
            obj.createUi();
            obj.userPrefChange();
        end
        
        function setTransform(obj, tform)
            % SETTRANSFORM
            assert(isa(tform, 'affine2d'), 'Transform must be type affine2d');
            obj.tform = tform;
        end

        function setNewVideo(obj, newVideo)
            % SETNEWVIDEO
            obj.newVideo = newVideo;
        end
    end

    methods (Access = private)
        function loadNewData(obj)
        end
    end
    
    methods (Access = private)
        function onKeyPress(obj, ~, evt)
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
                    if ~isempty(obj.data)
                        obj.showROIs();
                    end
            end
        end
        
        function onPush_loadNewData(obj, ~, ~)
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
                obj.data = obj.dataCache(obj.videoName);
                return
            end
            
            % Send relevant variables to base workspace for ImageJ
            assignin('base', 'newImageName', newImageName);
            assignin('base', 'newImagePath', newImagePath);
            
            % Import video and image
            evalin('base', 'run(''ConvertAvi2Tif.m'')');
            obj.newVideo = evalin('base', 'ts');
            
            try
                obj.newImage = imread(strrep([newImagePath, filesep, newImageName], '.avi', '.tif'));
            catch
                obj.newImage = imread(strrep([newImagePath, filesep, newImageName], '.avi', '.png'));
            end
            
            obj.registerData();

            obj.processData();
                        
            % Update the data cache
            obj.dataCache(obj.videoName) = obj.data;
            h = findByTag(obj.figureHandle, 'DataList');
            h.String = obj.dataCache.keys;
            h.Value = numel(h.String);
            
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
                obj.stimTable = [obj.stimTable; ... 
                    table(obj.name2id(obj.videoName), stimName,...
                    'VariableNames', {'EpochID', 'Stimulus'})];
            end
            
            h = findByTag(obj.figureHandle, 'List_Stim');
            h.String = unique(obj.stimTable.Stimulus);
        end
        
        function onSelect_Dataset(obj, src, ~)
            % ONSELECT_DATASET
            obj.videoName = src.String(src.Value);
            obj.videoName = obj.videoName{:};
            obj.data = obj.dataCache(obj.videoName);
            title(findByTag(obj.figureHandle, 'ax_1'), obj.videoName);
            obj.showROIs();
        end   
        
        function onSelect_Stimulus(obj, src, ~)
            % ONSELECT_STIMULUS
            stimName = src.String{src.Value};
            
            ind = obj.stimTable.Stimulus == string(stimName);
            IDs = obj.stimTable{ind, 'EpochID'};
            
            newData = zeros(size(obj.data, 1), size(obj.data, 2), numel(IDs));
            for i = 1:numel(IDs)
                newData(:, :, i) = obj.dataCache(['vis_', int2fixedwidthstr(IDs(i), 4)]);
            end
            obj.data = mean(newData, 3);
            obj.videoName = stimName;
            obj.showROIs();
            title(findByTag(obj.figureHandle, 'ax_1'), obj.videoName);
        end
              
        function onCheck_HoldData(obj, src, ~)
            % ONCHECK_HOLDDATA
            if src.Value
                obj.heldData = obj.data;
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
    end
    
    methods 
        function ax = getNumberedAxis(obj, ind)
            % GETNUMBEREDAXIS
            ax = findByTag(obj.figureHandle, ['ax_', num2str(ind)]);
        end
        
        function showROIs(obj)
            % SHOWROIS
            for i = 1:obj.ROI_INCREMENT
                idx = obj.currentRoiIdx + i - 1;
                ax = findobj(obj.figureHandle, 'Tag', sprintf('ax_%u', i));               
                h = findobj(ax, 'Tag', 'SignalLine');
                
                if idx > size(obj.data, 1)
                    h.YData = zeros(size(h.YData));
                    if ~isempty(obj.heldData)
                        set(findByTag(ax, 'HeldLine'),... 
                            'YData', zeros(size(h.YData)));
                    end
                    ylabel(ax, ''); 
                    ylim(ax, [-1 1]);
                    continue
                end
                
                h.XData = obj.xpts;             
                if obj.smoothData 
                    h.YData = mysmooth(obj.data(idx, :), 100);
                else
                    h.YData = obj.data(idx, :);
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
                
                % Plot appearance
                xlim(ax, [floor(obj.xpts(1)), ceil(obj.xpts(end))]);
                if maxVal ~= 0  % missing ROI
                    makeYAxisSymmetric(ax);
                    set(ax, 'YTick', -maxVal:0.25:maxVal, 'YTickLabel', {});
                end
                ylabel(ax, sprintf('ROI %u', idx));
                grid(ax, 'on');
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
            roiOverlay(obj.newImage, obj.roiReg,...
                'Parent', obj.imHandle);
            title(obj.imHandle, 'New Data',...
                'Interpreter', 'none');
        end

        function processData(obj)
            % PROCESSDATA
            %
            % Description:
            %   Process data determines how incoming videos are processed 
            %   and ultimately assigned to obj.data
            % -------------------------------------------------------------
            
            [obj.data, obj.xpts] = ao.online.roiSignals(...
                obj.newVideo(:, :, :), obj.roiReg,... 
                obj.FRAME_RATE, obj.BKGD_WINDOW, false);
            h = findall(obj.figureHandle, 'Tag', 'ZeroLine');
            for i = 1:numel(h)
                h(i).XData = [floor(obj.xpts(1)), ceil(obj.xpts(end))];
            end
            obj.data(isnan(obj.data)) = 0;
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
            fileName = sprintf('%s_%s_ref_%s.txt', ...
                source, expIDs{2}, obj.videoName(end-3:end));
            filePath = [obj.experimentDir, filesep, 'Ref', filesep, fileName];

            stimulusFileName = readProperty(filePath, 'Trial file name = ');
            txt = strsplit(stimulusFileName, filesep);
            stimName = txt{end};
            stimName = erase(stimName, '.txt');
            stimName = string(stimName);
        end
    end

    methods (Access = private)
        function createUi(obj)
            obj.figureHandle = figure(...
                'Name', 'Online Analysis',...
                'NumberTitle', 'off',...
                'DefaultUicontrolBackgroundColor', 'w',...
                'DefaultUicontrolFontSize', 10,...
                'Menubar', 'none',...
                'Toolbar', 'none',...
                'Color', 'w',...
                'KeyPressFcn', @obj.onKeyPress);
            obj.figureHandle.Position(3:4) = 2 * obj.figureHandle.Position(3:4);
            
            mainLayout = uix.HBox('Parent', obj.figureHandle,...
                'BackgroundColor', 'w');
            
            % Left top panel with images
            imLayout = uix.VBox('Parent', mainLayout,...
                'BackgroundColor', 'w',...
                'Tag', 'imLayout');
            baseAxis = axes(uipanel(imLayout, 'BackgroundColor', 'w'));
            ao.online.roiOverlay(obj.imBase, obj.roiBase,...
                'Parent', baseAxis);
            axis(baseAxis, 'tight');
            axis(baseAxis, 'equal');
            axis(baseAxis, 'off');
            title(baseAxis, 'Reference Image');

            obj.imHandle = axes(uipanel(imLayout, 'BackgroundColor', 'w'));
            
            uix.Empty('Parent', imLayout,...
                'BackgroundColor', 'w');
            
            % Left bottom panel with controls
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
            
            % Right panel with ROI plots
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
            
            set(mainLayout, 'Widths', [-1 -1]);
        end
        
        function userPrefChange(obj)
            prefs = containers.Map();
            prefs('bkgdWindow1') = obj.BKGD_WINDOW(1);
            prefs('bkgdWindow2') = obj.BKGD_WINDOW(2);
            d = UserPrefView2(prefs);
        end
        
        function onDialog_ChangedPref(obj, src, evt)
            disp('Hey')
            assignin('base', 'src', src);
            assignin('base', 'evt', evt);
        end
    end
    
    methods (Static)      
        function ID = name2id(vidName)
            % NAME2ID
            ID = str2double(vidName(end-2:end));
        end

        function vidName = id2name(ID)
            % ID2NAME
            vidName = ['vis_', int2fixedwidthstr(ID, 4)];
        end
    end
end 