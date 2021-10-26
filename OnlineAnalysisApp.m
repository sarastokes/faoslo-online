classdef OnlineAnalysisApp < handle

    % Properties that can be accessed by the base workspace
    properties (SetAccess = private)
        experimentDir
        newImage
        videoName
    end

    % Properties with set functions
    properties (Access = private)
        newVideo
        tform
    end

    properties %(Access = private)
        imBase
        roiBase
        numROIs
        
        imReg
        roiReg
        
        xpts
        data
    end

    % User interface properties
    properties (Hidden, SetAccess = private)
        figureHandle
        imHandle
        currentRoiIdx
        
        smoothData
    end
    
    properties (Hidden, Constant)
        ROI_INCREMENT = 10;
        FRAME_RATE = 25;
        BKGD_WINDOW = [1 240];
    end
    
    properties (Hidden, Access = private)
        dataCache 
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
            obj.numROIs = max(unique(obj.roiBase));
            
            obj.currentRoiIdx = 1;
            obj.smoothData = false;
            obj.dataCache = containers.Map();
            
            obj.createUi();
        end
        
        function setTransform(obj, tform)
            assert(isa(tform, 'affine2d'), 'Transform must be type affine2d');
            obj.tform = tform;
        end

        function setNewVideo(obj, newVideo)
            obj.newVideo = newVideo;
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
                        
            obj.dataCache(obj.videoName) = obj.data;
            h = findByTag(obj.figureHandle, 'DataList');
            h.String = obj.dataCache.keys;
            h.Value = numel(h.String);
             
            obj.showROIs();
            title(findByTag(obj.figureHandle, 'ax_1'), obj.videoName,...
                'Interpreter', 'none', 'FontSize', 8);
        end
        
        function onSelect_Dataset(obj, src, ~)
            obj.videoName = src.String(src.Value);
            obj.videoName = obj.videoName{:};
            obj.data = obj.dataCache(obj.videoName);
            title(findByTag(obj.figureHandle, 'ax_1'), obj.videoName);
            obj.showROIs();
        end   
        
        
        function onCheck_HoldData(obj, src, ~)
            if src.Value
                for i = 1:obj.ROI_INCREMENT
                    ax = obj.getNumberedAxis(i);
                    hNew = copyobj(findByTag(ax, 'SignalLine'), ax);
                    hNew.Tag = 'HeldLine';
                    hNew.Color = [0.5 0 0];
                end
            else
                h = findall(obj.figureHandle, 'Tag', 'HeldLine');
                delete(h);
            end
        end
    end
    
    methods 
        function ax = getNumberedAxis(obj, ind)
            ax = findByTag(obj.figureHandle, ['ax_', num2str(ind)]);
        end
        
        function showROIs(obj)
            for i = 1:obj.ROI_INCREMENT
                idx = obj.currentRoiIdx + i - 1;
                if idx > size(obj.data, 1)
                    continue
                end
                ax = findobj(obj.figureHandle, 'Tag', sprintf('ax_%u', i));
                h = findobj(ax, 'Tag', 'SignalLine');
                h.XData = obj.xpts;
                
                if obj.smoothData 
                    h.YData = mysmooth(obj.data(idx, :), 100);
                else
                    h.YData = obj.data(idx, :);
                end
                xlim(ax, [floor(obj.xpts(1)), ceil(obj.xpts(end))]);
                maxVal = max(abs(h.YData));
                if max(abs(h.YData)) ~= 0
                    ylim(ax, maxVal * [-1 1]);
                    set(ax, 'YTick', -maxVal:0.25:maxVal, 'YTickLabel', {});
                end
                ylabel(ax, sprintf('ROI %u', idx));
                grid(ax, 'on');
            end
        end
        
        function registerData(obj)
            % Run registration in base workspace for ImageJ, get results
            evalin('base', 'run(''DoSIFTRegistration.m'')');
            obj.tform = evalin('base', 'tform');
            
            newRefObj = imref2d(size(obj.newImage));
            baseRefObj = imref2d(size(obj.imBase));
            obj.roiReg = imwarp(obj.roiBase, baseRefObj, obj.tform,...
                'OutputView', newRefObj,...
                'interp', 'nearest');
            % Plot the new image with registered ROIs
            cla(obj.imHandle);
            roiOverlay(obj.newImage, obj.roiReg,...
                'Parent', obj.imHandle);
            title(obj.imHandle, 'New Data',...
                'Interpreter', 'none');
            
            [obj.data, obj.xpts] = ao.online.roiSignals(obj.newVideo(:, :, :), obj.roiReg,... 
                obj.FRAME_RATE, obj.BKGD_WINDOW, false);
            h = findall(obj.figureHandle, 'Tag', 'ZeroLine');
            for i = 1:numel(h)
                h(i).XData = [floor(obj.xpts(1)), ceil(obj.xpts(end))];
            end
            obj.data(isnan(obj.data)) = 0;
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
            imLayout = uix.VBox('Parent', mainLayout,...
                'BackgroundColor', 'w',...
                'Tag', 'imLayout');

            baseAxis = axes('Parent', uipanel(imLayout, 'BackgroundColor', 'w'));
            ao.online.roiOverlay(obj.imBase, obj.roiBase,...
                'Parent', baseAxis);
            axis(baseAxis, 'tight');
            axis(baseAxis, 'equal');
            axis(baseAxis, 'off');
            title(baseAxis, 'Reference Image');

            obj.imHandle = axes(uipanel(imLayout, 'BackgroundColor', 'w'));
            
            uix.Empty('Parent', imLayout,...
                'BackgroundColor', 'w');
            
            dataLayout = uix.HBox('Parent', imLayout,...
                'BackgroundColor', 'w');
            dataLayoutA = uix.VBox('Parent', dataLayout,...
                'BackgroundColor', 'w');
            uicontrol(dataLayoutA, 'Style', 'text', 'String', 'Existing Data:');
            uicontrol(dataLayoutA, 'Style', 'listbox',...
                'Tag', 'DataList',...
                'Callback', @obj.onSelect_Dataset);
            set(dataLayoutA, 'Heights', [17 -1]);
            dataLayoutB = uix.VBox('Parent', dataLayout,...
                'BackgroundColor', 'w');
            uicontrol(dataLayoutB, 'Style', 'push',...
                'String', 'Load New Data',...
                'Callback', @obj.onPush_loadNewData);
            uicontrol(dataLayoutB,... 
                'Style', 'check',...
                'String', 'Hold Data',...
                'Tag', 'Check_HoldData',...
                'Callback', @obj.onCheck_HoldData);
            set(imLayout, 'Heights', [-1 -1 10 70]);
            
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
                    'LineWidth', 0.75, 'Color', [0.45 0.45 0.45],...
                    'Tag', 'ZeroLine');
                plot(ax, [0 1], [0 0],... 
                    'LineWidth', 1.5, 'Color', [0 0 0.3],...
                    'Tag', 'SignalLine');
            end
            
            set(mainLayout, 'Widths', [-1 -1]);
        end
    end
end 