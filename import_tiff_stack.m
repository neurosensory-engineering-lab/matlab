% Specify the file path
filename = '/Users/jonathanfisher/Downloads/Stablized FUS-movie-sonication-atabout-8-sec-after-start(1).tif';  % Replace with your TIFF file path

% Get TIFF file info
info = imfinfo(filename);
numFrames = numel(info);

% Preallocate array based on image size and number of frames
imgStack = zeros(info(1).Height, info(1).Width, numFrames, 'like', imread(filename, 1));

% Read each frame
for k = 1:numFrames
    imgStack(:, :, k) = imread(filename, k);
end

