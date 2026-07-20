%% ULTIMATE STABLE FLUX (ROBUST RENDERER + LARGE ARROWS)
% -------------------------------------------------------------------------
% Fix: Standardized plotting logic from the "Gold Standard" version.
% Fix: Arrows increased by a massive factor for visibility.
% Fix: White background for standard publishing look.
% -------------------------------------------------------------------------
% NO CLEARVARS.

% --- CONFIGURATION ---
rootPath = '/Volumes/fisher_lab/Jacob HD Backup 2025/JHT7/'; 
filename = 'Experiment summary.xlsx'; 

% --- GLOBAL PARAMETERS ---
baseline_idx = 50:55;   
tone_onset = 56;        
rise_frames = 12;       
fs = 18.57;            

% 1. Load Experiment Summary
fullExcelPath = fullfile(pwd, filename); 
rawTable = readtable(fullExcelPath, 'VariableNamingRule', 'preserve', 'ReadVariableNames', false);
allFirstCol = cellstr(string(rawTable{:,1}));
c1_idx = find(strcmp(allFirstCol, 'C1'), 1);
expSummary = rawTable(c1_idx:end, 1:8); 
expSummary.Properties.VariableNames = {'ExperimentType', 'MouseNumber', 'Date', ...
    'FolderPath', 'PreSet1', 'PreSet2', 'PreSet3', 'PostTotal'};

num_exps = height(expSummary);
fprintf('\n>>> Initiating Final Render Pipeline (Visible Arrows)...\n');

%% 2. MAIN PROCESSING LOOP
for r = 1:num_exps
    expID = expSummary.ExperimentType{r};
    baseDir = expSummary.FolderPath{r}; 
    filePrefix = 'pre_10kHz_set_1';
    
    pc1_name = sprintf('PC1_%s_norm_upscaled', expID);
    if ~isfield(all_results, expID) || ~exist(pc1_name, 'var'), continue; end
    
    m_keep = all_results.(expID).spatial(1).pre_m_keep;
    valid_trials = find(m_keep);
    if isempty(valid_trials), continue; end
    
    fprintf('\n======================================================\n');
    fprintf(' PROCESSING: %s\n', expID);
    fprintf('======================================================\n');
    
    % --- STAGE 1: LOADING & AVERAGING ---
    fprintf('Stage 1: Reading TIFFs... ');
    avg_movie = []; loaded_count = 0;
    for t = valid_trials
        trialFullLoc = fullfile(baseDir, sprintf('%s%d.tif', filePrefix, t));
        if ~exist(trialFullLoc, 'file'), continue; end
        
        oldWarn = warning('off', 'all'); 
        tObj = Tiff(trialFullLoc, 'r');
        if isempty(avg_movie)
            tmp = single(tObj.read());
            [H_raw, W_raw] = size(tmp);
            tObj.setDirectory(1); 
        end
        info = imfinfo(trialFullLoc); nImg = numel(info);
        f = zeros(H_raw, W_raw, nImg, 'single');
        for j = 1:nImg
            f(:,:,j) = single(tObj.read());
            if ~tObj.lastDirectory(), tObj.nextDirectory(); end
        end
        close(tObj); warning(oldWarn);
        
        sf = zeros(size(f));
        for j = 1:nImg, sf(:,:,j) = imgaussfilt(double(f(:,:,j)), 10); end
        b_img = mean(sf(:,:,baseline_idx), 3);
        dFF = (sf - b_img) ./ (b_img + eps);
        if isempty(avg_movie), avg_movie = dFF; else, avg_movie = avg_movie + dFF; end
        loaded_count = loaded_count + 1;
    end
    avg_movie = avg_movie ./ loaded_count;
    [H, W, T] = size(avg_movie);
    fprintf('Done.\n');
    
    % --- STAGE 2: PC DENOISING ---
    PC1_res = imresize(eval(pc1_name), [H, W]);
    PC2_res = imresize(eval(sprintf('PC2_%s_norm_upscaled', expID)), [H, W]);
    PC3_res = imresize(eval(sprintf('PC3_%s_norm_upscaled', expID)), [H, W]);
    mov_flat = reshape(avg_movie, [], T); 
    pcs = [PC1_res(:), PC2_res(:), PC3_res(:)]; 
    scores = mov_flat' * pcs; 
    clean_movie = reshape((scores * pcs')', H, W, T);
    
    % --- STAGE 3: LATENCY & BOOSTED FLUX FIELDS ---
    fprintf('Stage 3: Building Flux Fields... ');
    latency_map = nan(H, W);
    for i = 1:H
        for j = 1:W
            tr = squeeze(clean_movie(i,j,:));
            [pmax, ~] = max(tr(tone_onset:min(tone_onset+30, T))); 
            if pmax > 0.001 
                t_rise = find(tr >= pmax * 0.5, 1, 'first');
                if ~isempty(t_rise) && t_rise >= tone_onset
                    latency_map(i,j) = (t_rise - tone_onset) / fs * 1000; 
                end
            end
        end
    end
    
    max_lat = prctile(latency_map(:), 95); 
    if isnan(max_lat) || max_lat <= 0, max_lat = 100; end
    
    flux_win = tone_onset : min(tone_onset + rise_frames, T);
    evoked_expansion = clean_movie(:,:,flux_win);
    dI_dt = mean(diff(evoked_expansion, 1, 3), 3); 
    [gx, gy] = gradient(mean(evoked_expansion, 3));
    v_mag = sqrt(gx.^2 + gy.^2) + eps;
    vx = dI_dt .* (gx ./ v_mag); vy = dI_dt .* (gy ./ v_mag);
    vx = imgaussfilt(vx, 12); vy = imgaussfilt(vy, 12);
    fprintf('Done.\n');

    % --- STAGE 4: RENDERING ---
    fprintf('Stage 4: Rendering... ');
    
    % FIG A: Anatomy
    figure(r); clf;
    imagesc(PC1_res); colormap(gray); axis image; axis off;
    title(['Anatomy: ', expID], 'Interpreter', 'none');
    
    % FIG B: Functional Flux
    figure(r + 100); clf;
    set(gcf, 'Color', 'w'); 
    hold on;
    
    [X_grid, Y_grid] = meshgrid(1:W, 1:H);
    seed_mask = PC1_res > (max(PC1_res(:)) * 0.20); 
    [seed_y, seed_x] = find(seed_mask);
    
    if ~isempty(seed_x)
        target_lines = 70; 
        step_size = max(1, round(length(seed_x) / target_lines));
        sx = seed_x(1:step_size:end); sy = seed_y(1:step_size:end);
        
        h_temp = streamline(X_grid, Y_grid, vx, vy, sx, sy);
        num_l = length(h_temp);
        fprintf('(%d paths) ', num_l);
        
        cmap = jet(256);
        for i = 1:num_l
            x_d = h_temp(i).XData; 
            y_d = h_temp(i).YData;
            
            if length(x_d) < 15, continue; end
            
            lat = interp2(X_grid, Y_grid, latency_map, x_d(1), y_d(1));
            if isnan(lat), lat = 0; end
            c_idx = round(((lat - 0) / (max_lat - 0)) * 255) + 1;
            c_idx = max(1, min(256, c_idx));
            
            % Draw Streamline
            plot(x_d, y_d, 'Color', cmap(c_idx, :), 'LineWidth', 3);
            
            % GIANT ARROWS: Standardization + High Visibility
            mid = round(length(x_d)/2);
            if mid+1 <= length(x_d)
                u = x_d(mid+1) - x_d(mid); 
                v = y_d(mid+1) - y_d(mid);
                mag = sqrt(u^2 + v^2) + eps;
                
                % Arrow multiplier increased to 100, MaxHeadSize increased
                quiver(x_d(mid), y_d(mid), (u/mag)*100, (v/mag)*100, 0, 'k', ...
                    'LineWidth', 1.5, 'MaxHeadSize', 5);
            end
        end
        delete(h_temp); 
    end

    % Final Polish
    colormap(jet); 
    cb = colorbar; 
    clim([0 max_lat]); 
    ylabel(cb, 'Start Latency (ms)');
    title(['Functional Flux: ', expID], 'Interpreter', 'none');
    
    axis image; axis off; set(gca, 'YDir', 'reverse');
    drawnow;
    fprintf('Complete.\n');
    
    waitforbuttonpress;
    clear avg_movie clean_movie sf f dFF scores pcs PC1_res PC2_res PC3_res latency_map;
end