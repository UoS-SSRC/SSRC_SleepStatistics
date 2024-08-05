function Out=Get_SSRC_SleepStatistics(time_vec,label,Marker_info,type)
% "SSRC_SleepStatistics Copyright (C) 2024  Kiran K G Ravindran and contributers.
% This program is free software: you can redistribute it and/or modify it
% under the terms of the GNU General Public License as published by the
% Free Software Foundation, either version 3 of the License,
% or (at your option) any later version. This program is distributed
% WITHOUT ANY WARRANTY.  See the GNU General Public License for more details
% (https://www.gnu.org/licenses/)
%% Get sleep metrics
% input - time, label, Marker_info and type
% type = 0 - Normal - all sleep metrics
% type = 1 - Minimal - No hourly sleep metrics
%%
if nargin<4
    type=0;
end
%%
if type==0
    % Markers
    LIGHTOFF=Marker_info.LIGHTOFF;
    LIGHTON=Marker_info.LIGHTON;
    RECSTART=Marker_info.RECSTART;
    RECEND=Marker_info.RECEND;
    % find data indices between the Lights-off to Lights-On
    % adjust for irregular time formatting  (not 00 or 30)
    [~,ind_loff] = min(abs(time_vec-LIGHTOFF));
    % Kiran Edit -23.4.20 when epochs are not 00 or 30
    [~,~,sloff]=hms(LIGHTOFF);
    loff_estimate=(time_vec(ind_loff)-LIGHTOFF);
    if (sloff==0 && loff_estimate<0) || (sloff==30 && loff_estimate<0)
        ind_loff=ind_loff+1;
    end
    %
    a1=datevec(LIGHTON);a=round(a1(end));
    if a>15 &&a<=45
        a1(6)=0;
        LON_temp= datetime(a1);
    elseif a>=0 && a<=15
        a1(6)=30;
        a1(5)=a1(5)-1;
        LON_temp= datetime(a1);
    elseif a>45
        a1(6)=30;
        LON_temp= datetime(a1);
    end
    [~,ind_lon] = min(abs(time_vec-LON_temp));
    %Kiran Edit - 23.4.20 when epochs are not 00 or 30
    [~,~,slon]=hms(LON_temp);
    lon_estimate=(time_vec(ind_lon)-LON_temp);
    if (slon==0 && lon_estimate<0) || (slon==30 && lon_estimate<0)
        ind_lon=ind_lon+1;
    end
    % adjust for lights on is over 8 hours and its an artefact, move light on index forward
    % based on input/rule obtained from the statistician involved in the creation of the legacy software
    if ind_lon>ind_loff+960
        while label(ind_lon)==6
            ind_lon=ind_lon-1;
            if ind_lon==ind_loff+960
                break;
            end
        end
    end
    adj=0;
    if label(ind_lon-1)~=5 && label(ind_lon)==5
        adj=0;
    end
    try
    L_label=label(ind_loff:ind_lon-adj);
    catch
     error("Marker info and the hyppnogram timecourse dont match. Check the Marker info")
    end
    %
    num_L_stages=length(L_label);
    if num_L_stages<960
        disp(strcat('Caution:',newline));
        disp('The hypnogram contains less than eight hours between Lights On and Lights Off')
    end
    if rem(num_L_stages,2)==1
        disp(strcat('Caution:',newline));
        disp(strcat('Odd number of epochs between Light On to Lights Off',newline));
    end
    %% Sleep metrics
    % Reference: SSRC PSG Data Extraction Specification
    % Sleep Onset latency (SOL)
    % time in minutes occurring from lights off to the first epoch of NREM or REM
    N_index=find(L_label==1 | L_label==2| L_label==3 | L_label==4);
    True_SOL= time_vec(ind_loff+N_index(1)-1) - time_vec(ind_loff);
    SOL_temp= True_SOL;
    SOL=round(minutes(SOL_temp),1);

    % Latency to persistent sleep (LPS)
    % time in minutes from lights off to the first consecutive 20 epochs of NREM or REM
    Ni=N_index;
    [B, N, Idx] = RunLength(diff(Ni));
    Consecutive = (B == 1);
    Start = Idx(Consecutive);
    len_LPS   = N(Consecutive);
    A=find(len_LPS>=19);
    Latency_index=Ni(Start(A(1)));
    LPS_temp=(Latency_index-1)/2;
    LPS=minutes(round(minutes(LPS_temp)));

    % Final awakening
    % first epoch of wake which is not followed by any epoch of NREM or REM,
    % or lights on whichever comes first   (lights on epoch - ind_lon)
    Lindex_lon =(ind_lon-ind_loff)+2;
    if label(ind_lon)~=5
        FINALAWK=Lindex_lon;
    elseif label(ind_lon)==5
        i=ind_lon;
        while label(i)==5
            i=i-1 ;
        end
        FINALAWK=(i-ind_loff)+2;
    end
    %     FINALAWK
    % Total recording time (TRT)
    % time in minutes from lights out to lights on. This time constitutes the
    % sleep opportunity period. Epochs of sleep are only scored between these two points
    True_TRT=((ind_lon-ind_loff)+1)/2;
    TRT=True_TRT;

    % Total sleep time (TST)
    % time in minutes scored as NREM or REM but excluding epochs of Unsure and
    % Wake within the period between lights off and lights on
    TST_labels=L_label;
    %     W_TST=find(TST_labels==5 | TST_labels==6) ;
    %     TST_labels(W_TST)=[];
    TST_labels(TST_labels==5 | TST_labels==6)=[];
    True_TST=duration(00,length(TST_labels)/2,00);
    TST=minutes(True_TST);

    % Sleep Period Time (SPT)
    % total time in minutes scored as NREM, REM, WAKE occurring from sleep onset
    % until lights on or the FINALAWK, whichever comes first
    if FINALAWK==Lindex_lon
        SPT_labels=L_label(N_index(1):end);
    elseif FINALAWK<Lindex_lon
        SPT_labels=L_label(N_index(1):FINALAWK-1);
    end
    SPT_labels(SPT_labels==6)=[];
    True_SPT=duration(00,length(SPT_labels)/2,00);
    SPT=minutes(True_SPT);

    % Stage W duration (DUR_W) - time in minutes scored as WAKE from lights off to lights on
    W_DUR_W=find(L_label==5) ;
    True_DUR_W=duration(00,length(W_DUR_W)/2,00);
    DUR_W=minutes(True_DUR_W);

    % Stage N1 duration (DUR_N1) - time in minutes scored as N1 from lights off to lights on
    W_DUR_N1=find(L_label==3) ;
    True_DUR_N1=duration(00,length(W_DUR_N1)/2,00);
    DUR_N1=minutes(True_DUR_N1);

    % Stage N2 duration (DUR_N2) - time in minutes scored as N2 from lights off to lights on
    W_DUR_N2=find(L_label==2) ;
    True_DUR_N2=duration(00,length(W_DUR_N2)/2,00);
    DUR_N2=minutes(True_DUR_N2);

    % Stage N3 duration (DUR_N3) - time in minutes scored as N3 from lights off to lights on
    W_DUR_N3=find(L_label==1) ;
    True_DUR_N3=duration(00,length(W_DUR_N3)/2,00);
    DUR_N3=minutes(True_DUR_N3);

    % Duration of REM sleep (DUR_REM)- time in minutes scored as REM from lights off to lights on
    W_DUR_REM=find(L_label==4) ;
    True_DUR_REM=duration(00,length(W_DUR_REM)/2,00);
    DUR_REM=minutes(True_DUR_REM);

    % Duration of NREM sleep (DUR_NREM) - time in minutes scored as NREM from lights off to lights on
    W_DUR_NREM=find(L_label==1|L_label==2|L_label==3) ;
    True_DUR_NREM=duration(00,length(W_DUR_NREM)/2,00);
    DUR_NREM=minutes(True_DUR_NREM);

    % Percent of TST for Stage N1 (PTST_N1) - % of epochs scored as N1 within the total sleep time
    N1_TST=find(TST_labels==3);
    len_N1_TST=length(N1_TST);
    len_TST=length(TST_labels);
    PTST_N1=round((len_N1_TST/len_TST)*100,2);

    % Percent of TST for Stage N2 (PTST_N2) - % of epochs scored as N2 within the total sleep time
    N2_TST=find(TST_labels==2);
    len_N2_TST=length(N2_TST);
    len_TST=length(TST_labels);
    PTST_N2=round((len_N2_TST/len_TST)*100,2);

    % Percent of TST for Stage N3 (PTST_N3) - % of epochs scored as N3 within the total sleep time
    N3_TST=find(TST_labels==1);
    len_N3_TST=length(N3_TST);
    len_TST=length(TST_labels);
    PTST_N3=round((len_N3_TST/len_TST)*100,2);

    % Percent of TST for Stage REM (PTST_REM) - % of epochs scored as REM within the total sleep time
    REM_TST=find(TST_labels==4);
    len_REM_TST=length(REM_TST);
    len_TST=length(TST_labels);
    PTST_REM=round((len_REM_TST/len_TST)*100,2);

    % Percent of TST for Stage NREM (PTST_NREM) - % of epochs scored as NREM within the total sleep time
    NREM_TST=find(L_label==1|L_label==2|L_label==3);
    len_NREM_TST=length(NREM_TST);
    len_TST=length(TST_labels);
    PTST_NREM=round((len_NREM_TST/len_TST)*100,2);

    % Sleep Efficiency (SEFF) - percentage of TST against TRT
    SEFF=round((TST/TRT)*100,2);

    % Number of stage changes (STAGEC) - number of stage transitions from sleep
    % onset until lights on or FINALAWK
    if FINALAWK==Lindex_lon
        STC_labels=L_label(N_index(1):end);
    elseif FINALAWK<Lindex_lon
        STC_labels=L_label(N_index(1):FINALAWK-1);
    end
    STC_labels(STC_labels==6)=[];
    [B_STC, ~, ~] = RunLength(STC_labels);
    STAGEC=length(B_STC);
    if N_index(1)==1
        STAGEC=STAGEC-1;
    end
    % Total Time Awake from SOL (min) (TAWAKE) - time in minutes scored as wake from sleep
    % onset to lights on or FINALAWK
    if FINALAWK==Lindex_lon
        TAW_label=L_label(N_index(1):end);
    elseif FINALAWK<Lindex_lon
        TAW_label=L_label(N_index(1):FINALAWK-1);
    end
    TAWAKE = minutes(duration(0,length(find(TAW_label==5))/2,0));

    % Number of night awakenings after LPS until lights on (NAW) - the number of blocks
    % of consecutive (2) epochs of wake from LPS until lights on
    NAW_labels=L_label(Latency_index:Lindex_lon-1);
    [B_NAW, N_NAW, ~] = RunLength(NAW_labels);
    NAW=length(find((B_NAW==5) & (N_NAW==2)));

    % Number of awakenings after LPS until final awakening (NAWSP)- the number of blocks
    % of consecutive (2) epochs of wake from LPS until FINALAWK
    if FINALAWK==Lindex_lon
        NAWSP_labels=L_label(Latency_index:end);
    elseif FINALAWK<Lindex_lon
        NAWSP_labels=L_label(Latency_index:FINALAWK-1);
    end
    [B_NAWSP, ~, ~] = RunLength(NAWSP_labels);
    NAWSP=length(find(B_NAWSP==5));

    % Wake after sleep onset (WASO) - time in minutes of epochs scored as wake from SOL until lights on
    WASO_labels=L_label(N_index(1):Lindex_lon-1);
    WASO=round(minutes(duration(0,length(find(WASO_labels==5))/2,0)),1);

    % Total duration of awakenings after sleep onset until the final awakening (WASOSP)
    % time in minutes of epochs scored as wake from SOL until FINALAWK
    if FINALAWK==Lindex_lon
        WASOSP_labels=L_label(N_index(1):end);
    elseif FINALAWK<Lindex_lon
        WASOSP_labels=L_label(N_index(1):FINALAWK-1);
    end
    WASOSP=minutes(duration(0,length(find(WASOSP_labels==5))/2,0));

    % Wake after sleep (WAS) - time in minutes from final awakening to lights on
    WAS= minutes(duration(0,(Lindex_lon - FINALAWK)/2,0));

    % Latency to stage N2 (N2_LAT) - time in minutes from lights out to the first epoch of N2
    N2_label=find(L_label==2);
    N2_LAT= round((N2_label(1)-1)/2,1);
    % Latency to N3 (N3_LAT) - the time in minutes from SOL to the first epoch of N3
    N3_label=find(L_label==1);
    N3_LAT= round(minutes(duration(0,(length(L_label(N_index(1):N3_label(1)-1))/2),0)),1);

    % REM Sleep Latency	(REM_LAT) - the time in minutes from SOL to the first epoch of REM
    REM_label=find(L_label==4);
    if isempty(REM_label)
        REM_LAT=NaN;
    else
        REM_LAT= minutes(duration(0,(length(L_label(N_index(1):REM_label(1)-1))/2),0));
    end
    % REM/non-REM ratio (REMRATIO) total duration of REM divided by the total duration of NREM
    REMRATIO=DUR_REM/DUR_NREM;
    % Epochs of Un-scored Sleep (EUS) time in minutes scored as A or Artefact between Lights Off and Lights On
    EUS=length(find(L_label==6))/2;
    %%
    % Splitting the L_labels into 3 parts
    len_third=round(length(L_label)/3);
    DUR_THRD1_label= L_label(1:len_third);
    DUR_THRD2_label= L_label(len_third+1:len_third*2);
    if len_third*3>length(L_label)
        DUR_THRD3_label= L_label(len_third*2+1:end);
    else
        DUR_THRD3_label= L_label(len_third*2+1:len_third*3);
    end
    % Duration of Stage W during 1st 3rd of night (DUR_W_THRD1)	- time in minutes scored as AWAKE occurring
    % within the 1st 3rd of the period from lights off to lights on
    DUR_W_THRD1_temp=length(find(DUR_THRD1_label==5));
    DUR_W_THRD1=minutes(duration(0,(DUR_W_THRD1_temp/2),0));
    % Duration of Stage W during 2nd 3rd of night (DUR_W_THRD2)	- time in minutes scored as AWAKE occurring
    % within the 2nd 3rd of the period from lights off to lights on
    DUR_W_THRD2_temp=length(find(DUR_THRD2_label==5));
    DUR_W_THRD2=minutes(duration(0,(DUR_W_THRD2_temp/2),0));
    % Duration of Stage W during 2nd 3rd of night (DUR_W_THRD3) - time in minutes scored as AWAKE occurring
    % within the final 3rd of the period from lights off to lights on
    DUR_W_THRD3_temp=length(find(DUR_THRD3_label==5));
    DUR_W_THRD3=minutes(duration(0,(DUR_W_THRD3_temp/2),0));

    % Duration of Stage N1 during 1st 3rd of night (DUR_N1_THRD1)	- time in minutes scored as N1 occurring
    % within the 1st 3rd of the period from lights off to lights on
    DUR_N1_THRD1_temp=length(find(DUR_THRD1_label==3));
    DUR_N1_THRD1=minutes(duration(0,(DUR_N1_THRD1_temp/2),0));
    % Duration of Stage N1 during 2nd 3rd of night (DUR_N1_THRD2)	- time in minutes scored as N1 occurring
    % within the 2nd 3rd of the period from lights off to lights on
    DUR_N1_THRD2_temp=length(find(DUR_THRD2_label==3));
    DUR_N1_THRD2=minutes(duration(0,(DUR_N1_THRD2_temp/2),0));
    % Duration of Stage N1 during 2nd 3rd of night (DUR_N1_THRD3) - time in minutes scored as N1 occurring
    % within the final 3rd of the period from lights off to lights on
    DUR_N1_THRD3_temp=length(find(DUR_THRD3_label==3));
    DUR_N1_THRD3=minutes(duration(0,(DUR_N1_THRD3_temp/2),0));

    % Duration of Stage N2 during 1st 3rd of night (DUR_N2_THRD1)	- time in minutes scored as N2 occurring
    % within the 1st 3rd of the period from lights off to lights on
    DUR_N2_THRD1_temp=length(find(DUR_THRD1_label==2));
    DUR_N2_THRD1=minutes(duration(0,(DUR_N2_THRD1_temp/2),0));
    % Duration of Stage N2 during 2nd 3rd of night (DUR_N2_THRD2)	- time in minutes scored as N2 occurring
    % within the 2nd 3rd of the period from lights off to lights on
    DUR_N2_THRD2_temp=length(find(DUR_THRD2_label==2));
    DUR_N2_THRD2=minutes(duration(0,(DUR_N2_THRD2_temp/2),0));
    % Duration of Stage N2 during 2nd 3rd of night (DUR_N2_THRD3) - time in minutes scored as N2 occurring
    % within the final 3rd of the period from lights off to lights on
    DUR_N2_THRD3_temp=length(find(DUR_THRD3_label==2));
    DUR_N2_THRD3=minutes(duration(0,(DUR_N2_THRD3_temp/2),0));

    % Duration of Stage N3 during 1st 3rd of night (DUR_N3_THRD1)	- time in minutes scored as N3 occurring
    % within the 1st 3rd of the period from lights off to lights on
    DUR_N3_THRD1_temp=length(find(DUR_THRD1_label==1));
    DUR_N3_THRD1=minutes(duration(0,(DUR_N3_THRD1_temp/2),0));
    % Duration of Stage N3 during 2nd 3rd of night (DUR_N3_THRD2)	- time in minutes scored as N3 occurring
    % within the 2nd 3rd of the period from lights off to lights on
    DUR_N3_THRD2_temp=length(find(DUR_THRD2_label==1));
    DUR_N3_THRD2=minutes(duration(0,(DUR_N3_THRD2_temp/2),0));
    % Duration of Stage N3 during 2nd 3rd of night (DUR_N3_THRD3) - time in minutes scored as N3 occurring
    % within the final 3rd of the period from lights off to lights on
    DUR_N3_THRD3_temp=length(find(DUR_THRD3_label==1));
    DUR_N3_THRD3=minutes(duration(0,(DUR_N3_THRD3_temp/2),0));

    % Duration of Stage REM during 1st 3rd of night (DUR_REM_THRD1)	- time in minutes scored as REM occurring
    % within the 1st 3rd of the period from lights off to lights on
    DUR_REM_THRD1_temp=length(find(DUR_THRD1_label==4));
    DUR_REM_THRD1=minutes(duration(0,(DUR_REM_THRD1_temp/2),0));
    % Duration of Stage REM during 2nd 3rd of night (DUR_REM_THRD2)	- time in minutes scored as REM occurring
    % within the 2nd 3rd of the period from lights off to lights on
    DUR_REM_THRD2_temp=length(find(DUR_THRD2_label==4));
    DUR_REM_THRD2=minutes(duration(0,(DUR_REM_THRD2_temp/2),0));
    % Duration of Stage REM during 2nd 3rd of night (DUR_REM_THRD3) - time in minutes scored as REM occurring
    % within the final 3rd of the period from lights off to lights on
    DUR_REM_THRD3_temp=length(find(DUR_THRD3_label==4));
    DUR_REM_THRD3=minutes(duration(0,(DUR_REM_THRD3_temp/2),0));

    % Number of night awakenings from Sleep onset during 1st 3rd of night (NAWSL_THRD1)-
    % number of blocks of consecutive epochs of wake occurring within the 1st 3rd of the period from
    % sleep onset to lights on
    % l_thrd=DUR_THRD1_label(Latency_index:end);

    [B_NAW1, ~, ~] = RunLength(DUR_THRD1_label);

    lab_B=find(B_NAW1==1|B_NAW1==2|B_NAW1==3|B_NAW1==4|B_NAW1==6);
    if isempty(lab_B)||length(B_NAW1)==2
        num_B1=0;
    else
        num_B1=length(find(B_NAW1(lab_B(1):end)==5));
    end
    NAWSL_THRD1=num_B1;
    % NAWSL_THRD1=minutes(duration(0,(NAWSL_THRD1_temp/2),0));
    % Number of night awakenings from Sleep onset during 2nd 3rd of night (NAWSL_THRD2)-
    % number of blocks of consecutive epochs of wake occurring within the 2nd 3rd of the period from
    % sleep onset to lights on
    [B_NAW2, ~, ~] = RunLength(DUR_THRD2_label);
    num_B2=length(find(B_NAW2(1:end)==5));
    if B_NAW1(end)==5 && B_NAW2(1)==5
        num_B2=num_B2-1;
    end
    NAWSL_THRD2=num_B2;
    % NAWSL_THRD2=minutes(duration(0,(NAWSL_THRD2_temp/2),0));
    % Number of night awakenings from Sleep onset during final 3rd of night (NAWSL_THRD2)-
    % number of blocks of consecutive epochs of wake occurring within the final 3rd of the period from
    % sleep onset to lights on
    [B_NAW3, ~, ~] = RunLength(DUR_THRD3_label);
    num_B3=length(find(B_NAW3(1:end)==5));
    if B_NAW2(end)==5 && B_NAW3(1)==5
        num_B3=num_B3-1;
    end
    NAWSL_THRD3=num_B3;
    %%
    % Splitting the labels into eight hourd of recording
    % check whether eight hours of data is there i.e 1 hour = 120 epochs
    % implies 960 epochs in the recording

    total_hrs=floor(length(L_label)/120);
    DUR_HR_label=cell(total_hrs,1);DUR_W_HR=cell(total_hrs,1);DUR_REM_HR=cell(total_hrs,1);DUR_N1_HR=cell(total_hrs,1);
    DUR_N2_HR=cell(total_hrs,1);DUR_N3_HR=cell(total_hrs,1);NAWSL_HR=cell(total_hrs,1);num_Br=zeros(total_hrs,1);
    for i=1:total_hrs
        if i==1
            DUR_HR_label{i}=L_label(1:(i*120));
        else
            DUR_HR_label{i}=L_label((120*(i-1)+1):(i*120));
        end
        DUR_W_HR{i}=minutes(duration(0,(length(find(DUR_HR_label{i}==5))/2),0));
        DUR_REM_HR{i}=minutes(duration(0,(length(find(DUR_HR_label{i}==4))/2),0));
        DUR_N1_HR{i}=minutes(duration(0,(length(find(DUR_HR_label{i}==3))/2),0));
        DUR_N2_HR{i}=minutes(duration(0,(length(find(DUR_HR_label{i}==2))/2),0));
        DUR_N3_HR{i}=minutes(duration(0,(length(find(DUR_HR_label{i}==1))/2),0));
        if ((N_index(1)-1)/2)>=60
            if i<=floor(((N_index(1)-1)/2)/60)
                j=1;
            end
        end
        [B_HR, ~, ~] = RunLength(DUR_HR_label{i});
        lab_HR=find(B_HR==1|B_HR==2|B_HR==3|B_HR==4|B_HR==6);
        if isempty(lab_HR)||length(B_HR)==2
            num_Br(i)=0;
        else
            if i==1 || j==1
                num_Br(i)=length(find(B_HR(lab_HR(1):end)==5));
            else
                num_Br(i)=length(find(B_HR(1:end)==5));
            end
        end
        if i>1 && num_Br(i)~=0
            if B_HR_1(end)==5 && B_HR(1)==5
                num_Br(i)=num_Br(i)-1;
            end
        end
        NAWSL_HR{i}=num_Br(i);

        B_HR_1=B_HR;
        j=0;
    end
    % total number of epochs
    n_rec_epochs=length(L_label);
    % total recorded epochs
    n_epochs=length(label);

    %% Saving the data into a excel sheet
    Durations_table = table({getVarName(SOL);getVarName(LPS);getVarName(TRT);getVarName(TST);getVarName(SPT);getVarName(DUR_W);getVarName(DUR_N1);getVarName(DUR_N2);getVarName(DUR_N3);getVarName(DUR_REM);getVarName(DUR_NREM);getVarName(TAWAKE);getVarName(WASO);getVarName(WASOSP);getVarName(WAS);getVarName(N2_LAT);getVarName(N3_LAT);getVarName(REM_LAT)},...
        [SOL;LPS;TRT;TST;SPT;DUR_W;DUR_N1;DUR_N2;DUR_N3;DUR_REM;DUR_NREM;TAWAKE;WASO;WASOSP;WAS;N2_LAT;N3_LAT;REM_LAT]);

    Durations_table2=table({getVarName(DUR_W_THRD1);getVarName(DUR_W_THRD2);getVarName(DUR_W_THRD3);getVarName(DUR_N1_THRD1);getVarName(DUR_N1_THRD2);...
        getVarName(DUR_N1_THRD3);getVarName(DUR_N2_THRD1);getVarName(DUR_N2_THRD2);getVarName(DUR_N2_THRD3);getVarName(DUR_N3_THRD1);getVarName(DUR_N3_THRD2);getVarName(DUR_N3_THRD3);...
        getVarName(DUR_REM_THRD1);getVarName(DUR_REM_THRD2);getVarName(DUR_REM_THRD3);getVarName(NAWSL_THRD1);getVarName(NAWSL_THRD2);getVarName(NAWSL_THRD3)},...
        [DUR_W_THRD1;DUR_W_THRD2;DUR_W_THRD3;DUR_N1_THRD1;DUR_N1_THRD2;DUR_N1_THRD3;DUR_N2_THRD1;DUR_N2_THRD2;DUR_N2_THRD3;DUR_N3_THRD1;DUR_N3_THRD2;DUR_N3_THRD3;...
        DUR_REM_THRD1;DUR_REM_THRD2;DUR_REM_THRD3;NAWSL_THRD1;NAWSL_THRD2;NAWSL_THRD3]);

    HOURS=(1:total_hrs)';
    Durations_hours=[array2table(HOURS),cell2table(DUR_W_HR),cell2table(DUR_N1_HR),cell2table(DUR_N2_HR),cell2table(DUR_N3_HR),cell2table(DUR_REM_HR),cell2table(NAWSL_HR)];

    Duration_table=[Durations_table;Durations_table2];

    Duration_table.Properties.VariableNames= {'Sleep metric','Duration(min)'};

    Percent_table=table({getVarName(PTST_N1);getVarName(PTST_N2);getVarName(PTST_N3);getVarName(PTST_REM);getVarName(PTST_NREM);getVarName(SEFF)},...
        [PTST_N1;PTST_N2;PTST_N3;PTST_REM;PTST_NREM;SEFF]);
    Percent_table.Properties.VariableNames= {'Sleep metric','Percent(%)'};

    Count_table=table({getVarName(STAGEC);getVarName(NAW);getVarName(NAWSP);getVarName(EUS)},[STAGEC;NAW;NAWSP;EUS]);
    Count_table.Properties.VariableNames= {'Sleep metric','Count'};

    header = {getVarName(RECSTART)  RECSTART; getVarName(RECEND) RECEND;getVarName(LIGHTOFF) LIGHTOFF;getVarName(LIGHTON) LIGHTON;...
        getVarName(n_rec_epochs) n_rec_epochs;getVarName(n_epochs) n_epochs;...
        getVarName(FINALAWK) FINALAWK; getVarName(REMRATIO) REMRATIO};

    Out.Duration_table=Duration_table;
    Out.Durations_hours=Durations_hours;
    Out.Percent_table=Percent_table;
    Out.Count_table=Count_table;
    Out.header=header;
    %% TYPE 1 - no hourly estimates
elseif type==1
    % Markers
    LIGHTOFF=Marker_info.LIGHTOFF;
    LIGHTON=Marker_info.LIGHTON;
    RECSTART=Marker_info.RECSTART;
    RECEND=Marker_info.RECEND;
    % find data indices between the Lights-off to Lights-On
    % adjust for irregular time formatting  (not 00 or 30)
    [~,ind_loff] = min(abs(time_vec-LIGHTOFF));
    % Kiran Edit - 23.4.20 when epochs are not 00 or 30
    [~,~,sloff]=hms(LIGHTOFF);
    loff_estimate=(time_vec(ind_loff)-LIGHTOFF);
    if (sloff==0 && loff_estimate<0) || (sloff==30 && loff_estimate<0)
        ind_loff=ind_loff+1;
    end
    a1=datevec(LIGHTON);a=round(a1(end));
    if a>15 &&a<=45
        a1(6)=0;
        LON_temp= datetime(a1);
    elseif a>=0 && a<=15
        a1(6)=30;
        a1(5)=a1(5)-1;
        LON_temp= datetime(a1);
    elseif a>45
        a1(6)=30;
        LON_temp= datetime(a1);
    end
    [~,ind_lon] = min(abs(time_vec-LON_temp));
    % Kiran Edit -  23.4.20 when epochs are not 00 or 30
    [~,~,slon]=hms(LON_temp);
    lon_estimate=(time_vec(ind_lon)-LON_temp);
    if (slon==0 && lon_estimate<0) || (slon==30 && lon_estimate<0)
        ind_lon=ind_lon+1;
    end
    % adjust for lights on is over 8 hours and its an artefact move light on index forward
    % based on input/rule obtained from the statistician involved in the creation of the legacy software
    if ind_lon>ind_loff+960
        while label(ind_lon)==6
            ind_lon=ind_lon-1;
            if ind_lon==ind_loff+960
                break;
            end
        end
    end
    adj=0;
    if label(ind_lon-1)~=5 && label(ind_lon)==5
        adj=0;
    end
    %
    try
    L_label=label(ind_loff:ind_lon-adj);
    catch
     error("Marker info and the hyppnogram timecourse dont match. Check the Marker info")
    end
    %
    num_L_stages=length(L_label);
    if num_L_stages<960
        disp(strcat('Caution:',newline));
        disp('The hypnogram contains less than eight hours between Lights On and Lights Off')
    end
    if rem(num_L_stages,2)==1
        disp(strcat('Caution:',newline));
        disp(strcat('Odd number of epochs between Light On to Lights Off',newline));
    end
    %% Sleep metrics
    % Reference: SSRC PSG Data Extraction Specification

    % Sleep Onset latency (SOL)
    % time in minutes occurring from lights off to the first epoch of NREM or REM
    N_index=find(L_label==1 | L_label==2| L_label==3 | L_label==4);
    True_SOL= time_vec(ind_loff+N_index(1)-1) - time_vec(ind_loff);
    SOL_temp= True_SOL;
    SOL=round(minutes(SOL_temp),1);
    SOT=time_vec(ind_loff+N_index(1)-1);
    % Latency to persistent sleep (LPS)
    % time in minutes from lights off to the first consecutive 20 epochs of NREM or REM
    Ni=N_index;
    [B, N, Idx] = RunLength(diff(Ni));
    Consecutive = (B == 1);
    Start = Idx(Consecutive);
    len_LPS   = N(Consecutive);
    A=find(len_LPS>=19);
    Latency_index=Ni(Start(A(1)));
    LPS_temp=(Latency_index-1)/2;
    LPS=minutes(round(minutes(LPS_temp)));

    % Final awakening
    % first epoch of wake which is not followed by any epoch of NREM or REM,
    % or lights on whichever comes first   (lights on epoch - ind_lon)
    Lindex_lon =(ind_lon-ind_loff)+2;
    if label(ind_lon)~=5
        FINALAWK=Lindex_lon;
    elseif label(ind_lon)==5
        i=ind_lon;
        while label(i)==5
            i=i-1 ;
        end
        FINALAWK=(i-ind_loff)+2;
    end
    if (ind_loff+FINALAWK)<=length(time_vec)
        FAT=time_vec(ind_loff+FINALAWK);
    else
        disp("FINALAWK > total recording time")
        FAT=NaT;
    end
    % Total recording time (TRT)
    % time in minutes from lights out to lights on. This time constitutes the
    % sleep opportunity period. Epochs of sleep are only scored between these two points
    True_TRT=((ind_lon-ind_loff)+1)/2;
    TRT=True_TRT;

    % Total sleep time (TST)
    % time in minutes scored as NREM or REM but excluding epochs of Unsure and
    % Wake within the period between lights off and lights on
    TST_labels=L_label;
    TST_labels(TST_labels==5 | TST_labels==6)=[];
    True_TST=duration(00,length(TST_labels)/2,00);
    TST=minutes(True_TST);

    % Sleep Period Time (SPT)
    % total time in minutes scored as NREM, REM, WAKE occurring from sleep onset
    % until lights on or the FINALAWK, whichever comes first
    if FINALAWK==Lindex_lon
        SPT_labels=L_label(N_index(1):end);
    elseif FINALAWK<Lindex_lon
        SPT_labels=L_label(N_index(1):FINALAWK-1);
    end
    SPT_labels(SPT_labels==6)=[];
    True_SPT=duration(00,length(SPT_labels)/2,00);
    SPT=minutes(True_SPT);

    % Stage W duration (DUR_W) - time in minutes scored as WAKE from lights off to lights on
    W_DUR_W=find(L_label==5) ;
    True_DUR_W=duration(00,length(W_DUR_W)/2,00);
    DUR_W=minutes(True_DUR_W);

    % Stage N1 duration (DUR_N1) - time in minutes scored as N1 from lights off to lights on
    W_DUR_N1=find(L_label==3) ;
    True_DUR_N1=duration(00,length(W_DUR_N1)/2,00);
    DUR_N1=minutes(True_DUR_N1);

    % Stage N2 duration (DUR_N2) - time in minutes scored as N2 from lights off to lights on
    W_DUR_N2=find(L_label==2) ;
    True_DUR_N2=duration(00,length(W_DUR_N2)/2,00);
    DUR_N2=minutes(True_DUR_N2);

    % Stage N3 duration (DUR_N3) - time in minutes scored as N3 from lights off to lights on
    W_DUR_N3=find(L_label==1) ;
    True_DUR_N3=duration(00,length(W_DUR_N3)/2,00);
    DUR_N3=minutes(True_DUR_N3);

    % Duration of REM sleep (DUR_REM)- time in minutes scored as REM from lights off to lights on
    W_DUR_REM=find(L_label==4) ;
    True_DUR_REM=duration(00,length(W_DUR_REM)/2,00);
    DUR_REM=minutes(True_DUR_REM);

    % Duration of NREM sleep (DUR_NREM) - time in minutes scored as NREM from lights off to lights on
    W_DUR_NREM=find(L_label==1|L_label==2|L_label==3) ;
    True_DUR_NREM=duration(00,length(W_DUR_NREM)/2,00);
    DUR_NREM=minutes(True_DUR_NREM);

    % Percent of TST for Stage N1 (PTST_N1) - % of epochs scored as N1 within the total sleep time
    N1_TST=find(TST_labels==3);
    len_N1_TST=length(N1_TST);
    len_TST=length(TST_labels);
    PTST_N1=round((len_N1_TST/len_TST)*100,2);

    % Percent of TST for Stage N2 (PTST_N2) - % of epochs scored as N2 within the total sleep time
    N2_TST=find(TST_labels==2);
    len_N2_TST=length(N2_TST);
    len_TST=length(TST_labels);
    PTST_N2=round((len_N2_TST/len_TST)*100,2);

    % Percent of TST for Stage N3 (PTST_N3) - % of epochs scored as N3 within the total sleep time
    N3_TST=find(TST_labels==1);
    len_N3_TST=length(N3_TST);
    len_TST=length(TST_labels);
    PTST_N3=round((len_N3_TST/len_TST)*100,2);

    % Percent of TST for Stage REM (PTST_REM) - % of epochs scored as REM within the total sleep time
    REM_TST=find(TST_labels==4);
    len_REM_TST=length(REM_TST);
    len_TST=length(TST_labels);
    PTST_REM=round((len_REM_TST/len_TST)*100,2);

    % Percent of TST for Stage NREM (PTST_NREM) - % of epochs scored as NREM within the total sleep time
    NREM_TST=find(L_label==1|L_label==2|L_label==3);
    len_NREM_TST=length(NREM_TST);
    len_TST=length(TST_labels);
    PTST_NREM=round((len_NREM_TST/len_TST)*100,2);

    % Sleep Efficiency (SEFF) - percentage of TST against TRT
    SEFF=round((TST/TRT)*100,2);

    % Number of stage changes (STAGEC) - number of stage transitions from sleep
    % onset until lights on or FINALAWK
    if FINALAWK==Lindex_lon
        STC_labels=L_label(N_index(1):end);%N_index(1)
    elseif FINALAWK<Lindex_lon
        STC_labels=L_label(N_index(1):FINALAWK-1);
    end
    STC_labels(STC_labels==6)=[];
    [B_STC, ~, ~] = RunLength(STC_labels);
    STAGEC=length(B_STC);
    if N_index(1)==1
        STAGEC=STAGEC-1;
    end
    % Total Time Awake from SOL (min) (TAWAKE) - time in minutes scored as wake from sleep
    % onset to lights on or FINALAWK
    if FINALAWK==Lindex_lon
        TAW_label=L_label(N_index(1):end);
    elseif FINALAWK<Lindex_lon
        TAW_label=L_label(N_index(1):FINALAWK-1);
    end
    TAWAKE = minutes(duration(0,length(find(TAW_label==5))/2,0));

    % Number of night awakenings after LPS until lights on (NAW) - the number of blocks
    % of consecutive (2) epochs of wake from LPS until lights on
    NAW_labels=L_label(Latency_index:Lindex_lon-1);
    [B_NAW, N_NAW, ~] = RunLength(NAW_labels);
    NAW=length(find((B_NAW==5) & (N_NAW==2)));

    % Number of awakenings after LPS until final awakening (NAWSP)- the number of blocks
    % of consecutive (2) epochs of wake from LPS until FINALAWK
    if FINALAWK==Lindex_lon
        NAWSP_labels=L_label(Latency_index:end);
    elseif FINALAWK<Lindex_lon
        NAWSP_labels=L_label(Latency_index:FINALAWK-1);
    end
    [B_NAWSP, ~, ~] = RunLength(NAWSP_labels);
    NAWSP=length(find(B_NAWSP==5));
    % Wake after sleep onset (WASO) - time in minutes of epochs scored as wake from SOL until lights on
    WASO_labels=L_label(N_index(1):Lindex_lon-1);
    WASO=round(minutes(duration(0,length(find(WASO_labels==5))/2,0)),1);

    % Total duration of awakenings after sleep onset until the final awakening (WASOSP)
    % time in minutes of epochs scored as wake from SOL until FINALAWK
    if FINALAWK==Lindex_lon
        WASOSP_labels=L_label(N_index(1):end);
    elseif FINALAWK<Lindex_lon
        WASOSP_labels=L_label(N_index(1):FINALAWK-1);
    end
    WASOSP=minutes(duration(0,length(find(WASOSP_labels==5))/2,0));

    % Wake after sleep (WAS) - time in minutes from final awakening to lights on
    WAS= minutes(duration(0,(Lindex_lon - FINALAWK)/2,0));

    % Latency to stage N2 (N2_LAT) - time in minutes from lights out to the first epoch of N2
    N2_label=find(L_label==2);
    N2_LAT= round((N2_label(1)-1)/2,1);
    N2OT=time_vec(ind_loff+N2_label(1)-1);
    % Latency to N3 (N3_LAT) - the time in minutes from SOL to the first epoch of N3
    N3_label=find(L_label==1);
    try
        N3_LAT= round(minutes(duration(0,(length(L_label(N_index(1):N3_label(1)-1))/2),0)),1);
    catch
        N3_LAT=NaN;
    end
    if isempty(N3_label)
        N3OT=NaT;
    else
        N3OT=time_vec(ind_loff+N3_label(1)-1);
    end
    % REM Sleep Latency	(REM_LAT) - the time in minutes from SOL to the first epoch of REM
    REM_label=find(L_label==4);
    if isempty(REM_label)
        REM_LAT=NaN;
    else
        REM_LAT= minutes(duration(0,(length(L_label(N_index(1):REM_label(1)-1))/2),0));
    end
    if isempty(REM_label)
        REMOT=NaT;
    else
        REMOT=time_vec(ind_loff+REM_label(1)-1);
    end
    % REM/non-REM ratio (REMRATIO) total duration of REM divided by the total duration of NREM
    REMRATIO=DUR_REM/DUR_NREM;
    % Epochs of Un-scored Sleep (EUS) time in minutes scored as A or Artefact between Lights Off and Lights On
    EUS=length(find(L_label==6))/2;

    n_rec_epochs=length(L_label);
    % total recorded epochs
    n_epochs=length(label);
    %% Thirds times
    len_third=round(length(L_label)/3);
    THRD1OT= time_vec(ind_loff+len_third);
    THRD2OT= time_vec(ind_loff+(len_third*2));
    try
        if len_third*3>length(L_label)
            THRD3OT= time_vec(ind_loff+length(L_label));
        else
            THRD3OT= time_vec(ind_loff+(len_third*3));
        end
    catch
        if (ind_loff+(len_third*3))>length(L_label)
            disp("THRD3OT > total recording time")
            THRD3OT= time_vec(end);
        end
    end
    %%
    Duration_table = table({getVarName(SOL);getVarName(LPS);getVarName(TRT);getVarName(TST);getVarName(SPT);getVarName(DUR_W);getVarName(DUR_N1);getVarName(DUR_N2);getVarName(DUR_N3);getVarName(DUR_REM);getVarName(DUR_NREM);getVarName(TAWAKE);getVarName(WASO);getVarName(WASOSP);getVarName(WAS);getVarName(N2_LAT);getVarName(N3_LAT);getVarName(REM_LAT)},...
        [SOL;LPS;TRT;TST;SPT;DUR_W;DUR_N1;DUR_N2;DUR_N3;DUR_REM;DUR_NREM;TAWAKE;WASO;WASOSP;WAS;N2_LAT;N3_LAT;REM_LAT]);
    Duration_table.Properties.VariableNames= {'Sleep metric','Duration(min)'};

    Count_table=table({getVarName(STAGEC);getVarName(NAW);getVarName(NAWSP);getVarName(EUS)},[STAGEC;NAW;NAWSP;EUS]);
    Count_table.Properties.VariableNames= {'Sleep metric','Count'};

    Percent_table=table({getVarName(PTST_N1);getVarName(PTST_N2);getVarName(PTST_N3);getVarName(PTST_REM);getVarName(PTST_NREM);getVarName(SEFF)},...
        [PTST_N1;PTST_N2;PTST_N3;PTST_REM;PTST_NREM;SEFF]);
    Percent_table.Properties.VariableNames= {'Sleep metric','Percent(%)'};

    header = {getVarName(RECSTART)  RECSTART; getVarName(RECEND) RECEND;getVarName(LIGHTOFF) LIGHTOFF;getVarName(LIGHTON) LIGHTON;...
        getVarName(n_rec_epochs) n_rec_epochs;getVarName(n_epochs) n_epochs;...
        getVarName(FINALAWK) FINALAWK; getVarName(REMRATIO) REMRATIO};
    % Event Markers
    Event_table=table(RECSTART,RECEND,LIGHTOFF,LIGHTON,SOT,FAT,N2OT,N3OT,REMOT,THRD1OT,THRD2OT,THRD3OT,'VariableNames',{getVarName(RECSTART);getVarName(RECEND);getVarName(LIGHTOFF);getVarName(LIGHTON);getVarName(SOT);getVarName(FAT);...
        getVarName(N2OT);getVarName(N3OT);getVarName(REMOT);getVarName(THRD1OT);getVarName(THRD2OT);getVarName(THRD3OT)});
    %
    Out.Duration_table=Duration_table;
    Out.Percent_table=Percent_table;
    Out.Count_table=Count_table;
    Out.header=header;
    Out.Event_table=Event_table;
end
end

%% convert Variable to Name
function out = getVarName(var)
out = inputname(1);
end
