function ctdSeaProcessing (varargin)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% COPYRIGHT & LICENSE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%  Copyright 2017 - IRD US191, all rights reserved.                        %
%                                                                          %
%  This file is part of ctdSeaProcessing.                                  %  
%                                                                          %
%  ctdSeaProcessing is free software; you can redistribute it and/or modify%
%                                                                          %
%    it under the terms of the GNU General Public License as published by  %
%    the Free Software Foundation; either version 2 of the License, or     %
%    (at your option) any later version.                                   %
%                                                                          %
%    ctdSeaProcessing is distributed in the hope that it will be useful,   %
%    but WITHOUT ANY WARRANTY; without even the implied warranty of        %
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         %
%    GNU General Public License for more details.                          %
%                                                                          %
%    To  receive a copy of the GNU General Public License                  %
%    write to the Free Software Foundation,                                %
%    Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Preprocessing software for CTD-LADCP                                     %
% Autor slave: Pierre Rousselot / Date: 10/03/16                           %
% Jedi master: Jacques Grelet                                              %
% -> Copy data acquisition CTD file to processing path                     %
% -> CTD SBE processing                                                    %
% -> Copy data acquisition LADCP file to processing path                   %
% -> LADCP Processing (a cleanud-up version of the velocity inversion      % 
%    method maintained primarily by Gerd Krahman at IFM-Geomar/LDEO)       %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
close all; clc;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Mode
[debug_mode]    = tools(varargin, nargin);
stepbystep_mode = false;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Handle
fig = figure('Name', 'CTD-LADCP PreProcessing', ...
    'units', 'normalized', ...
    'menubar', 'no', ...
    'tag', 'F_PRECALIBRATION', ...
    'position', [0.1 0.1 .35 .7]);

infogen_menu = uimenu(fig, 'Label', 'General information');

menu_mode           = uimenu(infogen_menu, 'Label', 'Mode');
Debug_Mode          = uimenu(menu_mode, 'Label', 'Debug', ...
    'callback', @DebugMode);
Normal_Mode         = uimenu(menu_mode, 'Label', 'Normal', ...
    'callback', @NormalMode, 'Checked', 'on');
Step_by_Step_Mode   = uimenu(menu_mode, 'Label', 'StepbyStep', ...
    'callback', @StepbyStepMode);
uimenu(infogen_menu, 'Label', 'Help', ...
    'callback', @help);
uimenu(infogen_menu, 'Label', 'Quit', ...
    'callback', 'close all', ...
    'Separator', 'on', ...
    'Accelerator', 'Q');

panel_infogen = uipanel(fig, 'title', 'General information', ...
    'position', [0. 0 1 1], ...
    'tag', 'INFOGEN', ...
    'visible', 'on');

if debug_mode
    set(fig, 'Name', 'CTD-LADCP PreProcessing --DEBUG MODE--');
    set(Debug_Mode, 'Checked', 'on')
    set(Normal_Mode, 'Checked', 'off')
    set(Step_by_Step_Mode, 'Checked', 'off')
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Get configuration
if ~ exist(strcat(prefdir, filesep, mfilename,'.mat'), 'file')
    select_configfile('config_filename');
else
    ConfigFile = load(strcat(prefdir, filesep, mfilename,'.mat'), 'cfg');
    cfg = ConfigFile.cfg;
end
%% Initialization
cfg.rep_local = fileparts(which(mfilename));
cfg.debug_mode = false;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Mission and station parameters
% Mission name
uicontrol(panel_infogen, 'style', 'Text', ...
    'String', 'Mission Name', ...
    'units', 'normalized', ...
    'position', [- 0.05 0.96 0.45 0.02]);

name_mission = uicontrol(panel_infogen, 'style', 'edit', ...
    'units', 'normalized', ...
    'position', [0.1 0.93 0.4 0.03], ...
    'tag', 'NOMMISSION_ENTER', ...
    'string', cfg.name_mission, ...
    'callback', {@get_mission_para, 'name_mission'});

% Mission ID
uicontrol(panel_infogen, 'style', 'Text', ...
    'String', 'Mission ID', ...
    'units', 'normalized', ...
    'position', [0.4 0.96 0.34 0.02]);

id_mission = uicontrol(panel_infogen, 'style', 'edit', ...
    'units', 'normalized', ...
    'position', [0.53 0.93 0.1 0.03], ...
    'tag', 'IDMISSION_ENTER', ...
    'string', cfg.id_mission, ...
    'callback', {@get_mission_para, 'id_mission'});

% Station number
uicontrol(panel_infogen, 'style', 'Text', ...
    'String', 'Station Number (''XXX'')', ...
    'units', 'normalized', ...
    'position', [0.625 0.96 0.45 0.02]);

num_station = uicontrol(panel_infogen, 'style', 'edit', ...
    'units', 'normalized', ...
    'position', [0.8 0.91 0.1 0.05], ...
    'BackgroundColor', 'white', ...
    'tag', 'NUMSTATION_ENTER', ...
    'TooltipString', '''XXX''', ...
    'string', cfg.num_station, ...
    'callback', {@get_mission_para, 'num_station'});

% Selection du fichier de configuration .ini
uicontrol(panel_infogen, 'style', 'Text', ...
    'String', 'Configuration Filename .ini', ...
    'units', 'normalized', ...
    'position', [0.03 0.88 0.45 0.02]);

config_file = uicontrol(panel_infogen, 'style', 'edit', ...
    'units', 'normalized', ...
    'position', [0.1 0.85 0.6 0.03], ...
    'tag', 'FILENAMECTD_ENTER', ...
    'string', cfg.config_filename, ...
    'TooltipString', 'Parameters and paths', ...
    'callback', {@get_mission_para, 'config_filename'});

uicontrol(panel_infogen, 'string', 'Select', ...
    'units', 'normalized', ...
    'position', [0.71 0.85 0.1 0.03], ...
    'tag', 'FILENAMECTD_CHOOSE', ...
    'userdata', config_file, ...
    'callback', {@choose_file, 'config_filename'});

%% Panel CTD
panel_CTD = uipanel('parent', panel_infogen, ...
    'title', 'CTD', ...
    'units', 'normalized', ...
    'position', [0.05 0.60 0.9 0.20]);

% Option to copy CTD file
msg = sprintf('Copy CTD files from:\n %s \n to :\n %s \n %s',...
    cfg.path_output_CTD, cfg.path_raw_CTD, cfg.path_processing_CTD);

copy_ctd = uicontrol(panel_CTD, 'style', 'checkbox', ...
    'units', 'normalized', ...
    'string', 'Copy CTD file to processing path', ...
    'TooltipString', msg, ...
    'position', [0.1 0.7 0.45 0.13], ...
    'tag', ' OPTION_COPY_CTD', ...
    'Value', cfg.copy_CTD, ...
    'callback', {@checkbox_value, 'copy_CTD'});

% Option to copy SBE35 file
msg = sprintf('Copy SBE35 file from:\n %s \n to :\n %s \n %s',...
    cfg.path_output_SBE35, cfg.path_raw_SBE35, cfg.path_processing_SBE35);
  
copy_sbe35  = uicontrol(panel_CTD, 'style', 'checkbox', ...
    'units', 'normalized', ...
    'string', 'Copy SBE35 file to processing path', ...
    'TooltipString', msg, ...
    'position', [0.2 0.5 0.45 0.13], ...
    'tag', ' OPTION_COPY_CTD', ...
    'Value', cfg.copy_SBE35, ...
    'callback', {@checkbox_value, 'copy_SBE35'});
  
% Option PMEL
process_pmel = uicontrol(panel_CTD, 'style', 'checkbox', ...
    'units', 'normalized', ...
    'string', 'PMEL Processing', ...
    'position', [0.8 0.7 0.20 0.13], ...
    'TooltipString', 'Specific processing for PMEL', ...
    'tag', 'OPTION_PMEL', ...
    'Value', 0, ...
    'callback', {@checkbox_value, 'process_PMEL'});

% Option BTL
process_btl = uicontrol(panel_CTD, 'style', 'checkbox', ...
    'units', 'normalized', ...
    'string', 'BTL Processing', ...
    'position', [0.8 0.2 0.20 0.13], ...
    'TooltipString', 'Bottle Processing', ...
    'tag', 'OPTION_BTL', ...
    'Value', cfg.process_BTL, ...
    'callback', {@checkbox_value, 'process_BTL'});
  
% Option to process CTD file
msg = sprintf('%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s', ...
    'Step :', 'sbe_ladcp', 'sbe_codac', 'sbe_std', 'sbe_plt', ...
    'sbe_report', 'sbe_btl', 'compress_codac');

process_ctd = uicontrol(panel_CTD, 'style', 'checkbox', ...
    'units', 'normalized', ...
    'string', 'SeaBird CTD data Processing', ...
    'TooltipString', msg, ...
    'position', [0.1 0.2 0.45 0.13], ...
    'tag', 'OPTION_PROCESS_CTD', ...
    'Value', cfg.process_CTD, ...
    'callback', {@checkbox_value, 'process_CTD'});

%% Panel LADCP
panel_LADCP = uipanel('parent', panel_infogen, ...
    'title', 'LADCP', ...
    'units', 'normalized', ...
    'position', [0.05 0.30 0.9 0.30]);

% Select LADCP Master file
uicontrol(panel_LADCP, 'style', 'Text', ...
    'String', 'LADCP Master filename', ...
    'units', 'normalized', ...
    'position', [0.03 0.8 0.45 0.08]);

ladcpm_infogen = uicontrol(panel_LADCP, 'style', 'edit', ...
    'units', 'normalized', ...
    'BackgroundColor', 'white', ...
    'position', [0.1 0.7 0.6 0.09], ...
    'TooltipString', 'Original output LADCP Master filename', ...
    'tag', 'FILELADCPM_ENTER', ...
    'string', strcat(cfg.path_output_LADCP,cfg.filename_LADCPM), ...
    'callback', {@get_mission_para, 'filename_LADCPM'});

uicontrol(panel_LADCP, 'string', 'Select', ...
    'units', 'normalized', ...
    'position', [0.71 0.7 0.1 0.09], ...
    'tag', 'FILELADCPM_CHOOSE', ...
    'userdata', ladcpm_infogen, ...
    'callback', {@choose_file, 'filename_LADCPM'});

% Select LADCP Slave file
uicontrol(panel_LADCP, 'style', 'Text', ...
    'String', 'LADCP slave filename', ...
    'units', 'normalized', ...
    'position', [0.03 0.6 0.45 0.08]);

ladcps_infogen = uicontrol(panel_LADCP, 'style', 'edit', ...
    'units', 'normalized', ...
    'BackgroundColor', 'white', ...
    'position', [0.1 0.5 0.6 0.09], ...
    'TooltipString', 'Original output LADCP Slave filename', ...
    'tag', 'FILELADCPS_ENTER', ...
    'string', strcat(cfg.path_output_LADCP,cfg.filename_LADCPS), ...
    'callback', {@get_mission_para, 'filename_LADCPS'});

uicontrol(panel_LADCP, 'string', 'Select', ...
    'units', 'normalized', ...
    'position', [0.71 0.5 0.1 0.09], ...
    'tag', 'FILELADCPS_CHOOSE', ...
    'userdata', ladcps_infogen, ...
    'callback', {@choose_file, 'filename_LADCPS'});

% Option to copy LADCP file
msg = sprintf('Copy LADCP files to :\n %s%s \n %s%s \n and \n %s%s \n %s%s \n %s%s \n %s%s', ...
    cfg.path_save_LADCP, cfg.newfilename_LADCPM,...
    cfg.path_save_LADCP, cfg.newfilename_LADCPS,...
    cfg.path_raw_LADCP, cfg.newfilename_LADCPM,...
    cfg.path_raw_LADCP, cfg.newfilename_LADCPS,...
    cfg.path_processing_LADCP, cfg.newfilename_LADCPM,...
    cfg.path_processing_LADCP, cfg.newfilename_LADCPS);

copy_ladcp = uicontrol(panel_LADCP, 'style', 'checkbox', ...
    'units', 'normalized', ...
    'string', 'Copy LADCP file to processing path', ...
    'TooltipString', msg, ...
    'position', [0.1 0.3 0.45 0.08], ...
    'tag', 'OPTION_COPY_LADCP', ...
    'Value', cfg.copy_LADCP, ...
    'callback', {@checkbox_value, 'copy_LADCP'});

% Option to process LADCP file
process_ladcp = uicontrol(panel_LADCP, 'style', 'checkbox', ...
    'units', 'normalized', ...
    'string', 'LADCP processing', ...
    'TooltipString', 'LDEO Processing', ...
    'position', [0.1 0.1 0.45 0.08], ...
    'tag', 'OPTION_PROCESS_LADCP', ...
    'Value', cfg.process_LADCP, ...
    'callback', {@checkbox_value, 'process_LADCP'});

%% Valid and Cancel Button
uicontrol(panel_infogen, 'style', 'pushbutton', ...
    'string', 'Valid', ...
    'units', 'normalized', ...
    'position', [0.1 0.05 0.4 0.1], ...
    'callback', @launcher);

uicontrol(panel_infogen, 'style', 'pushbutton', ...
    'string', 'Cancel', ...
    'units', 'normalized', ...
    'position', [0.5 0.05 0.4 0.1], ...
    'callback', 'close all');

%----------------------------------------------------------------------------------------------------------------------------------
% Help
    function help(~, ~)
        fid_helpfile = fopen('help.txt');
        file = textscan(fid_helpfile, '%s', 'Delimiter', '\n');
        helpdlg(file{1, 1}, 'Help')
    end

% Debug mode
    function DebugMode(~, ~)
        debug_mode      = true;
        stepbystep_mode = false;
        set(fig, 'Name', 'CTD-LADCP PreProcessing --DEBUG MODE--');
        set(Debug_Mode, 'Checked', 'on');
        set(Normal_Mode, 'Checked', 'off');
        set(Step_by_Step_Mode, 'Checked', 'off');
    end

% Normal mode
    function NormalMode(~, ~)
        debug_mode      = false;
        stepbystep_mode = false;
        set(fig, 'Name', 'CTD-LADCP PreProcessing');
        set(Normal_Mode, 'Checked', 'on');
        set(Debug_Mode, 'Checked', 'off');
        set(Step_by_Step_Mode, 'Checked', 'off');
    end

% Step-by-Step mode
    function StepbyStepMode(~, ~)
        debug_mode      = false;
        stepbystep_mode = true;
        set(fig, 'Name', 'CTD-LADCP PreProcessing --STEP-BY-STEP MODE--');
        set(Step_by_Step_Mode, 'Checked', 'on');
        set(Normal_Mode, 'Checked', 'off');
        set(Debug_Mode, 'Checked', 'off');
    end

% Select configuration file
    function select_configfile(hObj, ~)
            [filename, path, ~] = uigetfile('*.ini', 'Select configuration file');
            config_filename = fullfile(path, filename);
            cfg = configuration(config_filename);
            cfg.config_filename = config_filename;
            cfg.path_config = path;
            save(strcat(prefdir, filesep, mfilename, '.mat'), 'cfg');          
    end

% Select files & set parameters
    function choose_file(hObj, ~, member)
        if strcmp(member, 'config_filename')
            select_configfile
        else
            cfg.(member) = uigetfile('*.000', 'Select file', strcat(cfg.path_output_LADCP, cfg.(member)));
        end
        
        if ~ cfg.(member)
            msgbox('The file has not been selected !', 'Warn', 'error');
        else
            set_mission_para
        end
    end

% Get mission parameter
    function get_mission_para(hObj, ~, member)
        cfg.(member) = get(hObj, 'string');
        if strcmp(member, 'num_station')
            cfg.filename_CTD = sprintf('%s', cfg.id_mission, cfg.num_station);
            cfg.newfilename_LADCPM = sprintf('%s', cfg.id_mission, 'M', cfg.num_station, '.000');
            cfg.newfilename_LADCPS = sprintf('%s', cfg.id_mission, 'S', cfg.num_station, '.000');
        end
    end

% Set mission parameter
    function set_mission_para
        set(config_file, 'string', cfg.config_filename);
        set(num_station, 'string', cfg.num_station);
        set(name_mission, 'string', cfg.name_mission);
        set(id_mission, 'string', cfg.id_mission);
        set(ladcpm_infogen, 'string', strcat(cfg.path_output_LADCP, cfg.filename_LADCPM));
        set(ladcps_infogen, 'string', strcat(cfg.path_output_LADCP, cfg.filename_LADCPS));
        set(copy_ctd, 'value', cfg.copy_CTD)
        set(copy_sbe35, 'value', cfg.copy_SBE35)
        set(process_pmel, 'value', cfg.process_PMEL)
        set(process_ctd, 'value', cfg.process_CTD)        
        set(copy_ladcp, 'value', cfg.copy_LADCP)
        set(process_ladcp, 'value', cfg.process_LADCP)
    end

% Return checkbox value
    function checkbox_value(hObj, ~, member)
        if ~ get(hObj, 'value')
            cfg.(member) = false;
        elseif get(hObj, 'value')
            cfg.(member) = true;
        end
    end

% Launch processing
    function launcher(~, ~)
        % Save workspace
        save(strcat(prefdir, filesep, mfilename, '.mat'), 'cfg');
        cfg.debug_mode      = debug_mode;
        cfg.stepbystep_mode = stepbystep_mode;
        launch_processing(cfg)
    end

end