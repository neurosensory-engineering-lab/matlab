% '/Users/jonathanfisher/Dropbox/Academic/Papers/Hehir2023/Data transfer/Mouse371_022123 Jake/pre_10kHz_set_1'

function av_dFF_combined = group_process_zylavideos(basename, num_files, numpix_y, numpix_x, baselineframes, smoothradius)

    av_dFF_combined = []; % Initialize the combined dF/F matrix

    for i = 1:num_files
        % Construct the filename
        filename = [basename int2str(i) '.tif'];
        disp(['Processing: ' filename]);
        
        % Read the TIFF stack
        info = imfinfo(filename);
        num_images = numel(info);
        frames = zeros(numpix_y, numpix_x, 1, num_images);

        % Load the TIFF images into a 4D matrix
        for j = 1:num_images
            frames(:, :, 1, j) = imread(filename, j);
        end

        % Smooth the frames
        sframes = zeros(size(frames));
        for k = 1:num_images
            sframes(:, :, 1, k) = imgaussfilt(frames(:, :, 1, k), smoothradius);
        end

        % Calculate the baseline average frame
        baseline = sum(sframes(:, :, 1, baselineframes), 4) / numel(baselineframes);

        % Compute dF/F
        dFF = zeros(size(frames));
        for m = 1:num_images
            dF = sframes(:, :, 1, m) - baseline;
            dFF(:, :, 1, m) = dF ./ baseline;
        end

        % Combine the current dF/F into the result matrix
        if isempty(av_dFF_combined)
            av_dFF_combined = dFF;
        else
            av_dFF_combined = cat(4, av_dFF_combined, dFF);
        end

        % Clear variables for memory efficiency
        clear frames sframes dFF;
    end

    % Display the resulting combined dF/F as a montage
    figure;
    montage(av_dFF_combined, 'DisplayRange', []);
    colormap(jet);
    colorbar;
    title('Combined dF/F');

end
