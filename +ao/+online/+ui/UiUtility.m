classdef UiUtility < handle
% LAYOUTMANAGER
%
% Description:
%	Set of methods for common compound user interface components
%
% Syntax:
%	obj = LayoutManager();
%
% History:
%	23Jul2018 - SSP
%	30Sep2019 - SSP - Added bold label methods
%   06Oct2021 - SSP - Moved over from sbfsem-tools
% ------------------------------------------------------------------------
	
	% Helper functions
	methods (Static)
		function tf = isValidNumber(value)
			tf = ~isnan(str2double(value));
		end
	end

	% Callbacks
	methods (Static)
		function onChanged_Number(src, ~)
			tf = ao.online.ui.UiUtility.isValidNumber(src.String);
			if tf 
				set(src, 'ForegroundColor', 'k');
			else
				set(src, 'ForegroundColor', 'r');
			end
		end
	end

	% UI creation utilities
	methods (Static)
		function [h, p] = verticalBoxWithLabel(parentHandle, str, varargin)
			% VERTICALBOXWITHLABEL
			%
			% Inputs:
			%	parentHandle 		Where the ui component is initialized
			%	str 				Text for the label
			%	varargin 			Inputs to uicontrol for 2nd component
			% ------------------------------------------------------------

			p = uix.VBox('Parent', parentHandle,...
				'BackgroundColor', 'w');
			h = uicontrol(p, 'Style', 'text', 'String', str);
			uicontrol(p, varargin{:});
			set(p, 'Heights', [-0.75, -1]);
        end
        
		function [h, p] = horizontalBoxWithLabel(parentHandle, str, varargin)
			% HORIZONTALBOXWITHLABEL
            p = uix.HBox('Parent', parentHandle,...
                'BackgroundColor', 'w');
            h = uicontrol(p, 'Style', 'text', 'String', str);
            uicontrol(p, varargin{:});
            set(p, 'Widths', [-1, -1]);
		end
		
		function [h, p] = verticalBoxWithBoldLabel(parentHandle, str, varargin)
			% VERTICALBOXWITHBOLDLABEL
			%
			% Inputs:
			%	parentHandle 		Where the ui component is initialized
			%	str 				Text for the label
			%	varargin 			Inputs to uicontrol for 2nd component
			% ------------------------------------------------------------

			p = uix.VBox('Parent', parentHandle,...
				'BackgroundColor', 'w');
			h = uicontrol(p, 'Style', 'text', 'String', str, 'FontWeight', 'bold');
			uicontrol(p, varargin{:});
			set(p, 'Heights', [-0.75, -1]);
        end

		function [h, p] = horizontalBoxWithBoldLabel(parentHandle, str, varargin)
			% HORIZONTALBOXWITHBOLDLABEL
            p = uix.HBox('Parent', parentHandle,...
                'BackgroundColor', 'w');
            h = uicontrol(p, 'Style', 'text', 'String', str, 'FontWeight', 'bold');
            uicontrol(p, varargin{:});
            set(p, 'Widths', [-1, -1]);
        end
        
        function [h1, h2, p] = verticalBoxWithTwoCells(parentHandle, str, tag1, tag2, varargin)
            p = uix.VBox('Parent', parentHandle,...
                'BackgroundColor', 'w');
            uicontrol(p, 'Style', 'text', 'String', str, 'FontWeight', 'bold');
            p2 = uix.HBox('Parent', p, 'BackgroundColor', 'w');
            h1 = uicontrol(p2, 'Style', 'edit', 'Tag', tag1, varargin{:});
            h2 = uicontrol(p2, 'Style', 'edit', 'Tag', tag2, varargin{:});
        end
        
        function [h1, h2, p] = horizontalBoxWithTwoCells(parentHandle, str, tag1, tag2, varargin)
            p = uix.VBox('Parent', parentHandle,...
                'BackgroundColor', 'w');
            uicontrol(p, 'Style', 'text', 'String', str);
            p2 = uix.HBox('Parent', p, 'BackgroundColor', 'w');
            h1 = uicontrol(p2, 'Style', 'edit', 'Tag', tag1, varargin{:});
            h2 = uicontrol(p2, 'Style', 'edit', 'Tag', tag2, varargin{:});
            set(p, 'Heights', [20, -1]);
        end
	end
end
