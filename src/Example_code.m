%% Example code
% "SSRC_SleepStatistics Copyright (C) 2024  Kiran K G Ravindran and contributers.
% This program is free software: you can redistribute it and/or modify it
% under the terms of the GNU General Public License as published by the
% Free Software Foundation, either version 3 of the License,
% or (at your option) any later version. This program is distributed
% WITHOUT ANY WARRANTY.  See the GNU General Public License for more details
% (https://www.gnu.org/licenses/)
%% 
clear; close all; clc;
warning('off','all')
% Folder containing the example data
data_path = pwd;
data_path = fullfile(data_path, '..\exampledata');
% Get the Hypnogram and Marker files
files = string(extractfield(dir(strcat(data_path,'\*.txt')),'name')');
% To generate the SSRC sleep statistics we need a Marker file containing
% the Start, Lights off, Lights on and End event markers &
% a corresponding file containing the hypnogram.
% The format of the Marker and hypnogram files need to the match the files in the
% exampledata folder
Marker_files=files(contains(files,"Marker"));
Hypnogram_files=files(contains(files,"Hypnogram"));
Sleep_Statistics=[];
for iloop=1:length(Marker_files)
    % Get Marker info
    Marker_info=Get_Markers(fullfile(data_path,Marker_files(iloop)));
    % Get Hypnogram
    [Time_sleep,Hypnogram]=Get_Hypnogram(Marker_info,fullfile(data_path,Hypnogram_files(iloop)));
    % Get the statistics
    Out_Sleep_Statistics_Full=Get_SSRC_SleepStatistics(Time_sleep,Hypnogram,Marker_info);
    % Pool the data in a table for all files
    Sleep_Statistics=[Sleep_Statistics;Get_SM_row(Out_Sleep_Statistics_Full)];
end
% Add Marker and Hypnogram file names
Sleep_Statistics.Marker_files=Marker_files;
Sleep_Statistics.Hypnogram_files=Hypnogram_files;
% Export the sleep statistics table as a spreadsheet
writetable(Sleep_Statistics,"Example_SSRC_sleep_statistics.xlsx",'Sheet',"Statistics");
% End of example code
%% Support Functions
%% Get Marker info
function T=Get_Markers(fname)
fid = fopen(fname);
Marker= textscan(fid, '%s %s', 'Delimiter', ';');
%% Marker - Light on and Light off
Marker_Time=Marker{1};
Marker_Time = strrep(Marker_Time,'.','/');
if isempty(contains(Marker{2},'Lights Off'))|| isempty(contains(Marker{2},'Lights On'))
    disp('Error: The marker file doesnot contain lights off-on details.');
    fprintf(fileID,' %s\n','Error: The marker file doesnot contain lights off-on details.');
    return
end
if isempty(contains(Marker{2},'Start'))|| isempty(contains(Marker{2},'End'))
    disp('Error: The marker file doesnot contain Start and end recording details.');
    fprintf(fileID,' %s\n','Error: The marker file doesnot contain Start and end recording details.');
    return
end

a1=contains(Marker{2},'Lights Off','IgnoreCase',true);
b1=contains(Marker{2},'Light Off','IgnoreCase',true);
try
    if any(a1)
        LIGHTOFF=datetime((Marker_Time{contains(Marker{2},'Lights Off','IgnoreCase',true)}),'InputFormat','dd/MM/yyyy HH:mm:ss,SSS','Format','dd-MMM-yyyy HH:mm:ss,SSS');
    elseif any(b1)
        LIGHTOFF=datetime((Marker_Time{contains(Marker{2},'Light Off','IgnoreCase',true)}),'InputFormat','dd/MM/yyyy HH:mm:ss,SSS','Format','dd-MMM-yyyy HH:mm:ss,SSS');
    end
catch
    if any(a1)
        Ind_LF=(Marker_Time(contains(Marker{2},'Lights Off','IgnoreCase',true)));
    elseif any(b1)
        Ind_LF=(Marker_Time(contains(Marker{2},'Light Off','IgnoreCase',true)));
    end
    LIGHTOFF=datetime(Ind_LF{end},'InputFormat','dd/MM/yyyy HH:mm:ss,SSS','Format','dd-MMM-yyyy HH:mm:ss,SSS');
end

a=contains(Marker{2},'Light On','IgnoreCase',true);
b=contains(Marker{2},'Lights On','IgnoreCase',true);
if any(a)
    LIGHTON=datetime(Marker_Time{contains(Marker{2},'Light On','IgnoreCase',true)},'InputFormat','dd/MM/yyyy HH:mm:ss,SSS','Format','dd-MMM-yyyy HH:mm:ss,SSS');
elseif any(b)
    LIGHTON=datetime(Marker_Time{contains(Marker{2},'Lights On','IgnoreCase',true)},'InputFormat','dd/MM/yyyy HH:mm:ss,SSS','Format','dd-MMM-yyyy HH:mm:ss,SSS');
end
try
    RECSTART=datetime(Marker_Time{contains(Marker{2},'Start','IgnoreCase',true)},'InputFormat','dd/MM/yyyy HH:mm:ss,SSS','Format','dd-MMM-yyyy HH:mm:ss,SSS');
    c=find(contains(Marker{2},'End','IgnoreCase',true));
catch
    RECSTART=datetime(Marker_Time{contains(Marker{2},'Start','IgnoreCase',false)},'InputFormat','dd/MM/yyyy HH:mm:ss,SSS','Format','dd-MMM-yyyy HH:mm:ss,SSS');
    c=find(contains(Marker{2},'End','IgnoreCase',false));
end
RECEND=datetime(Marker_Time{c(end)},'InputFormat','dd/MM/yyyy HH:mm:ss,SSS','Format','dd-MMM-yyyy HH:mm:ss,SSS');
T= table(LIGHTOFF,LIGHTON,RECSTART,RECEND);
end

%% Get hypnogram labels and the time vector
function [time_vec,label]=Get_Hypnogram(Marker_info,File_name)
warning off
% Get the Marker info
RECSTART=Marker_info.RECSTART;
RECEND=Marker_info.RECEND;
% Get hypnogram file
File=readcell(File_name,'ExpectedNumVariables',4);
%% hypnogram data
% % PSG
% Artefact - 6
% Wake    - 5
% REM     - 4
% N1      - 3
% N2      - 2
% N3      - 1
% Exracting the start and end date
Start_index=find(contains(string(File(:,1)),'Rate:'));
if isempty(Start_index)
    disp('The sleep profile does not match the device type chosen');
    fprintf(fileID,' %s\n','The sleep profile does not match the device type chosen');
    return
end
Stages=File(Start_index+1:end,3); % steep stages string array
St=erase(File{Start_index+1,2},';' );
Et=erase(File{end,2},';' );

a=Stages{1,1};
if ismissing(a)
    Stages=File(Start_index+1:end,2); % steep stages string array
    St=erase(File{Start_index+1,1},';' );
    Et=erase(File{end,1},';' );
end
Cp1=strsplit(St,':');
Cp1{3}=erase(Cp1{3},',000' );
St=duration(str2double(Cp1)); %mm/dd/yy
Cp2=strsplit(Et,':');
Cp2{3}=erase(Cp2{3},',000' );
Et=duration(str2double(Cp2)); %mm/dd/yy
% Extracting the date
Date=File{Start_index+1,1};
EndDate=File{end,1};
if ismissing(a)
    strt=datetime(RECSTART,'Format','dd/MM/yyyy HH:mm:ss,SSS');
    Date=string(strt);
    Cp = strsplit(Date,'/'); %mm/dd/yy
    x=Cp{3};
    x(5:end)=[];
    Cp{3}=x;
    endd=datetime(RECEND,'Format','dd/MM/yyyy HH:mm:ss,SSS');
    Cp2= strsplit(string(endd),'/'); %mm/dd/yy;
    x2=Cp2{3};
    x2(5:end)=[];
    Cp2{3}=x2;
    Date=datetime(str2double(Cp{3}),str2double(Cp{2}),str2double(Cp{1}));
    EndDate=datetime(str2double(Cp2{3}),str2double(Cp2{2}),str2double(Cp2{1}));
end
% creating the date time
Dst=Date+St;
Det=(EndDate)+Et;
% creating a time vector
time_vec=(Dst:seconds(30):Det)';
time_vec=datetime(time_vec,'Format','dd-MMM-yyyy HH:mm:ss');
% discretized sleep stages
% Creating a common notation
valueSet= ["N3","N2","N1","REM","Wake","Artefact","A"];
keySet= [1 2 3 4 5 6 6];
M = dictionary(valueSet,keySet);
label=M(string(Stages));
end
%% Format the out put of the SSRC sleep statistics function into a table row
function SM=Get_SM_row(Out)
% Format the input structure containing the sleep measures tables to a
% single row
    temp_SM_head=cell2table(Out.header(:,2)');
    temp_SM_head.Properties.VariableNames=Out.header(:,1);   
    temp_SM_dur=rows2vars(Out.Duration_table(:,2));temp_SM_dur(:,1)=[];
    temp_SM_dur.Properties.VariableNames=Out.Duration_table{:,1};
    temp_SM_perc=rows2vars(Out.Percent_table(:,2));temp_SM_perc(:,1)=[];
    temp_SM_perc.Properties.VariableNames=Out.Percent_table{:,1};
    temp_SM_count=rows2vars(Out.Count_table(:,2));temp_SM_count(:,1)=[];
    temp_SM_count.Properties.VariableNames=Out.Count_table{:,1};
    SM=[temp_SM_head,temp_SM_dur,temp_SM_perc,temp_SM_count];
end