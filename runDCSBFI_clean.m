function results = runDCSBFI_clean(dataDir, dataFile, outputFile)
%RUNDCSBFI_CLEAN Fit DCS autocorrelation data and return blood-flow index.
%
% results = runDCSBFI_clean(dataDir, dataFile, outputFile)
%
% dataFile is a filename prefix. The function reads matching .dcs files,
% averages detector channels at each source-detector separation, estimates
% baseline beta, and fits BFI for every acquisition frame.

if nargin < 1 || isempty(dataDir)
    dataDir = pwd;
end
if nargin < 2 || isempty(dataFile)
    dataFile = '091626_0916_1323_';
end
if nargin < 3
    outputFile = '';
end

if exist('seminfdcsfit', 'file') ~= 2
    error(['Missing dependency: seminfdcsfit.m. ' ...
        'Add the DCS model function to the MATLAB path before running.']);
end

files = dir(fullfile(dataDir, [dataFile '*.dcs']));
if isempty(files)
    error('No .dcs files found in %s with prefix %s.', dataDir, dataFile);
end
for fileIndex = 1:numel(files)
    files(fileIndex).name = fullfile(files(fileIndex).folder, files(fileIndex).name);
end

[frameIndex, timeAxis, delayTimes, marks, g2Data, intensities] = ...
    readDCSdata_clean(files);

markIndex = find(marks(:)).';
if numel(markIndex) < 2
    error('At least two nonzero marks are required to define the baseline.');
end
baselineFrames = markIndex(1):markIndex(2);
if isempty(baselineFrames)
    error('The first two marks do not define a valid baseline interval.');
end

fdet(1).values = [2.5 1];
fdet(2).values = [2.5 2:8];
[microBfi, g2data, g2fit, beta, rho, intdcs] = ...
    fastdcs1layer_clean(fdet, g2Data, intensities, delayTimes, ...
    0.1, 10, baselineFrames);

bfi = microBfi * 1e9;
bfiRelative = bfi ./ mean(bfi(baselineFrames, :), 1, 'omitnan');

results = struct();
results.frameIndex = frameIndex;
results.timeAxis = timeAxis;
results.delayTimes = delayTimes;
results.marks = marks;
results.baselineFrames = baselineFrames;
results.bfi = bfi;
results.bfiRelative = bfiRelative;
results.g2Data = g2data;
results.g2Fit = g2fit;
results.beta = beta;
results.rho = rho;
results.intensity = intdcs;
results.sourceFiles = {files.name};

if ~isempty(outputFile)
    save(outputFile, 'results');
end
end

function [frameIndex, timeAxis, delayTimes, marks, g2Data, intensities] = ...
    readDCSdata_clean(files)

allData = [];
for fileIndex = 1:numel(files)
    fileId = fopen(files(fileIndex).name, 'r');
    if fileId < 0
        error('Could not open DCS file: %s', files(fileIndex).name);
    end
    fileData = fread(fileId, Inf, 'double', 0, 'b');
    fclose(fileId);
    allData = [allData; fileData]; %#ok<AGROW>
end

if mod(numel(allData), 9 * 43) ~= 0
    error('DCS data size is not divisible by the expected 9-by-43 frame format.');
end

dcsData = reshape(allData, 9, 43, []);
frameIndex = squeeze(dcsData(1, 1, 2:end));
timeAxis = squeeze(dcsData(1, 2, 2:end));
delayTimes = squeeze(dcsData(1, 3:end-1, 1));
marks = squeeze(dcsData(1, end, 2:end));

g2Data = squeeze(dcsData(2:end, 3:end-1, 2:end));
intensities = squeeze(dcsData(2:end, end, 2:end));
end

function [bfi, g2data, g2fit, beta, rho, intdcs] = ...
    fastdcs1layer_clean(fdet, g2Data, intensities, delayTimes, mua, mus, baselineFrames)

if isscalar(mua)
    mua = repmat(mua, 1, size(g2Data, 3));
end
if isscalar(mus)
    mus = repmat(mus, 1, size(g2Data, 3));
end

n = 1.4;
reff = 0;
lambda = 785;
cutoff = 1.05;
numFrames = size(g2Data, 3);
numSeparations = numel(fdet);

bfi = zeros(numFrames, numSeparations);
beta = zeros(numFrames, numSeparations);
rho = zeros(1, numSeparations);
intdcs = zeros(numFrames, numSeparations);
g2data = cell(1, numSeparations);
g2fit = cell(1, numSeparations);

for separationIndex = 1:numSeparations
    detectorChannels = fdet(separationIndex).values(2:end);
    rho(separationIndex) = fdet(separationIndex).values(1);
    g2data{separationIndex} = squeeze(mean(...
        g2Data(detectorChannels, :, :), 1)).';
    intdcs(:, separationIndex) = mean(...
        intensities(detectorChannels, :), 1).';

    baselineG2 = mean(g2data{separationIndex}(baselineFrames, :), 1);
    baselineMua = mean(mua(baselineFrames));
    baselineMus = mean(mus(baselineFrames));
    [~, baselineBeta, ~] = seminfdcsfit(...
        baselineG2, delayTimes, rho(separationIndex), baselineMua, ...
        baselineMus, n, reff, lambda, cutoff);

    [bfi(:, separationIndex), beta(:, separationIndex), fittedG2] = ...
        seminfdcsfit(g2data{separationIndex}, delayTimes, ...
        rho(separationIndex), mua, mus, n, reff, lambda, cutoff, [], baselineBeta);

    g2fit{separationIndex} = fittedG2;
end
end
