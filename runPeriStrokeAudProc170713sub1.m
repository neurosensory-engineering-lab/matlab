clear all
path(path,'~/Dropbox/Addons/')
% close all
%% parameters
param.mua0=0.1;
param.mus0=10;
param.figSaveBool=0;

paramFit.n = 1.4;
paramFit.Reff = 0;
paramFit.lambda = 785;
paramFit.cutoff = 1.1;

param.outFile='audProc170713Pt1-';
dataDir='/Volumes/KINGSTON/DCS/010726-forearm-cuff/';
% dataDir='/home/drbusch/Dropbox/Research/Brain/TBI_NYMC/AuditoryProcessing/Data/20170713-sub1/';
dataFile = 'test010726_0107_1147_';
% dataFile='20170713-sub1_0713_1543_';

param.markBaseRest=[1,2
];
%    7,8;
%    11,12;];
param.markDPAAE=[1 1; 1 1];
param.markActive=[1 1; 1 1];

param.windowT=10; % s, for TCD mean velocity moving window

%  param.markBaseRestI=zeros(size(param.markBaseRest));
%  for ii=1:length(param.markBaseRest(:))
%      param.markBaseRestI(ii)=find(param.markBaseRest(ii)==markVec);
%  end
%  for ii=1:length(param.markDPAAE)
%      param.markDPAAEI(ii)=find(param.markDPAAE(ii)==markVec);
%  end
%
%  for ii=1:length(param.markActive)
%      param.markActiveI(ii)=find(param.markActive(ii)==markVec);
%  end

%%  % working off Ashwin's codes
%  This code will read in all the data… (just call the function once -  it will loop through all the files)
%
% Analog input info: (If you used the Finometer in the ‘RED’ Configuration)
%
% AI 1:4 	— TCD channels 1 through 4
% AI 5 		— Raw Pressure waveform (100 mmHg/Volt)
% AI 6		— Mean Pressure (100 mmHg/Volt) - this is calculated by the finometer
% AI 7		— HR (100 bpm/Volt)
% AI 8 		— CO (10 lpm/Volt)
% AI 9		— Not used
% AI 10	— Not used
% AI 11	— CO2 waveform (100 mmHg = 0.9V)
% AI 12	— EtCO2 (100 mmHg = 0.9V)
% AI 13	— SpO2 (100% Sat = 0.9 V)
% AI 14	— Pulse Rate (250 bpm = 0.9V)
% AI 15	— Respiration Rate (150 bpm = 0.9V)
%

% not data set 1
% If you used the Finometer in the ‘ORANGE’ Configuration, everything is the same except for the Finometer outputs
%
% AI 5 		— Raw Pressure waveform (100 mmHg/Volt)
% AI 6		— SYStolic Pressure (100 mmHg/Volt) - this is calculated by the finometer
% AI 7		— DIAstolic Pressure (100 mmHg/Volt) - this is calculated by the finometer
% AI 8 		— CO (10 lpm/Volt)
%
%
%

% dataChannels=...
%     {'TCD1'...1
%     'TCD2'...2
%     'TCD3'...3
%     'TCD4'...4
%     'Raw Pressure'...5
%     'Mean Pressure'...6
%     'HR'...7
%     'CO'...8
%     ''...9
%     ''...10
%     'CO2'...11
%     'EtCO2'...12
%     'SpO2'...13
%     'Pulse Rate'...14
%     'RR'...15
%     ''...16
%     };
% dataUnitConv=[
%     1 1 1 1 ... TCD channels
%     100 ... 5 Raw Pressure waveform (100 mmHg/Volt)
%     100 ...% AI 6		— Mean Pressure (100 mmHg/Volt) - this is calculated by the finometer
%     100 ...% AI 7		— HR (100 bpm/Volt)
% 10  ...% AI 8 		— CO (10 lpm/Volt)
% 1 ... % AI 9		— Not used
% 1 ... % AI 10	— Not used
% 100/0.9 ...% AI 11	— CO2 waveform (100 mmHg = 0.9V)
% 100/0.9 ...% AI 12	— EtCO2 (100 mmHg = 0.9V)
% 100/0.9 ...% AI 13	— SpO2 (100% Sat = 0.9 V)
% 250/0.9 ...% AI 14	— Pulse Rate (250 bpm = 0.9V)
% 150/0.9 ...% AI 15	— Respiration Rate (150 bpm = 0.9V)
% 1 ...
%      ];

%
%  dataUnit={...
%      'au'; 'au'; 'au'; 'au'; % AI 1:4 	— TCD channels 1 through 4
% 'mmHg'; % AI 5 		— Raw Pressure waveform (100 mmHg/Volt)
% 'mmHg'; % AI 6		— Mean Pressure (100 mmHg/Volt) - this is calculated by the finometer
% 'bpm'; % AI 7		— HR (100 bpm/Volt)
% 'lpm'; % AI 8 		— CO (10 lpm/Volt)
% 'NOT USED'% AI 9		— Not used
% 'NOT USED'% AI 10	— Not used
% 'mmHg'; % AI 11	— CO2 waveform (100 mmHg = 0.9V)
% 'mmHg'; % AI 12	— EtCO2 (100 mmHg = 0.9V)
% '%'; % AI 13	— SpO2 (100% Sat = 0.9 V)
% 'min^{-1}'; % AI 14	— Pulse Rate (250 bpm = 0.9V)
% 'min^{-1}'; % AI 15	— Respiration Rate (150 bpm = 0.9V)
% 'NOT USED';
% %
% };
dataChannels=...
    {'TCD1'...1
    'TCD2'...2
    'TCD3'...3
    'TCD4'...4
    'Raw_Pressure'...5
    'Mean_Pressure'...6
    'NOT_USED'...7
    'CO'...8
    'NOT_USED'...9
    'NOT_USED'...10
    'EtCO2'...11
    'RR'...12
    'CO2 wave'...13
    'SpO2'...14
    'SpO2_wave'...15
    'HR'...16
    };

dataUnitConv=[
    1 1 1 1 ... TCD channels
    100 ... 5 Raw Pressure waveform (100 mmHg/Volt)
    100 ...% AI 6		— Mean Pressure (100 mmHg/Volt) - this is calculated by the finometer
    1 ...% AI 7		— HR (100 bpm/Volt)
    10  ...% AI 8 		— CO (10 lpm/Volt)
    1 ... % AI 9		— Not used
    1 ... % AI 10	— Not used
    100/0.9 ...% AI 11	— CO2 waveform (100 mmHg = 0.9V)
    150/0.9 ...% AI 12	— EtCO2 (100 mmHg = 0.9V)
    100/0.9 ...% AI 13	— SpO2 (100% Sat = 0.9 V)
    100/0.9 ...% AI 14	— Pulse Rate (250 bpm = 0.9V)
    255/0.9 ...% AI 15	— Respiration Rate (150 bpm = 0.9V)
    250/0.9 ...
    ];

dataUnit={...
    'au'; 'au'; 'au'; 'au'; % AI 1:4 	— TCD channels 1 through 4
    'mmHg'; % AI 5 		— Raw Pressure waveform (100 mmHg/Volt)
    'mmHg'; % AI 6		— Mean Pressure (100 mmHg/Volt) - this is calculated by the finometer
    'NOT_USED'; % AI 7		— HR (100 bpm/Volt)
    'lpm'; % AI 8 		— CO (10 lpm/Volt)
    'NOT_USED'% AI 9		— Not used
    'NOT_USED'% AI 10	— Not used
    'mmHg'; % AI 11	— CO2 waveform (100 mmHg = 0.9V)
    'min^{-1}'; % AI 12	— EtCO2 (100 mmHg = 0.9V)
    'mmHg'; % AI 13	— SpO2 (100% Sat = 0.9 V)
    '%'; % AI 14	— Pulse Rate (250 bpm = 0.9V)
    '%'; % AI 15	— Respiration Rate (150 bpm = 0.9V)
    'min^{-1}';
    %
    };

% not data set 1
% If you used the Finometer in the ‘ORANGE’ Configuration, everything is the same except for the Finometer outputs
%
% AI 5 		— Raw Pressure waveform (100 mmHg/Volt)
% AI 6		— SYStolic Pressure (100 mmHg/Volt) - this is calculated by the finometer
% AI 7		— DIAstolic Pressure (100 mmHg/Volt) - this is calculated by the finometer
% AI 8 		— CO (10 lpm/Volt)
%
%  [fname, exp_path] = uigetfile('*.dcs','Select SW DCS data file series');
% cd(exp_path);


% foo = fname(1:end-10);
% files = dir([foo '*.dcs']);

%%

files2=dir([dataDir dataFile '*.dcs'])
files=files2;
for ii=1:length(files2)
    files(ii).name=[dataDir files2(ii).name];
end
%%
[FrameIDX_DCS, TimeAxis_DCS, DelayTimes, Marks_DCS, AI_Data, g2Data, Intensities] = readDCSdata_SWC(files);

%%
markIndex=find(Marks_DCS);
markVec=1:length(markIndex);
param.markBaseRestI=markIndex(param.markBaseRest);
param.markDPAAEI=markIndex(param.markDPAAE);
param.markActiveI=markIndex(param.markActive);
param.bkgnd=param.markBaseRest(1,:);
param.bkgndI=param.markBaseRestI(1,:);


% %% normalize the data to baseline, add units
% for ii=1:size(AI_Data,1);
%     AI_DataN(ii,:)=AI_Data(ii,:)/nanmean(AI_Data(ii,param.markBaseRestI(1,1):param.markBaseRestI(1,2)));
%     AI_DataU(ii,:)=AI_Data(ii,:)*dataUnitConv(ii);
% end

%% fit the dcs data
for ii=1:10
    sprintf('\n');
end;clear ii

fdet(1).values = [2.5 2:4];
fdet(2).values = [2.5 6:8];
[bfi,g2data,g2fit,beta,rho,intdcs] = fastdcs1layer(['tmp-fit-seminf'],fdet,g2Data,Intensities,DelayTimes,...
    param.mua0,param.mus0,param.bkgndI);
%% normalize bfi
bfi=bfi*1e9; % convert to 1/ns
for ii=1:size(bfi,2)
    bfiR(:,ii)=bfi(:,ii)./nanmean(bfi(param.bkgndI(1):param.bkgndI(2),ii));
end;clear ii

%% calculate moving window of TCD data



% figure out the data frequency/timestep
tt=(TimeAxis_DCS(2:end)-TimeAxis_DCS(1:(end-1)));
param.dataTimeStep=nanmean(tt); % s
param.dataFreq=1/param.dataTimeStep; %Hz
clear tt

% how many points need ed for an X moving window?

param.windowPts=round(param.windowT/param.dataTimeStep);



tdat=AI_DataU(1,:);
tdatS=tdFiltMod(tdat,param.windowPts);



% tgo=30000;
% tst=tgo+1000;
% 
% 
% 
% figure(34);clf
% subplot(2,2,1)
% plot(TimeAxis_DCS, tdat,'mo');
% hold on
% plot(TimeAxis_DCS, tdatS,'rx')
% vline(TimeAxis_DCS([tgo tst]),'g')
% set(gca,'FontSize',18)
% xlabel('Time [s]')
% ylabel('TCD Vel. [a.u.]')
% title('TCD with smoothed version Left')
% 
% subplot(2,2,3)
% plot(TimeAxis_DCS(tgo:tst), tdat(tgo:tst),'mo');
% hold on
% plot(TimeAxis_DCS(tgo:tst), tdatS(tgo:tst),'rx')
% axis tight
% set(gca,'FontSize',18)
% xlabel('Time [s]')
% ylabel('TCD Vel. [a.u.]')
% title('TCD with smoothed version Left')
% 
% % Forcing smoothed data for TCD
% AI_DataU(1,:)=tdatS;
% 
% clear tdatS tdat
% 
% tdat=AI_DataU(3,:);
% tdatS=tdFiltMod(tdat,param.windowPts);
% 
% subplot(2,2,2)
% plot(TimeAxis_DCS, tdat,'co');
% hold on
% plot(TimeAxis_DCS, tdatS,'bx')
% vline(TimeAxis_DCS([tgo tst]),'g')
% set(gca,'FontSize',18)
% xlabel('Time [s]')
% ylabel('TCD Vel. [a.u.]')
% title('TCD with smoothed version Right')
% subplot(2,2,4)
% plot(TimeAxis_DCS(tgo:tst), tdat(tgo:tst),'co');
% hold on
% plot(TimeAxis_DCS(tgo:tst), tdatS(tgo:tst),'bx')
% axis tight
% set(gca,'FontSize',18)
% xlabel('Time [s]')
% ylabel('TCD Vel. [a.u.]')
% title('TCD with smoothed version Right')
% % Forcing smoothed data for TCD
% AI_DataU(3,:)=tdatS;
% 
% clear tdatS tdat


%% outputs

outHdr=['Time' 'bfi_Right' 'bfi_Left' 'rbfi_Right' 'rbfi_Left' dataChannels 'mark' 'markRegion' 'resistance'];
outUnits=['s' 'cm^2/ns' 'cm^2/ns' '1' '1' dataUnit' 'NA' 'NA' 'mmHg'];

% make some vectors to communicate regions
markVecLong=nan(size(Marks_DCS));
for ii=1:length(markVec)
    markVecLong(markIndex(ii))=markVec(ii);
end; clear ii
markVecLongRegion=nan(size(Marks_DCS));
markVecLongRegion(1:markIndex(1))=0;
for ii=1:(length(markVec)-1)
    markVecLongRegion(markIndex(ii):markIndex(ii+1))=markVec(ii);
end
markVecLongRegion(markIndex(end):end)=markVec(end);

regVec=nan(size(Marks_DCS));
for ii=1:size(param.markBaseRestI,1)
    regVec(param.markBaseRestI(ii,1):param.markBaseRestI(ii,2))=0;
end
regVec(param.markDPAAEI(1):param.markDPAAEI(2))=6;
regVec(param.markActiveI(1):param.markActiveI(2))=12;

outArr=[TimeAxis_DCS bfi bfiR AI_DataU' markVecLong markVecLongRegion regVec];

fid=fopen([param.outFile '.csv'],'w');
outStr=[];
for ii=1:(length(outHdr)-1)
    fprintf(fid,'%s,\t',outHdr{ii});
    outStr=[outStr '%g,\t'];
end
fprintf(fid,'%s\n',outHdr{ii+1});
outStr=[outStr '%g\n'];
for ii=1:(length(outUnits)-1)
    fprintf(fid,'%s,\t',outUnits{ii});
end
fprintf(fid,'%s\n',outUnits{ii+1});

fprintf(fid,outStr,outArr')
fclose(fid);clear fid



%% save
% save('tmp.mat')
close all
save([param.outFile '.mat'])
%%  sanity plot

fid=figure(1);clf;
set(gcf,'Position',[676          27        1920        1066])
h=4;w=4;
for ii=1:16
    tdat=AI_Data(ii,:);
    subplot(h,w,ii)
    plot(tdat,'x')
    title([dataChannels{ii} 'raw'])
    axis tight
    ylim(prctile(tdat,[1 99]))
    vline(markIndex)
    % mark the baseline region
    vline(param.markBaseRestI(1,:),'b')
    % mark the rest regions
    vline(param.markBaseRestI(2,:),'c')
    vline(param.markBaseRestI(3,:),'c')
    % mark the test regions
    vline(param.markDPAAEI(:),'m')
    vline(param.markActiveI(:),'r')
end
fsavefig(fid,'respRestTest',param.figSaveBool)
% normalized
fid=figure(2);clf;
set(gcf,'Position',[676          27        1920        1066])
h=4;w=4;
for ii=1:16
    tdat=AI_DataN(ii,:);
    subplot(h,w,ii)
    plot(tdat,'x')
    title([dataChannels{ii} ' norm'])
    axis tight
    ylim(prctile(tdat,[1 99]))
    vline(markIndex)
    % mark the baseline region
    vline(param.markBaseRestI(1,:),'b')
    % mark the rest regions
    vline(param.markBaseRestI(2,:),'c')
    vline(param.markBaseRestI(3,:),'c')
    % mark the test regions
    vline(param.markDPAAEI(:),'m')
    vline(param.markActiveI(:),'r')
end
fsavefig(fid,'respRestTest-norm',param.figSaveBool)
%% units
fid=figure(3);clf;
set(gcf,'Position',[676          27        1920        1066])
h=4;w=4;
for ii=1:16
    tdat=AI_DataU(ii,:);
    subplot(h,w,ii)
    plot(tdat,'x')
    title([dataChannels{ii} ' units'])
    axis tight
    tlim=prctile(tdat,[1 99]);
    if unique(tlim)==0
        ylim([-1 1])
    else
        ylim(tlim);
    end
    clear tlim
    ylabel(dataUnit{ii})
    vline(markIndex)
    % mark the baseline region
    vline(param.markBaseRestI(1,:),'b')
    % mark the rest regions
    vline(param.markBaseRestI(2,:),'c')
    vline(param.markBaseRestI(3,:),'c')
    % mark the test regions
    vline(param.markDPAAEI(:),'m')
    vline(param.markActiveI(:),'r')
end
fsavefig(fid,'respRestTest-units',param.figSaveBool)

%% look at resistance and blood flow


fid=figure(4);clf
subplot(3,1,1)
plot(outArr(:,1),outArr(:,4),'rx')
hold on
tind=5;
plot(outArr(:,1),outArr(:,5),'bx')
axis tight
set(gca,'FontSize',16)
xlabel([outHdr{1} ' ' outUnits{1}])
ylabel(['rBFI'])


subplot(3,1,2)
plot(outArr(:,1),outArr(:,6),'rx')
hold on
tind=5;
plot(outArr(:,1),outArr(:,8),'bx')
axis tight
set(gca,'FontSize',16)
xlabel([outHdr{1} ' ' outUnits{1}])
ylabel(['TCD'])


subplot(3,1,3)
tind=24; % resistance
plot(outArr(:,1),outArr(:,tind),'kx')
axis tight
set(gca,'FontSize',16)
xlabel([outHdr{1} ' ' outUnits{1}])
ylabel([outHdr{tind} ' ' outUnits{tind}])
fsavefig(fid,'respRestTest-rBFIandResistanceVsTime',param.figSaveBool)

%%
fid=figure(5);clf
tgo=param.bkgndI(1);
tst=max(param.markBaseRestI(:,2)); %

% limit output
yl=[ 0.8 prctile(outArr(tgo:tst,4),[98])];
% subplot(3,1,1)
plot(outArr(tgo:tst,1),outArr(tgo:tst,4),'rx')
hold on
tind=5;
plot(outArr(tgo:tst,1),outArr(tgo:tst,5),'bx')
axis tight
set(gca,'FontSize',16)
xlabel([outHdr{1} ' ' outUnits{1}])
ylabel(['rBFI'])
ylim(yl)


vline(outArr(param.markBaseRestI,1),'k')
vline(outArr(param.markActiveI,1),'r')
vline(outArr(param.markDPAAEI,1),'b')

% 
% subplot(3,1,2)
% plot(outArr(tgo:tst,1),outArr(tgo:tst,6),'rx')
% hold on
% tind=5;
% plot(outArr(tgo:tst,1),outArr(tgo:tst,8),'bx')
% axis tight
% set(gca,'FontSize',16)
% xlabel([outHdr{1} ' ' outUnits{1}])
% ylabel(['TCD'])
% 
% 
% subplot(3,1,3)
% tind=24; % resistance
% plot(outArr(tgo:tst,1),outArr(tgo:tst,tind),'kx')
% axis tight
% set(gca,'FontSize',16)
% xlabel([outHdr{1} ' ' outUnits{1}])
% ylabel([outHdr{tind} ' ' outUnits{tind}])
% fsavefig(fid,'respRestTest-rBFIandResistanceVsTimeShort',param.figSaveBool)



