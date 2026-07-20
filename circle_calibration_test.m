%% SPATIAL RING VISUAL VALIDATOR
% -------------------------------------------------------------------------
% Overlays physical distance rings (in um) onto a selected background image
% to visually verify the micron-to-pixel conversion factor.
% -------------------------------------------------------------------------

% 1. Configuration
% Choose an image already in your workspace (e.g., your PC1 mask)
bg_image = PC1_H1_norm_upscaled; 

% Conversion factor (pixels per micron) used in your main script
um_to_px = 0.3082; 

% Radii to test (in microns) - Added 1500 to test the outer limit
radii_um = [250, 500, 750, 1000, 1250, 1500];

% 2. Setup Plot
figRing = figure(820); clf;
set(figRing, 'Color', 'w', 'Position', [100 100 850 850]);

% Display the background image
imagesc(bg_image);
colormap(gca, 'parula'); % Using parula so the colored rings pop
axis image; hold on;
title(sprintf('Spatial Ring Validator (1 \\mum = %.4f pixels)', um_to_px), 'FontSize', 16, 'FontWeight', 'bold');

% Determine the center of the image
img_size = size(bg_image);
center_x = img_size(2) / 2;
center_y = img_size(1) / 2;

% Plot the target center
plot(center_x, center_y, 'wx', 'MarkerSize', 12, 'LineWidth', 3);
plot(center_x, center_y, 'kx', 'MarkerSize', 12, 'LineWidth', 1);

% 3. Draw the Concentric Rings
colors = lines(length(radii_um)); % Distinct colors for each ring
theta = linspace(0, 2*pi, 200);

for i = 1:length(radii_um)
    % Convert the physical radius to pixel radius
    r_px = radii_um(i) * um_to_px;
    
    % Calculate circle coordinates
    x_circle = center_x + r_px * cos(theta);
    y_circle = center_y + r_px * sin(theta);
    
    % Plot the circular ring
    plot(x_circle, y_circle, '-', 'Color', colors(i,:), 'LineWidth', 2.5);
    
    % Add a text label right at the top of each ring
    text(center_x, center_y - r_px - 10, sprintf('%d \\mum', radii_um(i)), ...
        'Color', colors(i,:), 'FontSize', 14, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
end

% 4. Add a Scale Bar for sanity check (500 um)
scale_bar_um = 500;
scale_bar_px = scale_bar_um * um_to_px;
x_start = 50; 
y_start = img_size(1) - 50;

% Draw a thick scale bar in the bottom left
plot([x_start, x_start + scale_bar_px], [y_start, y_start], '-w', 'LineWidth', 6);
plot([x_start, x_start + scale_bar_px], [y_start, y_start], '-k', 'LineWidth', 3);
text(x_start + scale_bar_px/2, y_start - 15, sprintf('%d \\mum', scale_bar_um), ...
    'Color', 'w', 'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');

axis off;