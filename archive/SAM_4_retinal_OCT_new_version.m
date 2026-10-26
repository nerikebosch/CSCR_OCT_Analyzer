%% First attempt to use SAM for OCT retinal scans

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



%% Create ILM Mask (Red Line)


Mask_ILM = ~segmentObjectsFromEmbeddings(MODEL, embeddings_medfilt, [sy, sx], ...
    "ForegroundPoints",[821 22]); % gets point in background at the top
Mask_ILM = imopen(Mask_ILM,strel('disk',25));

% Use threshold to mark nicely where the ilm line should go, because there
% were problems with it going into the background.
T_ilm = multithresh(uint8(I_crop), 3);
labels_ilm = imquantize(uint8(I_crop), T_ilm);
Layer_ILM = zeros(sx,1);

% Gets the middle part where the fovea is, because there were some problems
% where it would not have the ilm line correctly there. So this prevents
% dipping
fovea_start = round(sx * 0.25);
fovea_end = round(sx * 0.75);

for ii = 1 : sx
    col_labels = labels_ilm(:, ii);
    col_mask = Mask_ILM(:, ii);
    
    % Find the first pixel of bright solid tissue (Level 3 or 4)
    ind_bright = find(col_labels >= 3);
    
    if ~isempty(ind_bright)
        y_solid = ind_bright(1);
        
        % If we are in the central foveal pit zone
        if ii >= fovea_start && ii <= fovea_end
            
            % Makes sure the whole fovea area gets included
            y_surface = y_solid;
            while y_surface > 1 && col_labels(y_surface - 1) >= 2
                y_surface = y_surface - 1;
            end
            Layer_ILM(ii) = y_surface;
        else
            % If we are on the edges, only use the bright white tissue (Level 3)
            Layer_ILM(ii) = y_solid;
        end
    end
end


% filter to smooth the line
Layer_ILM = medfilt1(Layer_ILM, 5, 'omitnan');
Layer_ILM = smoothdata(Layer_ILM, 'sgolay', 45);


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
% Conclusion: single threshold does not create a well-resolved BW image
%Bw = im2bw(I_heq,100/255);  % im2bw  vs imbinarize
%Th1 = graythresh(I_heq);
%k = 1.5; % just a hinch
%Bw1 = imbinarize(I_heq,k*Th1); % The threshold is calculated based on graythresh method
%%Bw2 = imclose(Bw,strel('disk',8));
%figure; imagesc(Bw1); colormap gray;


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
figure;imagesc(labels)

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

figure;imagesc(Bw3);colormap gray

% check whether there is a hole in the macula
ind_potential_hole = Bw3 == 1;
num_of_ones = sum(ind_potential_hole(:));
label1match = labels(ind_potential_hole) == 1;

disp([sum(label1match) 0.005*num_of_ones])

if sum(label1match) < 0.005*num_of_ones
    disp('No hole')
    % assume there is no hole
    % Processing type I
else
    disp('Hole found')
    % assume there is a hole
    % Processing type II
end



% carefull with openining - consider object properties (select the largest
% one)
%Bw3 = imopen(Bw3,strel('disk',5));





% create a U-masks
%Umask = zeros(size(I_crop));
%Umask(:,[1 end]) = 1;
%Umask(end,:) = 1;

%Bw3Umask = or(Bw3,Umask);
%Bw3Umask = imfill(Bw3Umask,'holes');
%Bw1 = imopen(Bw1Umask, strel('disk',1));

%Consider finding the RPE by taking the averege (by rows) and find the
%location of the second peak (realted to the highly visible RPE layer).
%Then use that information for selecting two peripheral (non-central) x
%values (they may be arbitrary).



%% Identify the hole and get its center


% Invert to make the retina black (0) and the rest white so that the
% regionprops can detect it
Bw_holes =  Bw3; 

% But then make the background part black (0) again so that it wont be
% detected
for x = 1:sx
    y_ilm = Layer_ILM(x);
    if y_ilm > 0
        safe_y = min(y_ilm + 10, sy); 
        Bw_holes(1:round(safe_y), x) = 0; 
    end
end
Bw_holes = imfill(Bw_holes,'holes');
Bw_holes = imopen(Bw_holes, strel('disk',3)); % careful with radius 10 for small openings

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
    "ForegroundPoints",[hole_centroid(1) hole_centroid(2)]); % Using points from what we got to get the center part above

figure; imagesc(Mask_Hole); colormap gray;
title("SAM image of the hole");


posterior_hole = nan(sx,1);
for ii = 1 : sx
    col_top = Mask_Hole(:,ii);
    ind  = find(col_top==1);
    if ~isempty(ind)
        posterior_hole(ii) = ind(end);
    end
end
[MaxPH,indMaxPH] = max(posterior_hole);



%% Create mask for the top of the RPE (Cyan Line)

% Searching for the brightest pixel in the bottom third of the scan 
% to ensure that it doesnt click inside the hole.
search_start = max(MaxPH, round(sy * 0.6)); 
search_profile = double(I_crop(search_start:sy, indMaxPH));
[~, rpe_offset] = max(search_profile); 
true_rpe_y = search_start + rpe_offset - 1;

% A point in the upper half of the scan to make sure that SAM doesn't get
% any area above the hole.
bg_upper_x = indMaxPH;
bg_upper_y = round(Layer_ILM(indMaxPH)) + 5;
if isnan(bg_upper_y), bg_upper_y = 15; end

Mask_RPE_top = segmentObjectsFromEmbeddings(MODEL, embeddings_org, [sy, sx], ...
    "ForegroundPoints", [indMaxPH, true_rpe_y], ...
    "BackgroundPoints", [bg_upper_x, bg_upper_y]);

% try to make the mask smoother and remove some hard parts around it.
Mask_RPE_top = bwareafilt(logical(Mask_RPE_top), 1);
Mask_RPE_top = imopen(Mask_RPE_top, strel('disk', 1));
Mask_RPE_top = imclose(Mask_RPE_top, strel('disk', 15));


% Create the line
Layer_RPE_top = nan(sx,1); 
for ii = 1 : sx
    col_top = Mask_RPE_top(:,ii);
    ind_top  = find(col_top==1);
    if ~isempty(ind_top)
        Layer_RPE_top(ii) = ind_top(1);
    end
end

% This is to ensure that the RPE line is not close to the ILM line because
% sometimes it went up on the sides.
for x = 1:sx
    if ~isnan(Layer_RPE_top(x)) && ~isnan(Layer_ILM(x))
        if (Layer_RPE_top(x) - Layer_ILM(x)) < 30
            Layer_RPE_top(x) = NaN;
        end
    end
end


% This just connects and smooths the lines
% nearest makes sure it stays flat at the edges 
Layer_RPE_top = fillmissing(Layer_RPE_top, 'linear', 'EndValues', 'nearest');
Layer_RPE_top = medfilt1(Layer_RPE_top, 5, 'omitnan');
Layer_RPE_top = smoothdata(Layer_RPE_top, 'sgolay', 45);


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



%% Create mask for bottom part of rpe (Magenta Line)


Mask_RPE_bot = segmentObjectsFromEmbeddings(MODEL, embeddings_org, [sy, sx], ...
    "ForegroundPoints", [safe_x, y_rpe_top + 40;     
                         mid_x, y_rpe_mid + 40], ... 
    "BackgroundPoints", [safe_x, y_rpe_top + 10;      
                         mid_x, y_rpe_mid + 10]);

Mask_RPE_bot = bwareafilt(logical(Mask_RPE_bot), 1);
Mask_RPE_bot = imopen(Mask_RPE_bot,strel('disk',20));

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
Layer_RPE_bot = medfilt1(Layer_RPE_bot, 5, 'omitnan');
Layer_RPE_bot = smoothdata(Layer_RPE_bot, 'sgolay', 45);

figure(h1);
plot(1:sx,Layer_RPE_top,'c.')
plot(1:sx,Layer_RPE_bot,'m.')

figure; imagesc(Mask_RPE_top); colormap gray;
title("Top part of the RPE Mask");
figure; imagesc(Mask_RPE_bot); colormap gray;
title("Bottom part of the RPE Mask");

Mask_RPE_only = Mask_RPE_top & ~Mask_RPE_bot;

figure; imagesc(Mask_RPE_only); colormap gray;
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