% Use SAM for retinal scans
[fileName, filePath] = uigetfile('*.bmp', 'Load OCT scans'); % Load bitmap files
if isequal(fileName,0)
    disp('User canceled file selection.');
    return;
end

% Read the image and convert (using fullfile is safer for file paths)
I = rgb2gray(imread(fullfile(filePath, fileName))); % Use grayscale image to 2D
I = double(I);

[sy, sx] = size(I); % Images not always same size vertically because of how the light propagates

% --- SAM Setup and Execution ---
MODEL = segmentAnythingModel;
embeddings = extractEmbeddings(MODEL, I);
MASKS = segmentObjectsFromEmbeddings(MODEL, embeddings, [sy,sx], "ForegroundPoints", [762 745]);

% --- Translated Comment Section ---

% figure; im
figure; 
imshow(I, []); % Using [] because I is a double; this scales it correctly for display
title('Original Image');

% {} brackets to make it double not cell array
% segmentObjectsFromEmbeddings returns a cell array, so we extract the first mask
mask_matrix = double(MASKS{1}); 

% ind = masks.Pixel...
% Find the linear indices where the mask is equal to 1 (the segmented object)
ind = find(mask_matrix == 1); 

% mi = zeros(size(I)); Mi(ind) = 1
mi = zeros(size(I)); 
mi(ind) = 1; 

% .* I
% Multiply the mask by the original image to isolate the segmented region
imgsegsam = I .* mi; 

% figure... plot
figure; 
imshow(imgsegsam, []); 
title('Segmented Image - Draw a rectangle to crop');

% I_crop = imcrop
% This will pause the script and wait for you to draw a crop box on the figure
I_crop = imcrop; 

% I_crop_smooth = medfilt2(I-crop, [11 1]);
% Apply the median filter to smooth vertically as requested
I_crop_smooth = medfilt2(I_crop, [11 1]); 

% Final plot to show the result of the smoothing
figure;
imshow(I_crop_smooth, []);
title('Cropped & Smoothed Image');