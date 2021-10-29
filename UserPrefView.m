classdef UserPrefView < handle
    
    events
        BackgroundWindowChanged
    end
   
    properties (SetAccess = private)
        prefs
        inputChanged
        figureHandle
    end
    
    methods
        function obj = UserPrefView(prefs)
            obj.prefs = prefs;
            obj.inputChanged = false;
            
            obj.createUi();
        end
        
        function createUi(obj)
            obj.figureHandle = figure('Name', 'User Preferences',...
                'DefaultUicontrolFontSize', 10);
            figPos(obj.figureHandle, 0.75, 0.5);
            mainLayout = uix.VBox('Parent', obj.figureHandle);
            uicontrol(mainLayout,...
                'Style', 'text',...
                'FontSize', 14,...
                'String', 'USER PREFERENCES');
            [h1, h2] = ao.online.ui.UiUtility.horizontalBoxWithTwoCells(...
                mainLayout, 'Background window (in frames)',... 
                'BkgdWindow1', 'BkgdWindow2',...
                'Callback', @obj.onChanged_Number);
            h1.String = num2str(obj.prefs('bkgdWindow1'));
            h2.String = num2str(obj.prefs('bkgdWindow2'));
            uicontrol(mainLayout,...
                'Style', 'text',...
                'String', '0 0 = no background subtraction');
        end
        
        function onChanged_Number(obj, src, ~)
            tf = obj.isValidNumber(src.String);
            if tf
                set(src, 'ForegroundColor', 'k');
                assignin('base', 'src', src);
                obj.prefs(src.Tag) = str2double(src.String);
                obj.inputChanged = true;
            else  % Change color to notify user
                set(src, 'ForegroundColor', 'r');
            end
        end
    end
    
    methods (Static)
        function tf = isValidNumber(value)
            tf = ~isnan(str2double(value));
        end
    end
end