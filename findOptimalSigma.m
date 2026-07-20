function optimal_sigma = findOptimalSigma(PC1_image)
% ========================================================================
% Purpose: Mathematically identify the optimal structural blur sigma (sigma)
%          for a PC1 map by finding the "knee" of the gradient energy curve.
%          This identifies the precise point where high-frequency noise is
%          destroyed before macro-anatomical boundaries are distorted.
%
% Input:   PC1_image     - A 2D numerical matrix of your experimental data
%
% Output:  optimal_sigma - The empirical noise-floor sigma (scalar)
% ========================================================================

    % 1. Enforce double precision and normalize to standard 0-1 range
    real_map = double(PC1_image);
    real_map_norm = (real_map - min(real_map(:))) / (max(real_map(:)) - min(real_map(:)) + eps);

    % 2. Establish the search space sweep parameters
    sigma_sweep = 0:0.25:8; % Fine step resolution up to a massive 8-pixel blur
    gradient_energy = zeros(size(sigma_sweep));

    % 3. Compute derivative energy across the spatial low-pass filter sweep
    for i = 1:length(sigma_sweep)
        if sigma_sweep(i) == 0
            smoothed = real_map_norm;
        else
            smoothed = imgaussfilt(real_map_norm, sigma_sweep(i));
        end
        
        % Calculate spatial derivatives via Central Difference
        [Gx, Gy] = imgradientxy(smoothed, 'CentralDifference');
        Gmag = sqrt(Gx.^2 + Gy.^2);
        
        % Quantify high-frequency noise presence using gradient variance (energy)
        gradient_energy(i) = var(Gmag(:));
    end

    % 4. Normalize the energy profile to a standardized geometric scale (0 to 1)
    energy_norm = (gradient_energy - min(gradient_energy)) / (max(gradient_energy) - min(gradient_energy) + eps);

    % 5. Locate the geometric "Knee" Point (Maximum perpendicular distance to diagonal)
    n_pts = length(sigma_sweep);
    line_start = [sigma_sweep(1), energy_norm(1)];
    line_end   = [sigma_sweep(end), energy_norm(end)];
    line_vector = line_end - line_start;
    line_vector_norm = line_vector / norm(line_vector);
    
    distances = zeros(n_pts, 1);
    for i = 1:n_pts
        point = [sigma_sweep(i), energy_norm(i)];
        start_to_point = point - line_start;
        % Vector projection math to find true perpendicular height
        projection_length = dot(start_to_point, line_vector_norm);
        closest_point_on_line = line_start + projection_length * line_vector_norm;
        distances(i) = norm(point - closest_point_on_line);
    end
    
    [~, knee_idx] = max(distances);
    optimal_sigma = sigma_sweep(knee_idx);

    % 6. Render the Live Production Diagnostics Panel
    figDiag = figure('Name', 'Empirical Structural Sigma Optimizer', 'NumberTitle', 'off');
    set(figDiag, 'Color', 'w', 'Position', [300, 300, 650, 480]);
    
    plot(sigma_sweep, energy_norm, 'b-o', 'LineWidth', 2.5, 'MarkerSize', 5, 'MarkerFaceColor', 'b'); hold on;
    plot(optimal_sigma, energy_norm(knee_idx), 'ro', 'MarkerSize', 13, 'LineWidth', 3, 'MarkerFaceColor', 'r');
    
    % Draw the geometric reference chord line to visually demonstrate the knee logic
    plot([line_start(1), line_end(1)], [line_start(2), line_end(2)], 'k--', 'LineWidth', 1.2);
    
    grid on; set(gca, 'LineWidth', 1.2, 'FontSize', 11, 'FontWeight', 'bold');
    xlim([-0.2, max(sigma_sweep) + 0.2]); ylim([-0.05, 1.05]);
    xlabel('Structural Blur Sigma (\sigma_{pixels})');
    ylabel('Normalized Gradient Energy (Noise Static Floor)');
    title(sprintf('Anatomical Filter Profile (Optimal Knee \\sigma = %.2f px)', optimal_sigma));
    legend('Gradient Energy Profile', 'Empirical Noise Corner (\sigma)', 'Baseline Geometric Scale Chord', 'Location', 'best');
    
    fprintf('>> Empirical Sweep Complete. Noise corner located at Sigma: %.2f pixels.\n', optimal_sigma);
end