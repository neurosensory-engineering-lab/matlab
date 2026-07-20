function Final_Gain_Forecast = predictFUSGainMap(real_map, pc_percentile_bins, empirical_gain_vector, empirical_distance_microns, anisotropy_weight, pixel_pitch_um)
% PREDICTFUSGAINMAP - Surgical Planning Edition
%
% Architecture & Revisions:
%   1. Preserved Grid-Sweep Optimizer: Keeps your high-performance 1D curve 
%      fitting engine working exactly as intended.
%   2. Surgical Boundary Smoothing: Replaces high-frequency noise with a 
%      dual-stage Gaussian coordinate-field filter (sigma = 7.5 px) to eliminate 
%      artificial "islands" and produce continuous, reliable surgical margins.
%   3. Rank-Order Gradient Uniformity: Prevents high anisotropy weights from 
%      tearing the map apart along blood vessel scars.

    %% 1. INPUT ARGUMENT SAFEGUARDS & DEFAULTS
    if nargin < 3
        error('CRITICAL: You must provide at least 3 inputs.');
    end
    if nargin < 5 || isempty(anisotropy_weight), anisotropy_weight = 2.0; end
    if nargin < 6 || isempty(pixel_pitch_um), pixel_pitch_um = 1 / 0.3082; end 
    
    %% 2. PIPELINE INITIALIZATION & PRE-FILTERS
    real_map = double(real_map);
    real_map_norm = (real_map - min(real_map(:))) / (max(real_map(:)) - min(real_map(:)) + eps);
    [rows, cols] = size(real_map_norm);
    
    %% 3. CENTROID DEVIATION IDENTIFICATION (90th Percentile COM)
    top_10_thresh = prctile(real_map_norm(:), 90);
    binary_target_zone = real_map_norm >= top_10_thresh;
    [Y_idx, X_idx] = find(binary_target_zone);
    zone_intensities = real_map_norm(binary_target_zone);
    total_mass = sum(zone_intensities);
    X_com = sum(X_idx .* zone_intensities) / total_mass;
    Y_com = sum(Y_idx .* zone_intensities) / total_mass;
    
    %% 4. PHYSICAL DATA CONFIGURATION & ASYMMETRIC ALPHA FIT (YOUR ACCURATE ENGINE)
    raw_dist = empirical_distance_microns(:);
    raw_gain = empirical_gain_vector(:);
    [x_fit, sort_idx] = sort(raw_dist);
    y_fit = raw_gain(sort_idx);
    x_fit(1) = 0; 
    max_input_dist = max(x_fit);
    
    alpha_trough_model = @(p, x) p(1) - abs(p(2)) * ((x ./ max(50, p(3))).^p(4)) .* exp(1 - (x ./ max(50, p(3))).^p(4));
    
    function loss = alpha_loss(p, x_d, y_d)
        tau    = p(3);
        p_shft = p(4);
        y_mod = alpha_trough_model(p, x_d);
        loss = sum((y_d - y_mod).^2);
        if tau < 50 || tau > max_input_dist * 2.0, loss = loss + 1000; end
        if p_shft < 0.2 || p_shft > 5.0,           loss = loss + 1000; end
    end
    
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
    
    opt_options = optimset('MaxFunEvals', 20000, 'MaxIter', 20000, 'Display', 'off');
    optimized_params = fminsearch(@(p) alpha_loss(p, x_fit, y_fit), best_p0, opt_options);
    
    optimized_params(3) = max(50, abs(optimized_params(3)));
    optimized_params(4) = max(0.2, min(5.0, abs(optimized_params(4))));
    
    fprintf('[Fit Status] Bounded Calibration Engine Loaded.\n');
    fprintf('             Recovered Base (B):   %.4f\n', optimized_params(1));
    fprintf('             Dip Amplitude (A):    %.4f\n', -abs(optimized_params(2)));
    fprintf('             Space Constant (tau): %.1f um\n', optimized_params(3));
    fprintf('             Shape Parameter:      %.2f\n', optimized_params(4));
    fprintf('============================================================\n\n');
    
    %% 5. SURGICAL COORDINATE-FIELD STABILIZATION ENGINE
    [X_grid, Y_grid] = meshgrid(1:cols, 1:rows);
    dX = X_grid - X_com; dY = Y_grid - Y_com;
    d_euclidean_pixels = sqrt(dX.^2 + dY.^2);
    
    % Step 1: Smooth out the raw reference topography to isolate macro cortical structures
    anatomical_blur_sigma = 5.0; 
    smoothed_reference = imgaussfilt(real_map_norm, anatomical_blur_sigma);
    
    [G_x, G_y] = imgradientxy(smoothed_reference, 'CentralDifference');
    [G_mag, Theta_deg] = imgradient(G_x, G_y);
    
    Theta = Theta_deg * (pi / 180);
    phi_displacement = atan2(dY, dX);
    delta_angle = phi_displacement - Theta;
    
    % Step 2: Rank-Order Gradient Scaling (Neutralizes micro-vessel local spikes)
    [~, sort_gradient_idx] = sort(G_mag(:));
    ranks = zeros(size(G_mag));
    ranks(sort_gradient_idx) = (1:numel(G_mag)) / numel(G_mag);
    G_mag_rank = reshape(ranks, size(G_mag));
    G_mag_rank(real_map_norm < 0.05) = 0; 
    
    % Step 3: Compute the anisotropic tensor grid
    distance_warping_tensor = 1 ./ (1 + anisotropy_weight * G_mag_rank .* (cos(delta_angle).^2));
    d_warped_pixels = d_euclidean_pixels .* distance_warping_tensor;
    
    % --- CRITICAL CORRECTION FOR SURGICAL UTILITY ---
    % Apply a wide-domain spatial filter to the warped distance coordinates.
    % This completely dissolves high-frequency noise and guarantees continuous map contours.
    surgical_smoothing_radius = 7.5; 
    d_warped_pixels = imgaussfilt(d_warped_pixels, surgical_smoothing_radius); 
    d_warped_microns = d_warped_pixels * pixel_pitch_um;
    
    %% 6. SMOOTH CONTINUOUS PHENOMENOLOGICAL MAPPING 
    Raw_Predicted_Map = alpha_trough_model(optimized_params, d_warped_microns);
    
    blur_target_um = 30.0; 
    pixel_sigma = max(0.5, blur_target_um / pixel_pitch_um); 
    Smoothed_Predicted_Map = imgaussfilt(Raw_Predicted_Map, pixel_sigma);
    
    active_footprint_mask = real_map_norm > 0.02;
    Final_Gain_Forecast = Smoothed_Predicted_Map .* active_footprint_mask;
    
    %% 7. METRIC BOUNDS FOR DIVERGING SCALE
    internal_pixels = Final_Gain_Forecast(active_footprint_mask);
    if isempty(internal_pixels), internal_pixels = Final_Gain_Forecast(:); end
    c_min = min(internal_pixels); c_max = max(internal_pixels);
    
    %% 8. ASYMMETRIC DIVERGING COLORMAP PINNED AT 1.0 (WHITE)
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
    
    %% 9. PRODUCTION VISUALIZATION SUITE (SURGICAL RESOLUTION)
    figSim = figure('Name', 'Surgical Planning Alpha Trough Interface', 'NumberTitle', 'off'); clf;
    set(figSim, 'Color', 'w', 'Position', [100, 150, 1650, 500]);
    
    subplot(1, 3, 1);
    x_plot_dense = linspace(0, max_input_dist * 1.2, 600)'; y_plot_dense = alpha_trough_model(optimized_params, x_plot_dense);
    plot(x_plot_dense, y_plot_dense, 'b-', 'LineWidth', 2.5, 'DisplayName', 'Alpha Trough Fit'); hold on;
    plot(x_fit, y_fit, 'ro', 'MarkerSize', 8, 'LineWidth', 2, 'MarkerFaceColor', [1, 0.7, 0.7], 'DisplayName', 'Empirical Points');
    grid on; set(gca, 'LineWidth', 1.2, 'FontSize', 11);
    xlim([0, max_input_dist * 1.15]); ylim([min([y_fit; y_plot_dense])*0.95, max([y_fit; y_plot_dense])*1.05]);
    xlabel('True Physical Distance (\mu m)'); ylabel('Raw Gain Value');
    title('1. Continuous Asymmetric Profile'); legend('Location', 'best');
    
    subplot(1, 3, 2); imagesc(real_map); hold on;
    colormap(gca, 'parula'); colorbar; axis image;
    plot(X_com, Y_com, 'rx', 'MarkerSize', 14, 'LineWidth', 3);
    set(gca, 'LineWidth', 1.2, 'FontSize', 11, 'FontWeight', 'bold');
    xlabel('Cortical X Position (px)'); ylabel('Cortical Y Position (px)');
    title('2. Individual Surgical Reference');
    
    % Subplot 3: High-Alpha Continuous Surgical Target Map
    subplot(1, 3, 3); imagesc(Final_Gain_Forecast, [c_min, c_max]); hold on; 
    colormap(gca, custom_diverging_cmap); colorbar; axis image;
    if abs(c_max - c_min) > 1e-4
        % Generates clean, solid contour rings for stereotactic tracking
        contour(Final_Gain_Forecast, linspace(c_min, c_max, 8), 'LineColor', [0.1, 0.1, 0.1], 'LineWidth', 1.2);
    end
    plot(X_com, Y_com, 'kx', 'MarkerSize', 14, 'LineWidth', 3);
    set(gca, 'LineWidth', 1.2, 'FontSize', 11, 'FontWeight', 'bold');
    xlabel('Cortical X Position (px)'); ylabel('Cortical Y Position (px)');
    title(sprintf('3. Surgical Map (Smoothed Alpha = %.1f)', anisotropy_weight));
end