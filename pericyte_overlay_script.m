% % ----- Inputs -----
% gray = I(:,:,55);       % Grayscale frame
% overlay = dII(:,:,55);  % ΔI/I frame
% 
% threshold = 0.03;        % ΔI/I threshold
% 
% % Normalize grayscale for display (0–1)
% gray = mat2gray(gray);
% 
% % Normalize ΔI/I for color mapping
% maxResp = prctile(overlay(:), 99);
% minResp = prctile(overlay(:), 1);
% overlayNorm = max(min((overlay - minResp) / (maxResp - minResp), 1), 0);
% 
% % Apply threshold mask
% mask = overlay > threshold;
% 
% % Convert to colormap-based RGB
% ind = gray2ind(overlayNorm, 256);
% cmap = jet(256);
% colorRGB = ind2rgb(ind, cmap);
% 
% % Blend overlay with grayscale under mask
% alpha = 0.7;
% rgb = repmat(gray, [1, 1, 3]);  % Start with grayscale as RGB
% 
% for c = 1:3
%     rgb(:,:,c) = rgb(:,:,c) .* (~mask) + ...
%                  (1 - alpha) * rgb(:,:,c) .* mask + ...
%                  alpha * colorRGB(:,:,c) .* mask;
% end
% 
% % ----- Display -----
% figure;
% imshow(rgb);
% title('ΔI/I overlay on grayscale (Frame 55)');


% ----- Inputs -----
grayStack = I;  % Your grayscale image stack, size: H x W x T
colorOverlay = dII;   % Your ΔI/I stack, same size

threshold = .5;      % ΔI/I threshold (e.g., 5%)

% Normalize grayscale for display (0–1)
grayStack = mat2gray(grayStack);

% Normalize dI/I for color mapping
maxResp = prctile(colorOverlay(:), 99);  % Robust max for colormap scaling
minResp = prctile(colorOverlay(:), 1);
colorOverlay = max(min((colorOverlay - minResp) / (maxResp - minResp), 1), 0);

% Colormap setup
cmap = jet(256);

% Preallocate RGB stack
[H, W, T] = size(grayStack);
montageRGB = zeros(H, W, 3, T);

for t = 1:T
    gray = grayStack(:, :, t);
    overlay = colorOverlay(:, :, t);

    % Apply threshold
    mask = overlay > threshold;

    % Convert overlay to indexed image for colormap
    ind = gray2ind(overlay, 256);  % scale 0–255
    colorFrame = ind2rgb(ind, cmap);

    % Blend overlay with grayscale using mask
    rgb = repmat(gray, [1, 1, 3]);  % grayscale base
    alpha = 0.7;  % blending factor

    for c = 1:3
        rgb(:, :, c) = rgb(:, :, c) .* (~mask) + ...
                       (1 - alpha) * rgb(:, :, c) .* mask + ...
                       alpha * colorFrame(:, :, c) .* mask;
    end

    montageRGB(:, :, :, t) = rgb;
end

% ----- Display as montage -----
montage(montageRGB, 'Size', [ceil(sqrt(T)), ceil(sqrt(T))]);
title('ΔI/I overlay on grayscale');
