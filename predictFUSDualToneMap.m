function Final_Gain_Forecast = predictFUSDualToneMap(real_map, pc_percentile_bins, empirical_gain_vector, empirical_distance_microns, anisotropy_weight, pixel_pitch_um, second_tone_map)
% PREDICTFUSDUALTONEMAP - Surgical Planning Dual-Tone Edition
%
% Architecture & Revisions:
%   1. Preserved Grid-Sweep Search: Retains the high-performance initial sweep
%      to accurately anchor the 1D alpha-trough over your data's valley.
%   2. Surgical Boundary Stabilization: Replaces linear gradient scaling with a
%      percentile rank-order tensor and applies wide-domain coordinate field 
%      smoothing to eliminate unneeded granularity for reliable surgical targeting.
%   3. Multi-ROI Superimposition: Cleanly overlays top 10% cortical frequency 
%      boundaries on top of a velvety smooth 2D continuous gain profile.

    %% 1. INPUT ARGUMENT SAFEGUARDS & DEFAULTS
    if nargin < 3
        error('CRITICAL: You must provide at least 3 inputs (map, [], empirical_gain_vector).');
    end
    if nargin < 5 || isempty(anisotropy_weight), anisotropy_weight = 2.0; end
    if nargin < 6 || isempty(pixel_pitch_um), pixel_pitch_um = 1 / 0.3082; end 
    has_second_tone = (nargin >= 7 && ~isempty(second_tone_map));
    
    %% 2. PIPELINE INITIALIZATION & NORMALIZATION
    real_map = double(real_map);
    real_map_norm = (real_map - min(real_map(:))) / (max(real_map(:)) - min(real_map(:)) + eps);
    [rows, cols] = size(real_map_norm);
    
    %% 3. CENTROID DEVIATION IDENTIFICATION (Tone 1 vs Tone 2)
    % Process Primary Tone Map
    top_10_thresh1 = prctile(real_map_norm(:), 90);
    binary_target_zone1 = real_map_norm >= top_10_thresh1;
    [Y_idx1, X_idx1] = find(binary_target_zone1);
    zone_intensities1 = real_map_norm(binary_target_zone1);
    total_mass1 = sum(zone_intensities1);
    X_com1 = sum(X_idx1 .* zone_intensities1) / total_mass1;
    Y_com1 = sum(Y_idx1 .* zone_intensities1) / total_mass1;
    
    % Process Secondary Tone Map (if supplied)
    if has_second_tone
        second_map = double(second_tone_map);
        second_map_norm = (second_map - min(second_map(:))) / (max(second_map(:)) - min(second_map(:)) + eps);
        top_10_thresh2 = prctile(second_map_norm(:), 90);
        binary_target_zone2 = second_map_norm >= top_10_thresh2;
        [Y_idx2, X_idx2] = find(binary_target_zone2);
        zone_intensities2 = second_map_norm(binary_target_zone2);
        total_mass2 = sum(zone_intensities2);
        X_com2 = sum(X_idx2 .* zone_intensities2) / total_mass2;
        Y_com2 = sum(Y_idx2 .* zone_intensities2) / total_mass2;
    end
    
    %% 4. PHYSICAL DATA CONFIGURATION & ASYMMETRIC ALPHA FIT
    raw_dist = empirical_distance_microns(:);
    raw_gain = empirical_gain_vector(:);
    [x_fit, sort_idx] = sort(raw_dist);
    y_fit = raw_gain(sort_idx);
    x_fit(1) = 0; 
    max_input_dist = max(x_fit);
    
    % Unbroken Continuous Asymmetric Alpha Trough Model
    alpha_trough_model = @(p, x) p(1) - abs(p(2)) * ((x ./ max(50, p(3))).^p(4)) .* exp(1 - (x ./ max(50, p(3))).^p(4));
    
    % Objective Loss Function
    function loss = alpha_loss(p, x_d, y_d)
        base   = p(1);
        tau    = p(3);
        p_shft = p(4);
        y_mod = alpha_trough_model(p, x_d);
        loss = sum((y_d - y_mod).^2);
        
        if tau < 200 || tau > max_input_dist * 1.5, loss = loss + 100; end
        if p_shft < 0.5 || p_shft > 4.0,           loss = loss + 100; end
        if base < min(y_d) || base > max(y_d)*1.2, loss = loss + 100; end
    end
    
    % Seed Sweep Arrays
    initial_baseline = max(y_fit);
    initial_amp = max(y_fit) - min(y_fit);
    [~, min_idx] = min(y_fit);
    initial_tau = x_fit(min_idx);
    sweep_baselines  = [initial_baseline, initial_baseline * 1.05];
    sweep_amplitudes = [initial_amp, initial_amp * 1.2];
    sweep_taus       = [initial_tau * 0.8, initial_tau, initial_tau * 1.2];
    sweep_powers     = [1.0, 1.5, 2.0];
    
    best_loss = Inf;
    best_p0 = [initial_baseline, initial_amp, initial_tau, 1.5];
    
    for b = sweep_baselines
        for a = sweep_amplitudes
            for t = sweep_taus
                for pw = sweep_powers
                    test_p = [b, a, t, pw];
                    test_loss = alpha_loss(test_p, x_fit, y_fit);
                    if test_loss < best_loss
                        best_loss = test_loss;
                        best_p0 = test_p;
                    end
                end
            end
        end
    end
    
    % Run optimization search
    opt_options = optimset('MaxFunEvals', 20000, 'MaxIter', 20000, 'Display', 'off');
    optimized_params = fminsearch(@(p) alpha_loss(p, x_fit, y_fit), best_p0, opt_options);
    optimized_params(3) = max(50, abs(optimized_params(3)));
    optimized_params(4) = max(0.5, min(4.0, abs(optimized_params(4))));
    
    fprintf('[Fit Status] Dual-Tone Calibration Complete.\n');
    fprintf('             Recovered Base (B):   %.4f\n', optimized_params(1));
    fprintf('             Dip Amplitude (A):    %.4f\n', -abs(optimized_params(2)));
    fprintf('             Space Constant (tau): %.1f um\n', optimized_params(3));
    fprintf('             Shape Parameter:      %.2f\n', optimized_params(4));
    fprintf('============================================================\n\n');
    
    %% 5. SURGICAL ANISOTROPIC PROPAGATION TENSOR
    [X_grid, Y_grid] = meshgrid(1:cols, 1:rows);
    dX = X_grid - X_com1; dY = Y_grid - Y_com1;
    d_euclidean_pixels = sqrt(dX.^2 + dY.^2);
    
    % Macro anatomical pre-filtering to stabilize tracking fields
    anatomical_blur_sigma = 5.0; 
    smoothed_reference = imgaussfilt(real_map_norm, anatomical_blur_sigma);
    
    [G_x, G_y] = imgradientxy(smoothed_reference, 'CentralDifference');
    [G_mag, Theta_deg] = imgradient(G_x, G_y);
    Theta = Theta_deg * (pi / 180);
    phi_displacement = atan2(dY, dX);
    delta_angle = phi_displacement - Theta;
    
    % --- RANK-ORDER TENSOR NORMALIZATION FOR HIGH-ALPHA STABILITY ---
    [~, sort_gradient_idx] = sort(G_mag(:));
    ranks = zeros(size(G_mag));
    ranks(sort_gradient_idx) = (1:numel(G_mag)) / numel(G_mag);
    G_mag_rank = reshape(ranks, size(G_mag));
    G_mag_rank(real_map_norm < 0.05) = 0; % Eliminate peripheral background variations
    
    % Compute warping grid
    distance_warping_tensor = 1 ./ (1 + anisotropy_weight * G_mag_rank .* (cos(delta_angle).^2));
    d_warped_pixels = d_euclidean_pixels .* distance_warping_tensor;
    
    % --- SURGICAL COORDINATE-FIELD BLURPASS ---
    % Smooth the coordinate field to fully dissolve unneeded pixel-level granularity
    surgical_smoothing_radius = 7.5; 
    d_warped_pixels = imgaussfilt(d_warped_pixels, surgical_smoothing_radius); 
    d_warped_microns = d_warped_pixels * pixel_pitch_um;
    
    %% 6. SMOOTH CONTINUOUS PHENOMENOLOGICAL MAPPING 
    Raw_Predicted_Map = alpha_trough_model(optimized_params, d_warped_microns);
    
    blur_target_um = 30.0; 
    pixel_sigma = blur_target_um / pixel_pitch_um;
    pixel_sigma = max(0.5, pixel_sigma); 
    Smoothed_Predicted_Map = imgaussfilt(Raw_Predicted_Map, pixel_sigma);
    
    active_footprint_mask = real_map_norm > 0.02;
    Final_Gain_Forecast = Smoothed_Predicted_Map .* active_footprint_mask;
    
    %% 7. METRIC BOUNDS FOR COLORMAPPING
    internal_pixels = Final_Gain_Forecast(active_footprint_mask);
    if isempty(internal_pixels), internal_pixels = Final_Gain_Forecast(:); end
    c_min = min(internal_pixels); c_max = max(internal_pixels);
    
    %% 8. ASYMMETRIC DIVERGING COLORMAP PINNED AT 1.0
    num_colors = 256; blue_node = [0.0, 0.35, 0.9]; white_node = [1.0, 1.0, 1.0]; red_node = [0.9, 0.1, 0.1];
    
    if c_min < 1.0 && c_max > 1.0
        fractional_split = (1.0 - c_min) / (c_max - c_min);
        idx_split = max(2, min(num_colors-1, round(fractional_split * num_colors))); 
        custom_diverging_cmap = [linspace(blue_node(1), white_node(1), idx_split)', linspace(blue_node(2), white_node(2), idx_split)', linspace(blue_node(3), white_node(3), idx_split)'; ...
                                 linspace(white_node(1), red_node(1), num_colors-idx_split+1)', linspace(white_node(2), red_node(2), num_colors-idx_split+1)', linspace(white_node(3), red_node(3), num_colors-idx_split+1)'];
        custom_diverging_cmap(idx_split+1, :) = [];
    elseif c_max <= 1.0
        custom_diverging_cmap = [linspace(blue_node(1), white_node(1), num_colors)', linspace(blue_node(2), white_node(2), num_colors)', linspace(blue_node(3), white_node(3), num_colors)'];
    else
        custom_diverging_cmap = [linspace(white_node(1), red_node(1), num_colors)', linspace(white_node(2), red_node(2), num_colors)', linspace(white_node(3), red_node(3), num_colors)'];
    end
    
    %% 9. DUAL TONE METRIC VISUALIZATION PANELS (1 x 3 Layout)
    figSim = figure('Name', 'Multi-Tone Cortical Surgical Overlay Suite', 'NumberTitle', 'off'); clf;
    set(figSim, 'Color', 'w', 'Position', [100, 150, 1700, 520]);
    
    % Subplot 1: Asymmetric Curve Fit Profile
    subplot(1, 3, 1);
    x_plot_dense = linspace(0, max_input_dist * 1.2, 600)'; y_plot_dense = alpha_trough_model(optimized_params, x_plot_dense);
    plot(x_plot_dense, y_plot_dense, 'b-', 'LineWidth', 2.5, 'DisplayName', 'Alpha Trough Fit'); hold on;
    plot(x_fit, y_fit, 'ro', 'MarkerSize', 8, 'LineWidth', 2, 'MarkerFaceColor', [1, 0.7, 0.7], 'DisplayName', 'Data Points');
    grid on; set(gca, 'LineWidth', 1.2, 'FontSize', 11);
    xlim([0, max_input_dist * 1.15]); ylim([min([y_fit; y_plot_dense])*0.95, max([y_fit; y_plot_dense])*1.05]);
    xlabel('Distance From Centroid (\mu m)'); ylabel('Gain Coefficient');
    title('1. Continuous Fit Profile'); legend('Location', 'best');
    
    % Subplot 2: Primary Tone Reference Surface
    subplot(1, 3, 2); imagesc(real_map); hold on;
    colormap(gca, 'parula'); colorbar; axis image;
    plot(X_com1, Y_com1, 'cx', 'MarkerSize', 14, 'LineWidth', 3);
    set(gca, 'LineWidth', 1.2, 'FontSize', 11, 'FontWeight', 'bold');
    xlabel('Cortical X (px)'); ylabel('Cortical Y (px)');
    title('2. Reference Map (Tone 1)');
    
    % Subplot 3: Final Smooth Gain Map Superimposed with Multi-Tone ROIs
    subplot(1, 3, 3); imagesc(Final_Gain_Forecast, [c_min, c_max]); hold on; 
    colormap(gca, custom_diverging_cmap); colorbar; axis image;
    
    % Overlay stabilized structural contour lines for stereotactic tracking
    if abs(c_max - c_min) > 1e-4
        % Darker, thicker contours to make surgical boundaries stand out visually
        contour(Final_Gain_Forecast, linspace(c_min, c_max, 8), 'LineColor', [0.15, 0.15, 0.15], 'LineWidth', 1.1);
    end
    
    % Superimpose Target ROI 1 (Cyan Profile)
    contour(binary_target_zone1, [0.5, 0.5], 'Color', [0.0, 0.9, 0.9], 'LineWidth', 2.5, 'DisplayName', 'Tone 1 Top 10%');
    plot(X_com1, Y_com1, 'c*', 'MarkerSize', 12, 'LineWidth', 2.5);
    
    % Superimpose Target ROI 2 (Magenta Profile) if specified
    if has_second_tone
        contour(binary_target_zone2, [0.5, 0.5], 'Color', [1.0, 0.0, 1.0], 'LineWidth', 2.5, 'DisplayName', 'Tone 2 Top 10%');
        plot(X_com2, Y_com2, 'm*', 'MarkerSize', 12, 'LineWidth', 2.5);
        title('3. Multi-Tone ROI Overlay Matrix');
    else
        title('3. Single-Tone ROI Overlay Matrix');
    end
    
    set(gca, 'LineWidth', 1.2, 'FontSize', 11, 'FontWeight', 'bold');
    xlabel('Cortical X (px)'); ylabel('Cortical Y (px)');
end