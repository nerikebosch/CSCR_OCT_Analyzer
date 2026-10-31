function M = hole_morphology(Mask_Hole, is_real_hole, I_img, geom, pixel_um)
% HOLE_MORPHOLOGY Morphological features of the subretinal fluid pocket (the "hole").
%
%   M = hole_morphology(Mask_Hole, is_real_hole, I_img, geom, pixel_um)
%
%   Mask_Hole    - logical mask of the hole from detect_hole (working image space)
%   is_real_hole - false if detect_hole found no hole (Mask_Hole is then a virtual strip)
%   I_img        - image the mask was segmented on (for intensity inside the hole)
%   geom         - geometry struct from preprocess_OCT (undoes the resize to 992x1536)
%   pixel_um     - [axial lateral] micrometres per pixel of the ORIGINAL exported image.
%                  Empty = report in original image pixels (shape features then assume square pixels).
%
% No hole: size features are 0 (no fluid), shape and intensity features are NaN (undefined).

    if nargin < 5, pixel_um = []; end

    M = struct();
    M.Hole_Found        = 0;
    % Size features (0 when there is no hole)
    M.Hole_Area         = 0;
    M.Hole_Width        = 0;
    M.Hole_Height       = 0;
    M.Hole_MeanHeight   = 0;
    M.Hole_Perimeter    = 0;
    M.Hole_EquivDiam    = 0;
    % Shape features (undefined when there is no hole)
    M.Hole_Circularity  = NaN;
    M.Hole_Solidity     = NaN;
    M.Hole_Extent       = NaN;
    M.Hole_Eccentricity = NaN;
    M.Hole_AspectRatio  = NaN;
    % Intensity inside the fluid
    M.Hole_MeanIntensity = NaN;
    M.Hole_CR            = NaN;

    if ~is_real_hole || ~any(Mask_Hole(:)), return; end

    % Keep only the largest connected component
    mask = bwareafilt(logical(Mask_Hole), 1);

    % Intensity of the fluid itself (measured before any resampling)
    vals = double(I_img(mask));
    M.Hole_MeanIntensity = mean(vals);
    M.Hole_CR = std(vals) / mean(vals);

    % Undo the resize in preprocess_OCT so pixels match the original exported image
    rows = size(mask, 1) * geom.orig_sy / geom.target_sy;
    cols = size(mask, 2) * geom.orig_sx / geom.target_sx;
    unit = 1; % length of one pixel after resampling
    if ~isempty(pixel_um)
        % Resample to square pixels of lateral size so shape features are not distorted
        rows = rows * pixel_um(1) / pixel_um(2);
        unit = pixel_um(2);
    end
    mask = imresize(mask, round([rows, cols]), 'nearest');
    mask = bwareafilt(mask, 1);
    if ~any(mask(:)), return; end

    P = regionprops(mask, 'Area', 'Perimeter', 'EquivDiameter', 'Solidity', 'Extent', ...
                    'Eccentricity', 'MajorAxisLength', 'MinorAxisLength');

    colHeights = sum(mask, 1);
    fluidCols = find(colHeights > 0);

    M.Hole_Found       = 1;
    M.Hole_Area        = P.Area * unit^2;
    M.Hole_Width       = (fluidCols(end) - fluidCols(1) + 1) * unit; % lateral extent
    M.Hole_Height      = max(colHeights) * unit;                     % maximum fluid height
    M.Hole_MeanHeight  = mean(colHeights(fluidCols)) * unit;         % average fluid height
    M.Hole_Perimeter   = P.Perimeter * unit;
    M.Hole_EquivDiam   = P.EquivDiameter * unit;
    M.Hole_Circularity = 4 * pi * P.Area / P.Perimeter^2;            % 1 = perfect circle
    M.Hole_Solidity    = P.Solidity;                                 % area / convex hull area
    M.Hole_Extent      = P.Extent;                                   % area / bounding box area
    M.Hole_Eccentricity = P.Eccentricity;
    M.Hole_AspectRatio = P.MajorAxisLength / P.MinorAxisLength;
end
