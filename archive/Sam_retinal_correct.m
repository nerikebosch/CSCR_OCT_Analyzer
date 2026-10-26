% Use Sam for retinal scans

[fileName, filePath] = uigetfile('*.bmp','Load OCT scans'); % load bitmap files

I = rgb2gray(imread([filePath fileName])); % use grey scale image to 2D

I = double(I);
 
[sy,sx] = size(I); % images not always same size vertically because of how the light propogates

MODEL = segmentAnythingModel;

embeddings = extractEmbeddings(MODEL, I);

MASKS = segmentObjectsFromEmbeddings(MODEL, embeddings, [sy,sx], "ForegroundPoints", [762 745]);

Mask_ILM= ~segmentObjectsFromEmbeddings(MODEL, embeddings, [sy,sx], "ForegroundPoints", [1 1]);

Layer_ILM = zeros(sx,1);

for ii = 1 : sx
    col = Mask_ILM(:,ii);
    ind = find(col==1);
    Layer_ILM(ii) = ind(1);
end


Threshold = 10; % empirically chosen
I_thresholded = nan(sy,sx);
ind = I > Threshold;
I_thresholded(ind) = I(ind);

figure; 

% {} brackets to make it double not cell array
% imgsegsam ... 
% ind = masks.Pixel...
% figure...
% mi = zeros(size(I)); Mi(ind) = 1
% plot
% I_crop = imcrop
% I_crop_smooth = medfilt2(I-crop, [11 1]); can play around with numbers -
% vertically [11 11] both horizontal and vertical - but not good anymore 
% .* I




