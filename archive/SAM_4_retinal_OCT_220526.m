%% First attempt to use SAM for OCT retinal scans

MODEL = segmentAnythingModel;

% PARAMETERS
plotoption = 1;
Mean_profile_threshold = 10;


[fileName,filePath]  = uigetfile('*.bmp','Load OCT scan');
I = rgb2gray(imread([filePath fileName])); % this is a 9mm scan 
% and crop it to a central 6mm scan
[sy, sx] = size(I);
Margin = (sx*(1-6/9))/2;
I = I(:,Margin + 1: sx-Margin);
% crop further bofore SAM
T = multithresh(I, 3);
Labels = imquantize(I, T);
BW = zeros(size(I));
ind  = Labels==3 | Labels==4;
BW(ind) = 1;
BW = imopen(imfill(BW,'holes'),strel('disk',3)); % disk size may influence the results
[~,Y] = meshgrid(1:sx,1:sy);
Y_min = min(Y(BW==1));
Y_max = max(Y(BW==1));
I_crop = I(Y_min-10:Y_max,:);
I_crop = double(I_crop);
[sy,sx] = size(I_crop);
embeddings_org = extractEmbeddings(MODEL,I_crop);



%% Create ILM Mask (Red Line)
Mask_ILM = ~segmentObjectsFromEmbeddings(MODEL, embeddings_org, [sy, sx], ...
    "ForegroundPoints",[[1;sx],[1;1]]); % gets point in the two corners at the top
% Initial foreground was [821 22]


[X,Y] = meshgrid(1:sx,1:sy);
Layer_ILM = zeros(sx,1);
for ii = 1 : sx
    Layer_ILM(ii) = min(Y(Mask_ILM(:,ii)==1,ii));
end

% Rotate image if it at an angle
valid_cols = find(~isnan(Layer_ILM));
valid_y = Layer_ILM(valid_cols);
p = polyfit(valid_cols, valid_y, 1);
tilt_angle = atand(p(1));

% Keep original image
I_original_crop = I_crop;
I_crop = imrotate(I_crop, tilt_angle, 'bicubic', 'crop');

% filter to smooth the line
Layer_ILM = smoothdata(Layer_ILM, 'sgolay', 45);

if plotoption
    h1 = figure;imagesc(I_crop);colormap gray
    hold on;
    plot(1:sx, Layer_ILM,'r.')
end


%% Check if the hole exists, then create mask if there is

% consider multithreshold
NumTh = 3;
T1 = multithresh(uint8(I_crop),NumTh);
labels = imquantize(uint8(I_crop),T1);
Bw2 = zeros(sy,sx);
if NumTh == 2
    ind2 = labels == 2;
    ind3 = labels == 3;
    indCom = or(ind2,ind3);
    Bw2(indCom) = 1;
else
    ind1 = labels == 2;
    ind2 = labels == 3;
    ind3 = labels == 4;
    indCom = or(ind2,ind3);
    Bw2(ind1) = 0;
    Bw2(indCom) = 1;
end

% labelsRGB = label2rgb(labels);
h2 = figure;imagesc(labels); 
title("Labels of the image")

% the imclose was added to make sure there are no leakages to the hole.
% because otherwise it would create the BW2L with the hole attached and
% then when you create Bw3 it would be gone.
Bw2 = imclose(Bw2, strel('disk', 1));
BW2filled = imfill(Bw2,'holes');

% create a U-masks
UmaskL = zeros(size(I_crop));
UmaskL(:,[1 end]) = 1;
UmaskL(end,:) = 1;
UmaskU = zeros(size(I_crop));
UmaskU(:,[1 end]) = 1;
UmaskU(1,:) = 1;
BW2L = ~imfill(or(BW2filled,UmaskL),'holes');
BW2U = ~imfill(or(BW2filled,UmaskU),'holes');
BW2LU = or(BW2L,BW2U);
Bw3 = ~or(Bw2,BW2LU);
% clean the Umasks
Bw3(1,:) = 0;
Bw3(end,:) = 0;
Bw3(:,1) = 0;
Bw3(:,end) = 0;


h3 = figure;imagesc(Bw3);colormap gray;
title("After creating Umasks and using imfil")

% clean the areas around the hole(made it bigger)
Bw3 = imopen(Bw3, strel('disk', 3));

% check whether the potential hole is on the sides of the picture
left_margin = round(sx * 0.35);
right_margin = round(sx * 0.25);
Bw3(:, 1:left_margin) = 0; 
Bw3(:, end-right_margin:end) = 0;


%Bw3 = bwareafilt(Bw3, 1); % gets only the largest object
h4 = figure;imagesc(Bw3);colormap gray;
title("Image after using imopen to get only one area")


% check whether there is a hole in any shape and checking their parameters
stats = regionprops(logical(Bw3), 'Area', 'Centroid', 'BoundingBox', 'PixelIdxList', 'Solidity');

is_hole_found = false;
target_hole_idx = [];
max_area = 0;

for k = 1:length(stats)
    % Check size limits. can play around with the number to see what works
    % best
    if stats(k).Area > 500
        

        % Check intensity
        pixel_indices = stats(k).PixelIdxList;
        label1_count = sum(labels(pixel_indices) == 1); % Count darkest pixels
        dark_ratio = label1_count / stats(k).Area;
        
        % Check the shape
        bbox = stats(k).BoundingBox; 
        width = bbox(3);
        height = bbox(4);
        %is_not_wide = (width / height) < 5.0;
        is_not_thin  = (height / width) < 4.0;

        is_solid = stats(k).Solidity > 0.30;
        
        % Check all the criterias and then gets the largest ones location
        if dark_ratio > 0.15 && is_not_thin && is_solid
            if stats(k).Area > max_area
                max_area = stats(k).Area;
                target_hole_idx = k;
                is_hole_found = true;
            end
        end
    end
end

Mask_Hole = false(sy, sx);

if is_hole_found
    disp('Hole found')
    % assume there is a hole
    % Processing type II

    % Find the biggest hole from the list
    target_hole = stats(target_hole_idx);
        
    hole_centroid = target_hole.Centroid; % Gives [X, Y] center point
        
    figure(h1);
    plot(hole_centroid(1), hole_centroid(2), 'r*', 'MarkerSize', 10);

    % Create mask for the hole

    Mask_Hole = segmentObjectsFromEmbeddings(MODEL, embeddings_org, [sy, sx], ...
        "ForegroundPoints",[hole_centroid(1) hole_centroid(2)]); % Using points from what we got to get the center part above

    Mask_Hole = bwareafilt(Mask_Hole, 1);
    
    h5 = figure; imagesc(Mask_Hole); colormap gray;
    title("SAM image of the hole");

    % Find the lowest point of the hole
    posterior_hole = nan(sx,1);
    for ii = 1 : sx
        col_top = Mask_Hole(:,ii);
        ind  = find(col_top==1);
        if ~isempty(ind)
            posterior_hole(ii) = ind(end);
        end
    end
    [MaxPH,indMaxPH] = max(posterior_hole);

else
    disp('No hole')
    % assume there is no hole
    % Processing type I


    % try to get an x coordinate somewhere near the middle
    center_start = round(sx * 0.3);
    center_end = round(sx * 0.7);
    [ilm_max_y, local_ind] = max(Layer_ILM(center_start:center_end));
    indMaxPH = center_start + local_ind - 1; 
    
    % Go down near the RPE to get the top part of it
    search_start = min(sy - 10, round(ilm_max_y) + 30); 
    profile = double(I_crop(search_start:end, indMaxPH));
    
    % The brighest part will be where we think the rpe top layer starts
    [~, peak_idx] = max(profile);
    rpe_y = search_start + peak_idx - 1;
    
    % Add a coordinate above that point to use that as our area to start
    % the rpe masks
    MaxPH = max(1, rpe_y - 15);


end


%% Create mask for the top of the RPE (Cyan Line)


% Then crop the image just above this part and extract embeddings
crop_y_start = max(1, MaxPH - 70);

I_rpe_crop = double(I_crop(crop_y_start:sy, :));
[sy_rpe, sx_rpe] = size(I_rpe_crop);
h6 = figure; imagesc(I_rpe_crop); colormap gray;
title("New cropped image for the RPE embeddings");

embeddings_rpe = extractEmbeddings(MODEL, I_rpe_crop);


% Search for the brightest pixel in indMaxPH
local_hole_bottom = MaxPH - crop_y_start + 1;
search_profile = double(I_rpe_crop(local_hole_bottom:end, indMaxPH));
[~, local_max_idx] = max(search_profile);
rpe_offset_local = local_hole_bottom + local_max_idx - 1;
bg_hole_y = max(1, local_hole_bottom - 5);


Mask_RPE_crop = segmentObjectsFromEmbeddings(MODEL, embeddings_rpe, [sy_rpe, sx_rpe], ...
    "ForegroundPoints", [indMaxPH, rpe_offset_local], ...
    "BackgroundPoints", [indMaxPH, bg_hole_y]);

h7 = figure; imagesc(Mask_RPE_crop); colormap gray;
title("Mask of the RPE top");

% Create a blank mask the size of the original full image
Mask_RPE_top = false(sy, sx);
Mask_RPE_top(crop_y_start:sy, :) = Mask_RPE_crop;


% Create the line
Layer_RPE_top = nan(sx,1); 
for ii = 1 : sx
    col_top = Mask_RPE_top(:,ii);
    ind_top  = find(col_top==1);
    if ~isempty(ind_top)
        Layer_RPE_top(ii) = ind_top(1);
    end
end


% This just connects and smooths the lines
Layer_RPE_top = fillmissing(Layer_RPE_top, 'linear', 'EndValues', 'nearest');
Layer_RPE_top = smoothdata(Layer_RPE_top, 'sgolay', 45);

figure(h1);
plot(1:sx, Layer_RPE_top, 'c.');



%% Create mask for bottom part of rpe (Magenta Line)

% find all X-coordinates where the top layer is not NaN
valid_x = find(~isnan(Layer_RPE_top));

% define valid left side point
left_idx = max(1, round(length(valid_x) * 0.25));
left_x = valid_x(left_idx);
y_rpe_left = round(Layer_RPE_top(left_x));

% define valid right side point
right_idx = max(1, round(length(valid_x) * 0.75)); % max is just to make sure it wont be less than zero
right_x = valid_x(right_idx);
y_rpe_top = round(Layer_RPE_top(right_x));

% define valid middle point
mid_idx = round(length(valid_x) * 0.50);
mid_x = valid_x(mid_idx);
y_rpe_mid = round(Layer_RPE_top(mid_x));

% those were global coordinates so now we need to make it local for the
% cropped rpe image
y_rpe_left_local = y_rpe_left - crop_y_start + 1;
y_rpe_right_local = y_rpe_top - crop_y_start + 1;
y_rpe_mid_local = y_rpe_mid - crop_y_start + 1;

Mask_RPE_bot_crop = segmentObjectsFromEmbeddings(MODEL, embeddings_rpe, [sy_rpe, sx_rpe], ...
    "ForegroundPoints", [left_x,  min(sy_rpe, y_rpe_left_local + 40);     
                         mid_x,   min(sy_rpe, y_rpe_mid_local + 40);
                         right_x, min(sy_rpe, y_rpe_right_local + 40)], ... 
    "BackgroundPoints", [1,  max(1, y_rpe_left_local - 10);
                         left_x,  max(1, y_rpe_left_local + 5); 
                         mid_x - 150,   max(1, y_rpe_mid_local);
                         mid_x,   max(1, y_rpe_mid_local + 15);
                         mid_x + 150,   max(1, y_rpe_mid_local + 10);
                         right_x, max(1, y_rpe_right_local + 5);
                         sx_rpe, max(1, y_rpe_right_local - 25)]);

Mask_RPE_bot_crop = bwareafilt(logical(Mask_RPE_bot_crop), 1);
Mask_RPE_bot_crop = imclose(Mask_RPE_bot_crop,strel('disk',20));

h8 = figure; imagesc(Mask_RPE_bot_crop); colormap gray;
title("Mask of the RPE Bottom");

Mask_RPE_bot = false(sy, sx);
Mask_RPE_bot(crop_y_start:sy, :) = Mask_RPE_bot_crop;

% Get the line
Layer_RPE_bot = nan(sx,1);
for ii = 1 : sx
    col_bot = Mask_RPE_bot(:,ii);
    ind_bot  = find(col_bot==1);
    if ~isempty(ind_bot)
        Layer_RPE_bot(ii) = ind_bot(1);
    end
end

% Smooth the line
Layer_RPE_bot = fillmissing(Layer_RPE_bot, 'linear', 'EndValues', 'nearest');
Layer_RPE_bot = smoothdata(Layer_RPE_bot, 'sgolay', 45);

figure(h1);
plot(1:sx,Layer_RPE_bot,'m.')



Mask_RPE_only = Mask_RPE_top & ~Mask_RPE_bot;

h9 = figure; imagesc(Mask_RPE_only); colormap gray;
title("RPE Mask");


%% Get the different peaks in that rpe mask layer

figure(h1);

% 3 layers in the rpe mask
Layer_Green1 = nan(sx, 1);
Layer_Green2 = nan(sx, 1);
Layer_Green3 = nan(sx, 1);

for x = 1:sx
    % Start and end points for the search in RPE layer
    y_top = round(Layer_RPE_top(x));
    y_bot = round(Layer_RPE_bot(x));
    
    % Ensure we have a valid window of at least a few pixels
    if ~isnan(y_top) && ~isnan(y_bot) && (y_bot - y_top >= 4) && y_top >= 1 && y_bot <= sy
        
        % Extract bright vertical parts between the layers and smooth the intensity profile
        profile = double(I_crop(round(y_top):round(y_bot), x));
        profile_smooth = smoothdata(profile, 'gaussian', 3); 
        
        % Find local peaks. It looks for max brightness and only goes for
        % high peaks.
        [peaks, local_locs] = findpeaks(profile_smooth, 'MinPeakProminence', 3); 
        
        if ~isempty(local_locs)
            global_locs = y_top + local_locs - 1;
            
            % Divides the RPE in three layers. These are like a general
            % idea where they will be located between the RPE layer
            total_thick = y_bot - y_top;
            track1 = y_top + (total_thick * 0.25);
            track2 = y_top + (total_thick * 0.50);
            track3 = y_top + (total_thick * 0.75);
            
            % Assign each found peak to the anchor track it is physically closest to
            for k = 1:length(global_locs)
                p_loc = global_locs(k);
                
                % Calculate distance from this peak to the 3 anchors
                dists = abs([p_loc - track1, p_loc - track2, p_loc - track3]);
                [~, closest_track] = min(dists);
                
                % select the one it is closest to
                if closest_track == 1
                    Layer_Green1(x) = p_loc;
                elseif closest_track == 2
                    Layer_Green2(x) = p_loc;
                else
                    Layer_Green3(x) = p_loc;
                end
            end
        end
    end
end


% Connect and smooth each line
Layer_Green1 = smoothdata(fillmissing(medfilt1(Layer_Green1, 7, 'omitnan'), 'linear'), 'sgolay', 45);
Layer_Green2 = smoothdata(fillmissing(medfilt1(Layer_Green2, 7, 'omitnan'), 'linear'), 'sgolay', 45);
Layer_Green3 = smoothdata(fillmissing(medfilt1(Layer_Green3, 7, 'omitnan'), 'linear'), 'sgolay', 45);


for x = 1:sx
    y_top = Layer_RPE_top(x);
    y_bot = Layer_RPE_bot(x);
    
    % Only keep green lines if we have valid top and bottom boundaries
    if ~isnan(y_top) && ~isnan(y_bot)
        
        % keep them inside the RPE top and bottom layers
        if Layer_Green1(x) < y_top, Layer_Green1(x) = y_top + 1; end
        if Layer_Green1(x) > y_bot, Layer_Green1(x) = y_bot - 1; end
        
        if Layer_Green2(x) < y_top, Layer_Green2(x) = y_top + 1; end
        if Layer_Green2(x) > y_bot, Layer_Green2(x) = y_bot - 1; end
        
        if Layer_Green3(x) < y_top, Layer_Green3(x) = y_top + 1; end
        if Layer_Green3(x) > y_bot, Layer_Green3(x) = y_bot - 1; end
        
        
    else
        % If there is no top or bottom RPE boundary, delete the green lines too
        Layer_Green1(x) = NaN;
        Layer_Green2(x) = NaN;
        Layer_Green3(x) = NaN;
    end
end


% Plot the layers when there is at least a certain amount in the image

if sum(~isnan(Layer_Green1)) > (sx * 0.15)
    plot(1:sx, Layer_Green1, 'g-', 'LineWidth', 1.5);
end

if sum(~isnan(Layer_Green2)) > (sx * 0.15)
    plot(1:sx, Layer_Green2, 'g-', 'LineWidth', 1.5);
end

if sum(~isnan(Layer_Green3)) > (sx * 0.15)
    plot(1:sx, Layer_Green3, 'g-', 'LineWidth', 1.5);
end



%% Get Inner Retinal Layers (Blue Lines)


% define the area above the hole.
Layer_Inner_Bot = nan(sx, 1);

% This is to start where the yellow line should start above the rpe top line.
outer_ret_thick = 10; 

for x = 1:sx
    % define the top and bottom parts of where to get the layers
    y_top = round(Layer_ILM(x));
    y_cyan = round(Layer_RPE_top(x)); 
    
    if ~isnan(y_top) && ~isnan(y_cyan)
        % to get the yellow layer you go up from the top rpe layer
        floor_y = y_cyan - outer_ret_thick;
        
        % check if there is a hole in this area
        col_hole = Mask_Hole(:, x);
        ind_hole = find(col_hole == 1);
        
        if ~isempty(ind_hole)
            hole_top = ind_hole(1);
            % this is to make the yellow line go above the hole in the area
            % where there is a hole
            if hole_top < floor_y && hole_top > y_top
                floor_y = hole_top;
            end
        end
        
        % make sure it doesnt go above the ilm line
        if floor_y <= y_top
            floor_y = y_top + 10;
        end
        
        Layer_Inner_Bot(x) = floor_y;
    end
end

% Smooth the line
Layer_Inner_Bot = medfilt1(Layer_Inner_Bot, 11, 'omitnan');
Layer_Inner_Bot = smoothdata(Layer_Inner_Bot, 'sgolay', 25);

figure(h1);
plot(1:sx, Layer_Inner_Bot, 'y-', 'LineWidth', 2);

% find peaks for the layer
Layer_Blue1 = nan(sx, 1);
Layer_Blue2 = nan(sx, 1);
Layer_Blue3 = nan(sx, 1);
Layer_Blue4 = nan(sx, 1);

for x = 1:sx
    % define the area between the ILM and the yellow layer
    y_top = round(Layer_ILM(x));
    y_bot = round(Layer_Inner_Bot(x));
    
    if ~isnan(y_top) && ~isnan(y_bot) && (y_bot - y_top >= 10) && y_top >= 1 && y_bot <= sy
        
        % takes the brightest vertical value and smooths it to ignore dark
        % parts
        profile = double(I_crop(y_top:y_bot, x)); 
        profile_smooth = smoothdata(profile, 'gaussian', 3); 
        
        % find the peaks and makes sure to only gets the highest peaks
        [peaks, local_locs] = findpeaks(profile_smooth, 'MinPeakProminence', 3, 'MinPeakHeight', 35); 
        
        if ~isempty(local_locs)
            global_locs = y_top + local_locs - 1;
            
            % defining about where the layers will be
            total_thick = y_bot - y_top;
            track1 = y_top + (total_thick * 0.20);
            track2 = y_top + (total_thick * 0.40);
            track3 = y_top + (total_thick * 0.60);
            track4 = y_top + (total_thick * 0.80);
            
            % check the peak and add it to the area/track where it will be
            % the closest to
            for k = 1:length(global_locs)
                p_loc = global_locs(k);
                dists = abs([p_loc - track1, p_loc - track2, p_loc - track3, p_loc - track4]);
                [~, closest_track] = min(dists);
                
                if closest_track == 1, Layer_Blue1(x) = p_loc;
                elseif closest_track == 2, Layer_Blue2(x) = p_loc;
                elseif closest_track == 3, Layer_Blue3(x) = p_loc;
                else, Layer_Blue4(x) = p_loc;
                end
            end
        end
    end
end

% smooth the lines and connect them
Layer_Blue1 = smoothdata(fillmissing(medfilt1(Layer_Blue1, 7, 'omitnan'), 'nearest'), 'gaussian', 35);
Layer_Blue2 = smoothdata(fillmissing(medfilt1(Layer_Blue2, 7, 'omitnan'), 'nearest'), 'gaussian', 35);
Layer_Blue3 = smoothdata(fillmissing(medfilt1(Layer_Blue3, 7, 'omitnan'), 'nearest'), 'gaussian', 35);
Layer_Blue4 = smoothdata(fillmissing(medfilt1(Layer_Blue4, 7, 'omitnan'), 'nearest'), 'gaussian', 35);

% makes sure that the blue layers are only between the top and bottom
% layers
for x = 1:sx
    y_top = Layer_ILM(x);
    y_bot = Layer_Inner_Bot(x);
    
    if ~isnan(y_top) && ~isnan(y_bot)
        if Layer_Blue1(x) < y_top, Layer_Blue1(x) = y_top + 1; end
        if Layer_Blue1(x) > y_bot, Layer_Blue1(x) = y_bot - 1; end
        if Layer_Blue2(x) < y_top, Layer_Blue2(x) = y_top + 1; end
        if Layer_Blue2(x) > y_bot, Layer_Blue2(x) = y_bot - 1; end
        if Layer_Blue3(x) < y_top, Layer_Blue3(x) = y_top + 1; end
        if Layer_Blue3(x) > y_bot, Layer_Blue3(x) = y_bot - 1; end
        if Layer_Blue4(x) < y_top, Layer_Blue4(x) = y_top + 1; end
        if Layer_Blue4(x) > y_bot, Layer_Blue4(x) = y_bot - 1; end
    else
        Layer_Blue1(x) = NaN; Layer_Blue2(x) = NaN; Layer_Blue3(x) = NaN; Layer_Blue4(x) = NaN;
    end
end

% plot the blue layers
if sum(~isnan(Layer_Blue1)) > (sx * 0.15), plot(1:sx, Layer_Blue1, 'b-', 'LineWidth', 1.5); end
if sum(~isnan(Layer_Blue2)) > (sx * 0.15), plot(1:sx, Layer_Blue2, 'b-', 'LineWidth', 1.5); end
if sum(~isnan(Layer_Blue3)) > (sx * 0.15), plot(1:sx, Layer_Blue3, 'b-', 'LineWidth', 1.5); end
if sum(~isnan(Layer_Blue4)) > (sx * 0.15), plot(1:sx, Layer_Blue4, 'b-', 'LineWidth', 1.5); end



%% 5 Left-Side ROIs

if is_hole_found
    % Find where the hole starts on the left side
    hole_columns = any(Mask_Hole, 1);
    hole_left_edge = find(hole_columns, 1, 'first');
    
    % Margins to protect the data
    safe_margin = 50; % Horizontal margin to stay clear of the hole
    vert_margin = 2; % Vertical margin to exclude the bright boundary lines
    
    % Left ROI boundaries
    x_left_start = 1; 
    x_left_end   = max(1, hole_left_edge - safe_margin);
    
    % Initialize 5 separate masks for the left side
    Mask_ROI_L1 = false(sy, sx);
    Mask_ROI_L2 = false(sy, sx);
    Mask_ROI_L3 = false(sy, sx);
    Mask_ROI_L4 = false(sy, sx);
    Mask_ROI_L5 = false(sy, sx);
    
    for x = x_left_start : x_left_end
        y_ilm = round(Layer_ILM(x));
        y_b1  = round(Layer_Blue1(x));
        y_b2  = round(Layer_Blue2(x));
        y_b3  = round(Layer_Blue3(x));
        y_b4  = round(Layer_Blue4(x));
        y_yel = round(Layer_Inner_Bot(x));
        y_mag = round(Layer_RPE_bot(x));
        
        % L1: ILM to Blue 1
        if ~isnan(y_ilm) && ~isnan(y_b1) && (y_b1 - y_ilm > 2 * vert_margin)
            Mask_ROI_L1((y_ilm + vert_margin):(y_b1 - vert_margin), x) = true;
        end
        
        % L2: Blue 1 to Blue 2
        if ~isnan(y_b1) && ~isnan(y_b2) && (y_b2 - y_b1 > 2 * vert_margin)
            Mask_ROI_L2((y_b1 + vert_margin):(y_b2 - vert_margin), x) = true;
        end
        
        % L3: Blue 2 to Blue 3
        if ~isnan(y_b2) && ~isnan(y_b3) && (y_b3 - y_b2 > 2 * vert_margin)
            Mask_ROI_L3((y_b2 + vert_margin):(y_b3 - vert_margin), x) = true;
        end
        
        % L4: Blue 3 to Blue 4
        if ~isnan(y_b3) && ~isnan(y_b4) && (y_b4 - y_b3 > 2 * vert_margin)
            Mask_ROI_L4((y_b3 + vert_margin):(y_b4 - vert_margin), x) = true;
        end
        
        % L5: Yellow to Magenta
        if ~isnan(y_yel) && ~isnan(y_mag) && (y_mag - y_yel > 2 * vert_margin)
            Mask_ROI_L5((y_yel + vert_margin):(y_mag - vert_margin), x) = true;
        end
    end
    
    % Visualize the ROIs
    Mask_All_Left = Mask_ROI_L1 | Mask_ROI_L2 | Mask_ROI_L3 | Mask_ROI_L4 | Mask_ROI_L5;
    
    h10 = figure; imagesc(I_crop); colormap gray; hold on;
    title('5 Left-Side ROIs');
    plot(1:sx, Layer_ILM, 'r-', 'LineWidth', 1);
    plot(1:sx, Layer_Inner_Bot, 'y-', 'LineWidth', 1);
    plot(1:sx, Layer_RPE_bot, 'm-', 'LineWidth', 1);
    
    yellow_overlay = cat(3, ones(sy,sx), ones(sy,sx), zeros(sy,sx));
    h_overlay = imagesc(yellow_overlay);
    set(h_overlay, 'AlphaData', Mask_All_Left * 0.35);
    
    %% Statistics
    
    masks = {Mask_ROI_L1, Mask_ROI_L2, Mask_ROI_L3, Mask_ROI_L4, Mask_ROI_L5};
    roi_fields = {'L1', 'L2', 'L3', 'L4', 'L5'};
             
    STATS_Left = struct();
             
    for i = 1:5
        mask_rotated_back = imrotate(masks{i}, -tilt_angle, 'nearest', 'crop');

        ROI_raw = double(I_original_crop(mask_rotated_back)); 
        
        if ~isempty(ROI_raw)
            ROI_transformed = (10.^(ROI_raw/255) - 1) / 9; 
            current_stats = speckle_stats(ROI_transformed, ROI_raw);
            STATS_Left.(roi_fields{i}) = current_stats;
            
        else
            STATS_Left.(roi_fields{i}) = []; % Assign empty if no pixels
        end
    end
end

disp(STATS_Left.L1.CR);
disp(STATS_Left.L2.CR);
disp(STATS_Left.L3.CR);
disp(STATS_Left.L4.CR);
disp(STATS_Left.L5.CR);

% Speckle paramterization
%ROI_Right_raw = I_crop(Mask_ROI_Right);
% Inverse-log transformation and normalization
%ROI_Right = (10.^(ROI_Right_raw/255) - 1)/9; % 
%STATS_Right = speckle_stats(ROI_Right,ROI_Right_raw);