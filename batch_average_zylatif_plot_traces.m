function [av_frames,av_sframes,av_dFF,ind_traces] = batch_average_zylatif_plot_traces(basename,numpix_y,numpix_x,start_trial,end_trial,baselineframes,c)
% Modified to ensure ind_traces are baseline-centered at zero.

num_trials = end_trial - start_trial + 1;

for i = start_trial:end_trial
    filename = [basename int2str(i) '.tif'];
    disp(['Processing: ' filename]);
    
    info = imfinfo(filename);
    num_images = numel(info);
    
    % Initialize container on first trial
    if i == start_trial
        ind_traces = zeros(num_images, num_trials);
    end
    
    % 1. Load Frames
    frames = zeros(numpix_y, numpix_x, 1, num_images);
    for j = 1:num_images
        frames(:,:,1,j) = double(imread(filename, j));
    end
    
    % 2. Spatial Smoothing
    sframes = zeros(numpix_y, numpix_x, 1, num_images);
    for k = 1:num_images
        sframes(:,:,1,k) = imgaussfilt(frames(:,:,1,k), 10);
    end
    
    % 3. Calculate 3D Baseline (for the average dFF output)
    baseline_img = mean(sframes(:,:,1,baselineframes), 4);
    
    % 4. Create trial-specific dFF stack
    dFF = (sframes - baseline_img) ./ (baseline_img + eps);
    
    % 5. Extract the Trace
    raw_trace = roiaverage(dFF, c);
    
    % --- THE CORRECTION STEP ---
    % Even after dFF, the ROI average might not be exactly 0 due to 
    % spatial variance. We force the trace to start at 0 by subtracting
    % the mean of its own baseline period.
    trace_baseline_offset = mean(raw_trace(baselineframes));
    corrected_trace = raw_trace - trace_baseline_offset;
    
    ind_traces(:, i - start_trial + 1) = corrected_trace;
    % ---------------------------
    
    % Accumulate for average movie
    if i == start_trial
        av_frames = frames;
        av_sframes = sframes;
        av_dFF = dFF;
    else
        av_frames = av_frames + frames;
        av_sframes = av_sframes + sframes;
        av_dFF = av_dFF + dFF;
    end
end

% Final normalization
av_dFF = av_dFF / num_trials;

end



% %batch_average_zylatif is a function for opening a set of tif stacks (multipage tif) of images generated with
% %the Zyla camera during our ultrasound experiments. It then creates a dF/F
% %based on the average data.
% %OUTPUTS:
% %ind_traces = array of 1D traces for dF/F of each trial, based on the
% %particular mask ROI specified by c.
% %filename = is a string, it is the basename of the tif stack
% %numpix = number of pixels on one axis of image. We are assuming here that
% %the image is square.
% %start_trial is the trial at which you want to start averaging, in case you
% %don't want to start from the first trial in the experiment set.
% %baseline frames is a vector of numbers of the frames you want to use as
% %background.
% %J.A.N. Fisher 2016
% 
% function [av_frames,av_sframes,av_dFF,ind_traces]= batch_average_zylatif_plot_traces(basename,numpix_y,numpix_x,start_trial,end_trial,baselineframes,c)
% 
% %For each movie in the set that you want to average over, open the
% %particular movie
% for i=start_trial:end_trial
% 
%     filename =[basename int2str(i) '.tif'];
%     disp(filename)
%     %pause
%     info = imfinfo(filename);
%     num_images = numel(info);
%     frames=zeros(numpix_y,numpix_x,1,num_images);
%   %  disp(frames)
% 
%   %Initialize an array container for the dF/F traces
%   if i==start_trial
%       ind_traces = zeros(num_images,end_trial-start_trial+1);
%   else
%   end
% 
%     %For each movie file that you've opened up, create a matrix that has
%     %those images from the multi-page tif.
%     for j = 1:num_images
%         j
%         P = imread(filename,j);
%         frames(:,:,1,j) = P;
%     end
% 
%     %Now we create both a smoothed version of the movie as well as a dF/F
%     %version that utilizes the smoothed version.
%     % Pre-alocate for sframes
%     sframes=zeros(numpix_y,numpix_x,1,num_images);
% 
%     for k = 1:num_images
%     sframes(:,:,1,k) = imgaussfilt(frames(:,:,1,k),10);
%     end
% 
%     %Create a baseline average frame based on how many initial images you
%     %want to average
% 
%     baseline = sum(sframes(:,:,1,baselineframes),4)/numel(baselineframes);
% 
%     %Now create dF, which is the subtraction of your sframes minus the
%     %baseline reference frame
%     for m = 1:num_images
% 
%         dF(:,:,1,m)=sframes(:,:,1,m)-baseline;
%     end
% 
%     %Now create dFF
%     for n = 1:num_images
%         dFF(:,:,1,n)=dF(:,:,1,n)./baseline;
%     end
%     %roiaverage(dFF,c)
%     ind_traces(:,i-start_trial+1)=roiaverage(dFF,c);
%     close
% 
%     if i==start_trial %start_trial==1 | start_trial==end_trial
%         av_frames = frames;
%         av_sframes = sframes;
%         av_dFF = dFF;
%     else
%         av_frames = av_frames+frames;
%         av_sframes = av_sframes+sframes;
%         av_dFF = av_dFF+dFF;
% 
%     end
% end
% %Finally divide the summed frame sets to create averages
% %av_frames = av_frames/(end_trial-start_trial+1);
% %av_sframes = av_sframes/(end_trial-start_trial+1);
% av_dFF = av_dFF/(end_trial-start_trial+1);
% 
% % figure
% % % montage(av_dFF)
% % caxis auto
% % colormap jet
% % colorbar
% % title([basename ' dF/F, average of ' int2str((end_trial-start_trial+1)) ' movies'])
