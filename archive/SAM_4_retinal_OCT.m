% First attempt tpo use SAM for OCT retinal scans

% PARAMETERS
plotoption = 1;
Mean_profile_threshold = 10;


[fileName,filePath]  = uigetfile('*.bmp','Load OCT scan');
I = rgb2gray(imread([filePath fileName])); % this is a 9mm scan 
% and crop it to a central 6mm scan
[~, sx] = size(I);
Margin = (sx*(1-6/9))/2;
I = I(:,Margin + 1: sx-Margin);
I = double(I);



% Cropping the image
Mean_profile = mean(I,2);
ind = find(Mean_profile > Mean_profile_threshold);
I_crop_org = I(ind(1):end,:);
I_crop = medfilt2(I_crop_org,[11 11]);
[sy,sx] = size(I_crop);
MODEL = segmentAnythingModel;
embeddings_org = extractEmbeddings(MODEL,I_crop_org);
embeddings_medfilt = extractEmbeddings(MODEL,I_crop);

%% Create ILM Mask

Mask_ILM = ~segmentObjectsFromEmbeddings(MODEL, embeddings_medfilt, [sy, sx], ...
    "ForegroundPoints",[821 22]);
Mask_ILM = imopen(Mask_ILM,strel('disk',25));
Layer_ILM = zeros(sx,1);
for ii = 1 : sx
    col_top = Mask_ILM(:,ii);
    ind  = find(col_top==1);
    Layer_ILM(ii) = ind(1);
end

if plotoption
    h1 = figure;imagesc(I_crop_org);colormap gray
    hold on;
    plot(1:sx, Layer_ILM,'r.')
end

% Another idea is to find the hole (if exists) and then select peripheral
% points for RPE away from that hole.

Mask_ILM_NaN = double(Mask_ILM);
ind = find(Mask_ILM == 0);
Mask_ILM_NaN(ind) = NaN;

I_heq = adapthisteq(uint8(I_crop_org));
Bw = im2bw(I_heq,100/255);  % im2bw  vs imbinarize
Bw1 = imbinarize(I_heq);
Bw2 = imclose(Bw,strel('disk',8));

figure; imagesc(Bw1); colormap gray;



%Consider finding the RPE by taking the averege (by rows) and find the
%location of the second peak (realted to the highly visible RPE layer).
%Then use that information for selecting two peripheral (non-central) x
%values (they may be arbitrary).


% Should close some of the holes but not the target hole
Bw_closed = imclose(Bw1, strel('disk', 6));

% Invert to make the retina black (0) and the rest white so that the
% regionprops can detect it
Bw_holes = ~Bw_closed; 

% But then make the background part black (0) again so that it wont be
% detected
for x = 1:sx
    y_ilm = Layer_ILM(x);
    if y_ilm > 0
        safe_y = min(y_ilm + 10, sy); 
        Bw_holes(1:safe_y, x) = 0; 
    end
end

figure; imagesc(Bw_holes); colormap gray;

% Regionprops measures all the different shapes
stats = regionprops(Bw_holes, 'Area', 'Centroid', 'BoundingBox');

% Find the biggest hole from the list
[~, max_idx] = max([stats.Area]);
target_hole = stats(max_idx);
    

hole_centroid = target_hole.Centroid; % Gives [X, Y] center point
    
figure(h1);
plot(hole_centroid(1), hole_centroid(2), 'r*', 'MarkerSize', 10);                                                                                                                                                                                                                                   

%% Create mask for the hole

Mask_Hole = segmentObjectsFromEmbeddings(MODEL, embeddings_org, [sy, sx], ...
    "ForegroundPoints",[hole_centroid(1) hole_centroid(2)]);

figure; imagesc(Mask_Hole); colormap gray;


posterior_hole = nan(sx,1);
for ii = 1 : sx
    col_top = Mask_Hole(:,ii);
    ind  = find(col_top==1);
    if ~isempty(ind)
        posterior_hole(ii) = ind(end);
    end
end
[MaxPH,indMaxPH] = max(posterior_hole);


%% Create mask for the top of the rpe

% for small hole dont add background points
Mask_RPE_top = segmentObjectsFromEmbeddings(MODEL, embeddings_org, [sy, sx], ...
    "ForegroundPoints",[indMaxPH MaxPH + 5]);


% for small hole use 5
% for big hole use 25
Mask_RPE_top = imopen(Mask_RPE_top,strel('disk',5));


%Layer_RPE_top = zeros(sx,1);
% = zeros(sx,1);

Layer_RPE_top = nan(sx,1); 
for ii = 1 : sx
    col_top = Mask_RPE_top(:,ii);
    ind_top  = find(col_top==1);
    if ~isempty(ind_top)
        Layer_RPE_top(ii) = ind_top(1);
    end
end

% These are anchor points for the model

% find all X-coordinates where the top layer is not NaN
valid_x = find(~isnan(Layer_RPE_top));

% define valid right side points
safe_idx = max(1, round(length(valid_x) * 0.75)); % max is just to make sure it wont be less than zero
safe_x = valid_x(safe_idx);
y_rpe_top = round(Layer_RPE_top(safe_x));

% define middle point from hole's center 
mid_idx = round(length(valid_x) * 0.50);
mid_x = valid_x(mid_idx);
y_rpe_mid = round(Layer_RPE_top(mid_x));

%% Create mask for bottom part of rpe

% for small hole use "ForegroundPoints", [safe_x, y_rpe_top + 40;     
                     %mid_x, y_rpe_mid + 40], ... 
                     %"BackgroundPoints", [safe_x, y_rpe_top + 10;      
                     %mid_x, y_rpe_mid + 10]);

% for big hole use "ForegroundPoints", [safe_x, y_rpe_top + 50;     
                     %mid_x, y_rpe_mid + 50], ... 
                     %"BackgroundPoints", [safe_x, y_rpe_top + 2;      
                     %mid_x, y_rpe_mid + 2]);


Mask_RPE_bot = segmentObjectsFromEmbeddings(MODEL, embeddings_org, [sy, sx], ...
    "ForegroundPoints", [safe_x, y_rpe_top + 40;     
                         mid_x, y_rpe_mid + 40], ... 
    "BackgroundPoints", [safe_x, y_rpe_top + 10;      
                         mid_x, y_rpe_mid + 10]);

Mask_RPE_bot = imopen(Mask_RPE_bot,strel('disk',20));

Layer_RPE_bot = nan(sx,1);

for ii = 1 : sx
    col_bot = Mask_RPE_bot(:,ii);
    ind_bot  = find(col_bot==1);
    if ~isempty(ind_bot)
        Layer_RPE_bot(ii) = ind_bot(1);
    end
end

figure(h1);
plot(1:sx,Layer_RPE_top,'c.')
plot(1:sx,Layer_RPE_bot,'m.')

figure; imagesc(Mask_RPE_top); colormap gray;
figure; imagesc(Mask_RPE_bot); colormap gray;

Mask_RPE_only = Mask_RPE_top & ~Mask_RPE_bot;

figure; imagesc(Mask_RPE_only); colormap gray;


%% Get the different peaks in that rpe mask layer

figure(h1);

for x = 1:sx
    % it is rounded because it needs whole numbers. cant use fractions
    y_top = round(Layer_RPE_top(x));
    y_bot = round(Layer_RPE_bot(x));
    
    if ~isnan(y_top) && ~isnan(y_bot) && (y_bot - y_top >= 2) && y_top >= 1 && y_bot <= sy
        
        % extract the 1D intensity profile for just this masked segment
        profile = double(I_crop(y_top:y_bot, x)); 
        
        % smoothing filter
        profile_smooth = smoothdata(profile, 'gaussian', 3); 
        
        % find local peaks and MinPeakProminence helps ignore tiny noise
        % bumps. it stores value in small extracted slice
        [peaks, local_locs] = findpeaks(profile_smooth, 'MinPeakProminence', 4); 
        
        % convert the local Y-coordinates back to the global image
        % Y-coordinates because the local locs are relative to small slice
        % so we need to convert to make it true to the real image size
        global_peak_y = y_top + local_locs - 1;
        
        plot(x * ones(size(global_peak_y)), global_peak_y, 'g.', 'MarkerSize', 4);
    end
end



% 
% Threshold = 50; % empirically chosen
% I_thresholded = nan(sy,sx);
% ind = I > Threshold;
% I_thresholded(ind) = I(ind);

%MASKS = segmentObjectsFromEmbeddings(MODEL, embeddings, [sy, sx], ...
%    "ForegroundPoints",[762 745]);


%%%%%%%%%%%%%%%%%%%
% [masks,scores] = imsegsam(I);
% ind = masks.PixelIdxList{1};
% M1 = zeros(size(I));M1(ind)=1;
% figure;imagesc(M1);colormap gray