function [FrameIDX_DCS, TimeAxis_DCS, DelayTimes, Marks_DCS, AI_Data, g2Data, Intensities] = readDCSdata_SWC(files)

nFiles = numel(files);

% First read all the data
A = [];
for i = 1:nFiles
    files(i).name
    fid = fopen(files(i).name);
    A = [A; fread(fid,Inf,'double',0,'b')];
    A
    pause
    fclose(fid);
    
end

% Reshape the data
DCS_Data = reshape(A, 9,43, []);

% Separate into variables, and eliminae first point
FrameIDX_DCS    = squeeze(DCS_Data(1   ,1       ,2:end  ));
TimeAxis_DCS    = squeeze(DCS_Data(1   ,2       ,2:end  ));  
DelayTimes      = squeeze(DCS_Data(1   ,3:end-1 ,1      ));   % Delay times are same in each frame
Marks_DCS       = squeeze(DCS_Data(1   ,end     ,2:end  ));

AI_temp         = squeeze(DCS_Data(2:end, 1:2   ,2:end  ));
AI_Data         = squeeze(reshape(AI_temp,16,1,[]));

g2Data          = squeeze(DCS_Data(2:end    ,3:end-1    ,2:end));
Intensities     = squeeze(DCS_Data(2:end    ,end        ,2:end));

