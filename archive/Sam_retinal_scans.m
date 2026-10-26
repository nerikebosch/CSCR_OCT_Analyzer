% Load the image

[fileName, filePath] = uigetfile('*.bmp','Load OCT scans');
I = rgb2gray(imread([filePath fileName]));

MODEL = segmentAnythingModel;

%% Extract embeddings

% Use GPU if available to decrease computation time
if (canUseGPU)
    I_proc = gpuArray(I);
else
    I_proc = I;
end

embeddings = extractEmbeddings(MODEL, I_proc);

%% Prepare image for display

f = figure;
hAX = axes(f);

hIm = imagesc(I); 
colormap gray; 
axis image; 
hold on;

% Get the ROI

roi = drawrectangle(hAX);

% Initial Segmentation

mask = segmentObjectsFromEmbeddings(MODEL, embeddings, size(I), BoundingBox=roi.Position);

% Display the result
imgOverlay = insertObjectMask(gather(I), mask);
hIm.CData = imgOverlay;