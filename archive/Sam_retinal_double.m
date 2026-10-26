% Load the image

[fileName, filePath] = uigetfile('*.bmp','Load OCT scans');
I = rgb2gray(imread([filePath fileName]));

% Convert to raw double (Values remain 0-255, but type is double)
I = double(I); 

MODEL = segmentAnythingModel;

%% Extract Embeddings

% Passing the raw double to the model
embeddings = extractEmbeddings(MODEL, I);

%% Prepare image for display

f = figure;
hAX = axes(f);

hIm = imagesc(I); 
colormap gray; 
axis image; 
hold on;

%% Get the ROI

roi = drawrectangle(hAX);

%% Segmentation

mask = segmentObjectsFromEmbeddings(MODEL, embeddings, size(I), BoundingBox=roi.Position);

%% Plot the Segmentation

imgOverlay = labeloverlay(gather(I), mask); % makes it uint

hIm.CData = imgOverlay;