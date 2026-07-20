% User-specified dataset (e.g., 'DT1', 'DT2', etc.)
DT = 'DT1'; % Change this to DT1, DT2, etc.

% Construct variable names dynamically
var_10kHz = sprintf('PC1_%s_10kHz_norm_upscaled', DT);
var_30kHz = sprintf('PC1_%s_30kHz_norm_upscaled', DT);

% Load the data dynamically
PC1_10kHz = eval(var_10kHz);
PC1_30kHz = eval(var_30kHz);

% Define threshold for top 40% response
threshold = 0.9;

% Create binary masks
mask_10kHz = PC1_10kHz > threshold;
mask_30kHz = PC1_30kHz > threshold;

% Unique areas
unique_10kHz = mask_10kHz & ~mask_30kHz;  % 10kHz only
unique_30kHz = mask_30kHz & ~mask_10kHz;  % 30kHz only

% Generate a grayscale background (e.g., max projection)
background = max(PC1_10kHz, PC1_30kHz);

% Create solid color layers for overlays
blueLayer = cat(3, zeros(size(mask_10kHz)), zeros(size(mask_10kHz)), mask_10kHz); % Blue for 10kHz
redLayer = cat(3, mask_30kHz, zeros(size(mask_10kHz)), zeros(size(mask_10kHz))); % Red for 30kHz

% Set transparency levels (1 = fully opaque, 0 = fully transparent)
alpha_10kHz = 0.5 * mask_10kHz; % Semi-transparent blue
alpha_30kHz = 0.5 * mask_30kHz; % Semi-transparent red

% Plot the results
figure;

% Subplot 1: Overlapping responses with transparency
subplot(1,3,1);
imshow(background, []); % Show background first
hold on;
h1 = imshow(blueLayer); % 10kHz in blue
set(h1, 'AlphaData', alpha_10kHz); % Apply transparency

h2 = imshow(redLayer); % 30kHz in red
set(h2, 'AlphaData', alpha_30kHz); % Apply transparency

title(sprintf('%s Overlap: 10 kHz (Blue), 30 kHz (Red)', DT));
hold off;
axis off; % Remove axis

% Subplot 2: Unique 10 kHz response
subplot(1,3,2);
imshow(unique_10kHz);
colormap(gca, gray);
title(sprintf('%s Unique 10 kHz Response', DT));
axis off; % Remove axis

% Subplot 3: Unique 30 kHz response
subplot(1,3,3);
imshow(unique_30kHz);
colormap(gca, gray);
title(sprintf('%s Unique 30 kHz Response', DT));
axis off; % Remove axis

% Title for the whole figure
sgtitle(sprintf('Overlapping dual tone areas for DT1'));