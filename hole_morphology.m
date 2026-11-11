function M = hole_morphology(Mask_Hole, is_real_hole, I_img, geom, pixel_um)
% HOLE_MORPHOLOGY Morphological features of the subretinal fluid pocket (the "hole").
%
%   M = hole_morphology(Mask_Hole, is_real_hole, I_img, geom, pixel_um)
%
%   Mask_Hole    - logical mask of the hole from detect_hole (working image space)
%   is_real_hole - false if detect_hole found no hole (Mask_Hole is then a virtual strip)
%   I_img        - image the mask was segmented on (for intensity inside the hole)
%   geom         - geometry struct from preprocess_OCT (not used any more; kept for the call signature)
%   pixel_um     - [axial lateral] micrometres per pixel of the WORKING image (992 x 1536 grid, lateral 5.86 um).
%                  Empty = report in working-image pixels (same pixel size for every protocol).
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

    % Measure on the working-image grid. preprocess_OCT resamples every exported image to
    % 992 x 1536 px over the same 9 mm scan, so one working pixel has the same size in all
    % protocols (lateral 9000/1536 = 5.86 um). The original exports differ in width
    % (1536, 2048 or more px), so measuring in original pixels would not be comparable.
    rows = size(mask, 1);
    cols = size(mask, 2);
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
