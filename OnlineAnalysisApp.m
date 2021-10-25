classdef OnlineAnalysisApp < handle

    properties
        parentDir
        imBase
        roiBase
        numROIs
        
        imReg
        roiReg
        
        newImage
        newVideo
        videoName
        tform
        xpts
        data
    end

    properties (Hidden, SetAccess = private)
        figureHandle
        imHandle
        axHandle
        currentRoiIdx
        
        smoothData
    end
    
    properties (Hidden, Constant)
        ROI_INCREMENT = 10;
        FRAME_RATE = 25;
        BKGD_WINDOW = [1 240];
        TEMP_DIR = 'C:\Users\sarap\Desktop\OnlineReg\';
    end
    
    properties 
        dataCache 
    end

    methods 
        function obj = OnlineAnalysisApp()
            obj.parentDir = uigetdir(cd, 'Pick Experiment folder');
            addpath(genpath(obj.parentDir));
            cd(obj.parentDir);
            
            % Make sure connection with ImageJ exists...
            fprintf('Opening ImageJ...\n');
            evalin('base', 'run(''ConnectToImageJ.m'')');
            % Send relevant variables to the base workspace
            assignin('base', 'parentDir', obj.parentDir);

            obj.imBase = imread([obj.parentDir, '\REF_image.png']);
            obj.roiBase = dlmread([obj.parentDir, '\REF_rois.txt']);
            obj.numROIs = max(unique(obj.roiBase));
            
            obj.currentRoiIdx = 1;
            obj.smoothData = false;
            obj.dataCache = containers.Map();
            
            obj.createUi();
        end
    end
    
    methods (Access = private)
        function onKeyPress(obj, ~, evt)
            switch evt.Key
                case 'leftarrow'
                    newRoi = obj.currentRoiIdx - obj.ROI_INCREMENT;
                case 'rightarrow'
                    newRoi = obj.currentRoiIdx + obj.ROI_INCREMENT;
                case 's'
                    if ~obj.smoothData
                        obj.smoothData = true;
                    else
                        obj.smoothData = false;
                    end
                    if ~isempty(obj.data)
                        obj.showROIs();
                    end
                    return
            end
            if newRoi < obj.numROIs && newRoi > 0
                obj.currentRoiIdx = newRoi;
                obj.showROIs();
            end
        end
        
        function onPush_loadNewData(obj, ~, ~)
            [newName, fPath, ind] = uigetfile('*.avi',... 
                'Load registered video data');
            if ind == 0
                return;
            end
            
            x = strfind(newName, 'vis_');
            obj.videoName = newName(x:x+7);
            
            if isKey(obj.dataCache, obj.videoName)
                obj.data = obj.dataCache(obj.videoName);
                return
            end
            % Send relevant variables to base workspace for ImageJ
            assignin('base', 'newName', newName);
            assignin('base', 'filePath', fPath);
            
            % Import video and image
            % obj.newVideo = video2stack([fPath, filesep, newName]);
            evalin('base', 'run(''ConvertAVI2TIF.m'')');
            obj.newVideo = evalin('base', 'ts');
            try
                obj.newImage = imread(strrep([fPath, filesep, newName], '.avi', '.tif'));
            catch
                obj.newImage = imread(strrep([fPath, filesep, newName], '.avi', '.png'));
            end
            
            obj.registerData();
                        
            obj.dataCache(obj.videoName) = obj.data;
            h = findByTag(obj.figureHandle, 'DataList');
            h.String = obj.dataCache.keys;
            h.Value = numel(h.String);
             
            obj.showROIs();
            title(findByTag(obj.figureHandle, 'ax_1'), obj.videoName,...
                'Interpreter', 'none');
        end
        
        function onSelect_Dataset(obj, src, ~)
            obj.videoName = src.String(src.Value);
            obj.videoName = obj.videoName{:};
            obj.data = obj.dataCache(obj.videoName);
            title(findByTag(obj.figureHandle, 'ax_1'), obj.videoName);
            obj.showROIs();
        end        
    end
    
    methods 
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
            
            [obj.data, obj.xpts] = roiSignals(obj.newVideo(:, :, :), obj.roiReg,... 
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
            roiOverlay(obj.imBase, obj.roiBase,...
                'Parent', baseAxis);
            axis(baseAxis, 'tight');
            axis(baseAxis, 'equal');
            axis(baseAxis, 'off');
            title(baseAxis, 'Reference Image');

            obj.imHandle = axes(uipanel(imLayout, 'BackgroundColor', 'w'));
            uicontrol(imLayout, 'Style', 'push',...
                'String', 'Load New Data',...
                'Callback', @obj.onPush_loadNewData);
            uix.Empty('Parent', imLayout,...
                'BackgroundColor', 'w');
            uicontrol(imLayout, 'Style', 'text', 'String', 'Existing Data:');
            uicontrol(imLayout, 'Style', 'listbox',...
                'Tag', 'DataList',...
                'Callback', @obj.onSelect_Dataset);
            set(imLayout, 'Heights', [-1 -1 25 10 20 75]);
            
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