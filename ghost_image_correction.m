% Load the image
image_file = '/Users/jonathanfisher/Downloads/040425_preFUS.png';
original_image = imread(image_file);

% Convert to grayscale if needed
if size(original_image, 3) == 3
    original_image = rgb2gray(original_image);
end

original_image = medfilt2(original_image, [5,5]); % median filter

% Get the dimensions of the original image
[rows, cols] = size(original_image);

% Create a black image of the same size
psf = zeros(rows, cols);

% Define the positions of the white pixels
center_row = round(rows / 2);
center_col = round(cols / 2);
offset = 124; % Displacement to the left

% Create a point spread function (PSF) that consists of a central white pixel and an offset near-white
psf(center_row, center_col) = 1;               % Center pixel
psf(center_row, center_col - offset) = 1;  % Pixel to the left (reduced intensity)

% Normalize the PSF
psf = psf / sum(psf(:));

% Apply Gaussian filter for noise reduction in the original image
sigma = 0.75; % Adjust sigma for the amount of smoothing
smoothed_image = imgaussfilt(double(original_image) / 255, sigma);

% Perform deconvolution using the generated PSF
deblurred_image = deconvwnr(smoothed_image, psf, 0.005);  % Reduced noise power

% Threshold the deblurred image to remove negative values and low intensities
threshold = 0.05; % Adjust as needed
deblurred_image(deblurred_image < threshold) = 0;

% Display the original and deconvolved images
figure;
subplot(1, 2, 1);
imshow(original_image);
title('Original Image');
subplot(1, 2, 2);
imshow(deblurred_image);
title('Deconvolved Image');
