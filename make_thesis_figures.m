function make_thesis_figures(folderPath, options)
% MAKE_THESIS_FIGURES Saves the methodology figures for one B-scan of one visit folder.
%
%   make_thesis_figures(folderPath)
%   make_thesis_figures(folderPath, options)   with fields (all optional):
%       ScanIndex - which .bmp in the folder (default 1, the first processed scan)
%       OutDir    - output folder (default 'figs')
%       FitSide   - ROI side used for the back-transform and fit figures, 'Right' (default) or 'Left'
%       FitLayer  - ROI layer used for those figures (default 3)
%       Only      - figure numbers to save, e.g. 7 for only 07_profile (default: all)
%       MODEL     - an existing segmentAnythingModel (saves loading it again)
%
%   Run it once on an OD folder (hole case) and once on an OS folder (no-hole case).
%   Files are named <eye>_<date>_scan<idx>_<figure>.png (plots also as .pdf).
%
%   The intermediate steps (rough ILM, Otsu classes, hole candidates, SAM prompts,
%   intensity profile) are recomputed here with the same settings as the pipeline
%   functions. If you change a setting there, change it here too.

    if nargin < 2, options = struct(); end
    % speckle_stats needs burrfit2, kfit, etc. (same as batch_process_folders)
    addpath(genpath(fullfile(fileparts(mfilename('fullpath')), 'stats_utils')));
    if ~isfield(options, 'ScanIndex'), options.ScanIndex = 1; end
    if ~isfield(options, 'OutDir'),    options.OutDir = 'figs'; end
    if ~isfield(options, 'FitSide'),   options.FitSide = 'Right'; end
    if ~isfield(options, 'FitLayer'),  options.FitLayer = 3; end
    if ~isfield(options, 'Only'),      options.Only = []; end
    savefig_([], [], [], [], [], options.Only);   % which figures to save
    if ~isfield(options, 'MODEL') || isempty(options.MODEL)
        disp('Initializing SAM segmentAnythingModel...');
        MODEL = segmentAnythingModel;
    else
        MODEL = options.MODEL;
    end
    if ~isfolder(options.OutDir), mkdir(options.OutDir); end

    %% Scan and metadata
    folderPath = strip(folderPath, 'right', filesep);
    [~, folderName] = fileparts(folderPath);
    fileList = list_bscans(folderPath);   % sorted by B-scan number (not alphabetically)
    if isempty(fileList), error('No .bmp files in %s', folderPath); end
    idx = options.ScanIndex;
    fileName = fileList(idx).name;
    isLeftEye = contains(folderName, '_Retina_Radial_L_', 'IgnoreCase', true) || ...
                (contains(folderName, '_L_', 'IgnoreCase', true) && ~contains(folderName, '_Retina_Radial_R_', 'IgnoreCase', true));
    eyeTag = 'OD'; if isLeftEye, eyeTag = 'OS'; end
    dateTok = regexp(folderName, '(20\d{6})', 'match');
    dateStr = ''; if ~isempty(dateTok), dateStr = dateTok{end}; end
    prefix = sprintf('%s_%s_scan%d', eyeTag, dateStr, idx);
    outDir = options.OutDir;
    fprintf('Making figures for %s (%s)\n', fileName, prefix);

    %% Run the pipeline on this scan (its own debug figures are closed afterwards)
    figsBefore = findall(0, 'Type', 'figure');
    [I_crop_orig, I_crop_aligned, emb, sy, sx, angle_deg, I_true_raw, geom] = ...
        preprocess_OCT(folderPath, fileName, MODEL, isLeftEye);
    Layer_ILM = segment_ILM(I_crop_aligned, MODEL, emb, sy, sx, 0);
    % detect_hole and segment_layers always draw on h1, so give them a hidden figure
    h1 = figure('Visible', 'off'); hold on;
    [is_hole_found, Mask_Hole, MaxPH, indMaxPH, is_real_hole] = ...
        detect_hole(I_crop_aligned, MODEL, emb, sy, sx, Layer_ILM, 0, h1);
    [B1, B2, B3, B4, Inner, RPE_bot, RPE_top] = ...
        segment_layers(I_crop_aligned, MODEL, sy, sx, MaxPH, indMaxPH, Layer_ILM, Mask_Hole, 0, h1);
    [~, ~, ~, M_leg] = analyze_rois(I_crop_orig, I_crop_aligned, angle_deg, is_hole_found, Mask_Hole, sy, sx, ...
        B1, B2, B3, B4, Inner, RPE_bot, RPE_top, Layer_ILM, h1, I_true_raw, geom);
    [~, ~, ~, M_fw] = analyze_rois_fixed_width(I_crop_orig, I_crop_aligned, angle_deg, is_hole_found, Mask_Hole, sy, sx, ...
        B1, B2, B3, B4, Inner, RPE_bot, RPE_top, Layer_ILM, h1, I_true_raw, geom);
    delete(setdiff(findall(0, 'Type', 'figure'), figsBefore));

    if is_real_hole, caseStr = 'hole found'; else, caseStr = 'no hole: virtual strip'; end
    layerCols = [0.95 0.35 0.25; 0.98 0.75 0.15; 0.35 0.8 0.35; 0.25 0.65 0.95; 0.75 0.4 0.9];
    I0 = imread(fullfile(folderPath, fileName));
    if size(I0, 3) == 3, I0 = rgb2gray(I0); end

    %% 01 Raw exported B-scan
    try
        f = newfig(16, 11);
        ax = axes(f); showimg(ax, double(I0));
        title(ax, sprintf('Raw exported B-scan (%s, %s, %d \\times %d px)', eyeTag, dateStr, size(I0, 2), size(I0, 1)));
        savefig_(f, outDir, prefix, '01_raw', false);
    catch ME, warning('01_raw failed: %s', ME.message); end

    %% 02 Radial scan pattern (assumes scan 1 is horizontal and scans go in order over 180 deg)
    try
        f = newfig(9, 9);
        ax = axes(f); hold(ax, 'on');
        th = linspace(0, 2*pi, 200);
        plot(ax, cos(th), sin(th), 'k-', 'LineWidth', 1);
        sel = [1, 2, numel(fileList)];
        for k = 1:numel(fileList)
            a = (k - 1) * pi / numel(fileList);
            if ismember(k, sel)
                plot(ax, [-cos(a) cos(a)], [-sin(a) sin(a)], '-', 'Color', [0.85 0.2 0.15], 'LineWidth', 2);
                text(ax, 1.12 * cos(a), 1.12 * sin(a), sprintf('%d', k), 'Color', [0.85 0.2 0.15], ...
                     'FontWeight', 'bold', 'HorizontalAlignment', 'center');
            else
                plot(ax, [-cos(a) cos(a)], [-sin(a) sin(a)], '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
            end
        end
        axis(ax, 'equal'); axis(ax, 'off'); xlim(ax, [-1.25 1.25]); ylim(ax, [-1.25 1.25]);
        title(ax, sprintf('%d radial B-scans (9 mm), processed: %s', numel(fileList), mat2str(sel)));
        savefig_(f, outDir, prefix, '02_scan_pattern', true);
    catch ME, warning('02_scan_pattern failed: %s', ME.message); end

    %% 03 Preprocessing (same steps as preprocess_OCT)
    try
        Ip = I0; if isLeftEye, Ip = flip(Ip, 2); end
        Ir = double(imresize(Ip, [geom.target_sy, geom.target_sx]));
        Im = medfilt2(Ir, [15 15]);
        rough = nan(size(Ir, 2), 1);
        for ii = 1:size(Ir, 2)
            dIm = abs(diff(Im(:, ii))); ind = find(dIm > mean(dIm) + 3*std(dIm));
            if ~isempty(ind), rough(ii) = ind(1); end
        end
        xx = 1:size(Ir, 2); v = ~isnan(rough); p = polyfit(xx(v), rough(v)', 1);
        Ial = imrotate(Ir, angle_deg, 'bicubic', 'crop');
        Iac = Ial(:, geom.Margin + 1 : size(Ial, 2) - geom.Margin);
        T = multithresh(Iac, 3); Lab = imquantize(Iac, T);
        BW = imopen(imfill(Lab == 3 | Lab == 4, 'holes'), strel('disk', 3));

        f = newfig(24, 17);
        tl = tiledlayout(f, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
        ax = nexttile(tl); showimg(ax, Ir);
        plot(ax, xx, rough, 'r.', 'MarkerSize', 3); plot(ax, xx, polyval(p, xx), 'y-', 'LineWidth', 1.5);
        title(ax, sprintf('(a) Rough ILM and fitted line (tilt %.2f\\circ)', angle_deg));
        ax = nexttile(tl); showimg(ax, Ial);
        xline(ax, [geom.Margin, size(Ial, 2) - geom.Margin], 'y--', 'LineWidth', 1.5);
        title(ax, '(b) Tilt corrected, central 6 mm kept');
        ax = nexttile(tl); showimg(ax, double(BW) * 255);
        yline(ax, [geom.crop_top, geom.Y_max], 'r--', 'LineWidth', 1.5);
        title(ax, '(c) Otsu tissue mask (classes 3-4), vertical crop');
        ax = nexttile(tl); showimg(ax, I_crop_aligned);
        title(ax, '(d) Final working image');
        savefig_(f, outDir, prefix, '03_preprocessing', false);
    catch ME, warning('03_preprocessing failed: %s', ME.message); end

    %% 04 Hole detection (same steps as detect_hole)
    try
        syS = round(sy * 2);
        Is = imresize(I_crop_aligned, [syS, sx], 'bicubic');
        T1 = multithresh(uint8(Is), 3); lab = imquantize(uint8(Is), T1);
        Bw2 = imclose(lab == 3 | lab == 4, strel('disk', 1));
        filled = imfill(Bw2, 'holes');
        UL = false(syS, sx); UL(:, [1 end]) = true; UL(end, :) = true;
        UU = false(syS, sx); UU(:, [1 end]) = true; UU(1, :) = true;
        BW2LU = ~imfill(filled | UL, 'holes') | ~imfill(filled | UU, 'holes');
        Bw3 = ~(Bw2 | BW2LU);
        Bw3([1 end], :) = false; Bw3(:, [1 end]) = false;
        Bw3 = imopen(Bw3, strel('disk', 4));
        % same rule as detect_hole: the centroid must lie between 35 % and 75 % of the width
        lm = round(sx * 0.35); rm = round(sx * 0.25);
        st = regionprops(Bw3, 'Area', 'BoundingBox', 'PixelIdxList', 'Solidity', 'Centroid');
        pass = false(numel(st), 1);
        for k = 1:numel(st)
            dark = sum(lab(st(k).PixelIdxList) == 1) / st(k).Area;
            bb = st(k).BoundingBox;
            inCentre = st(k).Centroid(1) >= lm && st(k).Centroid(1) <= sx - rm;
            pass(k) = st(k).Area > 1000 && dark > 0.20 && bb(4) / bb(3) < 4 && st(k).Solidity > 0.30 && inCentre;
        end
        chosen = [];
        if any(pass), [~, j] = max([st.Area] .* pass'); chosen = j; end

        f = newfig(24, 22);
        tl = tiledlayout(f, 3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
        ax = nexttile(tl); showimg(ax, Is); title(ax, '(a) Image stretched 2\times vertically');
        ax = nexttile(tl); imagesc(ax, lab); axis(ax, 'image', 'off'); colormap(ax, parula(4));
        cb = colorbar(ax); cb.Ticks = 1:4; cb.Label.String = 'Otsu class (1 = darkest)';
        title(ax, '(b) Multi-level Otsu, 4 classes');
        ax = nexttile(tl); showimg(ax, double(Bw2) * 255); title(ax, '(c) Bright tissue (classes 3-4)');
        ax = nexttile(tl); showimg(ax, double(BW2LU) * 255);
        title(ax, '(d) Dark regions open to top/bottom (removed)');
        ax = nexttile(tl); showimg(ax, double(Bw3) * 255);
        xline(ax, [lm, sx - rm], 'c--', 'LineWidth', 1.2);   % centroid must lie between these lines
        for k = 1:numel(st)
            c = [0.9 0.2 0.2]; lw = 1;
            if pass(k), c = [1 0.85 0.1]; end
            if isequal(k, chosen), c = [0.2 0.9 0.3]; lw = 2.5; end
            rectangle(ax, 'Position', st(k).BoundingBox, 'EdgeColor', c, 'LineWidth', lw);
        end
        title(ax, '(e) Candidates: red rejected, yellow passed, green chosen');
        ax = nexttile(tl); showimg(ax, I_crop_aligned);
        if is_real_hole
            overlay(ax, Mask_Hole, [0 0.9 1], 0.4);
            if ~isempty(chosen)
                bb = st(chosen).BoundingBox; bb([2 4]) = bb([2 4]) / 2;
                rectangle(ax, 'Position', bb, 'EdgeColor', 'y', 'LineStyle', '--', 'LineWidth', 1.5);
            end
            plot(ax, indMaxPH, MaxPH, 'r*', 'MarkerSize', 10, 'LineWidth', 1.5);
            title(ax, '(f) Fluid mask: SAM (box prompt) + candidate, * = lowest point');
        else
            overlay(ax, Mask_Hole, [1 0.4 0.1], 0.4);
            plot(ax, 1:sx, Layer_ILM, 'r-', 'LineWidth', 1);
            plot(ax, indMaxPH, Layer_ILM(indMaxPH), 'y*', 'MarkerSize', 10, 'LineWidth', 1.5);
            yline(ax, MaxPH, 'y--', 'LineWidth', 1);
            title(ax, '(f) No hole: 20 px strip at foveal pit (*), ref. row = sy/2');
        end
        savefig_(f, outDir, prefix, '04_hole_detection', false);
    catch ME, warning('04_hole_detection failed: %s', ME.message); end

    %% 05 SAM prompts and masks (same prompts as segment_ILM and segment_layers)
    try
        Mask_V = segmentObjectsFromEmbeddings(MODEL, emb, [sy, sx], ...
            "ForegroundPoints", [sx/2 20], "BackgroundPoints", [[1; sx; 50], [1; 1; 1]]);
        fgI = [sx/2 20]; bgI = [[1; sx; 50], [1; 1; 1]];

        cy = max(1, MaxPH - 70);
        Irpe = double(I_crop_aligned(cy:sy, :));
        [syr, sxr] = size(Irpe);
        embR = extractEmbeddings(MODEL, Irpe);
        lhb = MaxPH - cy + 1;
        [~, li] = max(double(Irpe(lhb:end, indMaxPH)));
        fgT = [indMaxPH, lhb + li - 1]; bgT = [indMaxPH, max(1, lhb - 5)];
        Mask_T = segmentObjectsFromEmbeddings(MODEL, embR, [syr, sxr], "ForegroundPoints", fgT, "BackgroundPoints", bgT);

        vx = find(~isnan(RPE_top));
        lx = vx(max(1, round(numel(vx) * 0.25))); rx = vx(max(1, round(numel(vx) * 0.75))); mx = vx(round(numel(vx) * 0.50));
        yl = round(RPE_top(lx)) - cy + 1; yr = round(RPE_top(rx)) - cy + 1; ym = round(RPE_top(mx)) - cy + 1;
        fgB = [lx, min(syr, yl + 40); mx, min(syr, ym + 40); rx, min(syr, yr + 40)];
        bgB = [1, max(1, yl + 1); 50, max(1, yl + 1); lx, max(1, yl + 5); mx - 150, max(1, ym); ...
               mx, max(1, ym + 15); mx + 150, max(1, ym + 10); rx, max(1, yr + 5); sxr, max(1, yr - 25)];
        Mask_B = segmentObjectsFromEmbeddings(MODEL, embR, [syr, sxr], "ForegroundPoints", fgB, "BackgroundPoints", bgB);
        Mask_B = imclose(bwareafilt(logical(Mask_B), 1), strel('disk', 20));

        full = @(m) [false(cy - 1, sx); m];   % crop mask back into the working image
        sh = [0, cy - 1];                     % prompt shift from crop to working image

        f = newfig(18, 26);
        tl = tiledlayout(f, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
        ax = nexttile(tl); showimg(ax, I_crop_aligned);
        overlay(ax, Mask_V, [0.3 0.5 1], 0.35); plot(ax, 1:sx, Layer_ILM, 'r-', 'LineWidth', 1.5);
        prompts(ax, fgI, bgI);
        title(ax, '(a) ILM: SAM segments the vitreous (blue); its lower edge is the ILM (red)');
        ax = nexttile(tl); showimg(ax, I_crop_aligned);
        overlay(ax, full(Mask_T), [0 0.9 1], 0.35); plot(ax, 1:sx, RPE_top, 'c-', 'LineWidth', 1.5);
        yline(ax, cy, 'w--'); prompts(ax, fgT + sh, bgT + sh);
        title(ax, '(b) RPE top: brightest pixel below the reference point (dashed = SAM crop)');
        ax = nexttile(tl); showimg(ax, I_crop_aligned);
        overlay(ax, full(Mask_B), [1 0.3 1], 0.35); plot(ax, 1:sx, RPE_bot, 'm-', 'LineWidth', 1.5);
        hp = prompts(ax, fgB + sh, bgB + sh);
        title(ax, '(c) RPE bottom: 3 foreground and 8 background points, after shadow correction');
        legend(ax, hp, {'Foreground point', 'Background point'}, 'Location', 'southoutside', ...
               'Orientation', 'horizontal', 'TextColor', 'k');
        savefig_(f, outDir, prefix, '05_sam_prompts', false);
    catch ME, warning('05_sam_prompts failed: %s', ME.message); end

    %% Column used for the intensity profile: middle of the chosen ROI (or 85% of the width)
    roiMask = M_leg.(options.FitSide);
    if isempty(roiMask), roiMask = M_fw.(options.FitSide); end
    roiCols = find(any(roiMask{options.FitLayer}, 1));
    if isempty(roiCols), xp = round(sx * 0.85); else, xp = roiCols(round(end / 2)); end

    %% 06 All boundaries and layer names
    try
        f = newfig(18, 13);
        ax = axes(f); showimg(ax, I_crop_aligned);
        h = gobjects(0);
        h(end+1) = plot(ax, 1:sx, Layer_ILM, 'r-', 'LineWidth', 1.2, 'DisplayName', 'ILM');
        hb = plot(ax, 1:sx, [B1 B2 B3 B4], '-', 'Color', [0.3 0.55 1], 'LineWidth', 1.2);
        hb(1).DisplayName = 'Boundaries 1-4'; h(end+1) = hb(1);
        h(end+1) = plot(ax, 1:sx, Inner, 'y-', 'LineWidth', 1.2, 'DisplayName', 'Inner boundary');
        h(end+1) = plot(ax, 1:sx, RPE_top, 'c-', 'LineWidth', 1.2, 'DisplayName', 'RPE top');
        h(end+1) = plot(ax, 1:sx, RPE_bot, 'm-', 'LineWidth', 1.2, 'DisplayName', 'RPE bottom');
        if is_real_hole
            bnd = bwboundaries(Mask_Hole);
            for b = 1:numel(bnd), plot(ax, bnd{b}(:, 2), bnd{b}(:, 1), 'w-', 'LineWidth', 1); end
        end
        xline(ax, xp, 'w--', 'LineWidth', 1);
        tops = [Layer_ILM(xp), B1(xp), B2(xp), B3(xp), Inner(xp)];
        bots = [B1(xp), B2(xp), B3(xp), B4(xp), RPE_bot(xp)];
        xt = min(sx - 20, xp + 25);
        for L = 1:5
            text(ax, xt, (tops(L) + bots(L)) / 2, sprintf('L%d', L), 'Color', 'w', 'FontWeight', 'bold', ...
                 'FontSize', 8, 'BackgroundColor', 'k', 'Margin', 1);
        end
        legend(ax, h, 'Location', 'southoutside', 'Orientation', 'horizontal', 'TextColor', 'k');
        title(ax, sprintf('Retinal boundaries and ROIs L1-L5 (%s); dashed = profile column', caseStr));
        savefig_(f, outDir, prefix, '06_boundaries', false);
    catch ME, warning('06_boundaries failed: %s', ME.message); end

    %% 07 Intensity profile of one column with the detected peaks (same as segment_layers)
    try
        yt = round(Layer_ILM(xp)); yb = round(Inner(xp));
        prof = double(I_crop_aligned(yt:yb, xp));
        ps = smoothdata(prof, 'gaussian', 3);
        [~, locs] = findpeaks(ps, 'MinPeakProminence', 3, 'MinPeakHeight', 35);
        d = (0:numel(prof) - 1)';
        f = newfig(16, 9);
        ax = axes(f); hold(ax, 'on');
        plot(ax, d, prof, '-', 'Color', [0.7 0.7 0.7], 'DisplayName', 'Raw profile');
        plot(ax, d, ps, 'k-', 'LineWidth', 1.5, 'DisplayName', 'Smoothed (Gaussian, 3)');
        plot(ax, d(locs), ps(locs), 'rv', 'MarkerFaceColor', 'r', 'DisplayName', 'Peaks');
        xline(ax, (yb - yt) * [0.2 0.4 0.6 0.8], '--', {'20%', '40%', '60%', '80%'}, 'Color', [0.3 0.55 1], ...
              'HandleVisibility', 'off', 'LabelVerticalAlignment', 'bottom');
        yline(ax, 35, 'k:', 'Min. peak height 35', 'HandleVisibility', 'off');
        xline(ax, [B1(xp) B2(xp) B3(xp) B4(xp)] - yt, '-', {'B1', 'B2', 'B3', 'B4'}, 'Color', [0 0.25 0.8], ...
              'LineWidth', 1.5, 'HandleVisibility', 'off');
        xlabel(ax, 'Depth below ILM (px)'); ylabel(ax, 'Intensity (8-bit)');
        legend(ax, 'Location', 'northeast'); grid(ax, 'on'); box(ax, 'on');
        title(ax, {sprintf('Column %d: peaks assigned to the nearest of 4 positions (dashed);', xp), 'final boundaries (solid)'});
        savefig_(f, outDir, prefix, '07_profile', true);
    catch ME, warning('07_profile failed: %s', ME.message); end

    %% 08 ROIs: full-width vs fixed-width
    try
        f = newfig(18, 22);
        tl = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
        sets = {M_leg, M_fw};
        names = {sprintf('(a) Full-width ROIs (%s)', caseStr), '(b) Fixed-width ROIs (120 px)'};
        for s = 1:2
            ax = nexttile(tl); showimg(ax, I_crop_aligned);
            masks = [sets{s}.Left, sets{s}.Right, sets{s}.Full];
            for m = 1:numel(masks)
                overlay(ax, masks{m}, layerCols(mod(m - 1, 5) + 1, :), 0.5);
            end
            overlay(ax, Mask_Hole, [1 1 1], 0.25);
            for L = 1:5
                plot(ax, NaN, NaN, 's', 'MarkerFaceColor', layerCols(L, :), 'MarkerEdgeColor', 'none', ...
                     'MarkerSize', 9, 'DisplayName', sprintf('L%d', L));
            end
            plot(ax, NaN, NaN, 's', 'MarkerFaceColor', [0.85 0.85 0.85], 'MarkerEdgeColor', 'none', ...
                 'MarkerSize', 9, 'DisplayName', 'Hole / virtual strip');
            legend(ax, 'Location', 'southoutside', 'Orientation', 'horizontal', 'TextColor', 'k');
            title(ax, names{s});
        end
        savefig_(f, outDir, prefix, '08_rois', false);
    catch ME, warning('08_rois failed: %s', ME.message); end

    %% 09 ROI mapped back to the raw image
    try
        mAl = roiMask{options.FitLayer};
        mRaw = to_raw(mAl, angle_deg, geom);
        f = newfig(24, 9);
        tl = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
        ax = nexttile(tl); showimg(ax, I_crop_aligned); overlay(ax, mAl, [1 0.85 0.1], 0.6);
        title(ax, sprintf('(a) %s L%d in the working image', options.FitSide, options.FitLayer));
        ax = nexttile(tl); showimg(ax, I_true_raw); overlay(ax, mRaw, [1 0.85 0.1], 0.6);
        title(ax, sprintf('(b) Mapped back to the raw image (%d \\times %d px)', geom.orig_sx, geom.orig_sy));
        savefig_(f, outDir, prefix, '09_back_transform', false);
    catch ME, warning('09_back_transform failed: %s', ME.message); end

    %% 10 Histogram, KDE and the 8 fitted PDFs for one ROI (same as speckle_stats)
    try
        raw = double(I_true_raw(to_raw(roiMask{options.FitLayer}, angle_deg, geom)));
        lin = (10.^(raw / 255) - 1) / 9;
        S = speckle_stats(lin, raw);
        lin = lin(lin > 0);
        pts = linspace(min(lin) + eps, max(lin), 1000);
        KDE = ksdensity(lin, pts, 'Kernel', 'epanechnikov', 'Support', 'positive');
        % Same order as STATS.GOF: [BURR EXP GAM K LN NK RAY WBL]
        dn = {'Burr', 'Exponential', 'Gamma', 'K', 'Lognormal', 'Nakagami', 'Rayleigh', 'Weibull'};
        P = cell(1, 8);
        P{1} = burr2pdf(pts, S.BURR);
        P{2} = exppdf(pts, S.EXP);
        P{3} = gampdf(pts, S.GAM(1), S.GAM(2));
        if any(isnan(S.K)), P{4} = nan(size(pts)); else, P{4} = kpdf(pts, S.K(1), S.K(2)); end
        P{5} = lognpdf(pts, S.LN(1), S.LN(2));
        P{6} = pdf(makedist('Nakagami', S.NK(1), S.NK(2)), pts);
        P{7} = raylpdf(pts, S.RAY(1));
        P{8} = wblpdf(pts, S.WBL(1), S.WBL(2));
        [~, best] = min(S.GOF);

        f = newfig(17, 11);
        ax = axes(f); hold(ax, 'on');
        xmax = prctile(lin, 99.5);
        histogram(ax, lin(lin <= xmax), 80, 'Normalization', 'pdf', 'FaceColor', [0.82 0.82 0.82], ...
                  'EdgeColor', 'none', 'DisplayName', 'Histogram');
        plot(ax, pts, KDE, 'k-', 'LineWidth', 2.5, 'DisplayName', 'KDE (reference)');
        cols = lines(8);
        for k = 1:8
            if all(isnan(P{k}))
                plot(ax, NaN, NaN, '-', 'Color', cols(k, :), 'DisplayName', sprintf('%s (fit failed)', dn{k}));
                continue;
            end
            lw = 1.2; tag = '';
            if k == best, lw = 3; tag = '  BEST'; end
            plot(ax, pts, P{k}, '-', 'Color', cols(k, :), 'LineWidth', lw, ...
                 'DisplayName', sprintf('%s (RMSE %.3g)%s', dn{k}, S.GOF(k), tag));
        end
        xlim(ax, [0 xmax]);
        xlabel(ax, 'Linear intensity'); ylabel(ax, 'Probability density');
        legend(ax, 'Location', 'northeast', 'FontSize', 7); grid(ax, 'on'); box(ax, 'on');
        title(ax, sprintf('%s L%d, %s: fitted PDFs vs. KDE (n = %d pixels)', options.FitSide, ...
              options.FitLayer, eyeTag, numel(lin)));
        savefig_(f, outDir, prefix, '10_distribution_fit', true);
    catch ME, warning('10_distribution_fit failed: %s', ME.message); end

    %% 11 Hole morphology features (only with a real hole; working-image pixels)
    if is_real_hole
        try
            mk = bwareafilt(logical(Mask_Hole), 1);
            rp = regionprops(mk, 'BoundingBox', 'ConvexHull');
            bnd = bwboundaries(mk);
            colH = sum(mk, 1); fc = find(colH > 0);
            [~, hc] = max(colH); rows = find(mk(:, hc));
            bb = rp.BoundingBox;
            f = newfig(16, 10);
            ax = axes(f); showimg(ax, I_crop_aligned);
            overlay(ax, mk, [0 0.9 1], 0.35);
            plot(ax, bnd{1}(:, 2), bnd{1}(:, 1), 'g-', 'LineWidth', 1.5, 'DisplayName', 'Perimeter');
            plot(ax, rp.ConvexHull(:, 1), rp.ConvexHull(:, 2), 'y--', 'LineWidth', 1.2, 'DisplayName', 'Convex hull (solidity)');
            plot(ax, bb(1) + [0 bb(3) bb(3) 0 0], bb(2) + [0 0 bb(4) bb(4) 0], 'w:', 'LineWidth', 1.2, ...
                 'DisplayName', 'Bounding box (extent)');
            yw = bb(2) + bb(4) + 8;
            plot(ax, [fc(1) fc(end)], [yw yw], 'r-', 'LineWidth', 2, 'DisplayName', 'Width');
            plot(ax, [hc hc], [rows(1) rows(end)], '-', 'Color', [1 0.5 0], 'LineWidth', 2, 'DisplayName', 'Max. height');
            pad = 40;
            xlim(ax, [max(1, bb(1) - pad), min(sx, bb(1) + bb(3) + pad)]);
            ylim(ax, [max(1, bb(2) - pad), min(sy, bb(2) + bb(4) + pad)]);
            legend(ax, 'Location', 'eastoutside', 'TextColor', 'k');
            title(ax, 'Fluid pocket morphology features (illustration in working-image pixels)');
            savefig_(f, outDir, prefix, '11_hole_morphology', false);
        catch ME, warning('11_hole_morphology failed: %s', ME.message); end
    end

    %% 12 Linearisation of the log-compressed intensities
    try
        f = newfig(9, 7);
        ax = axes(f);
        r = 0:255;
        plot(ax, r, (10.^(r / 255) - 1) / 9, 'k-', 'LineWidth', 1.5);
        xlabel(ax, 'Exported value I_{raw} (8-bit)'); ylabel(ax, 'I_{lin}');
        title(ax, 'I_{lin} = (10^{I_{raw}/255} - 1) / 9');
        grid(ax, 'on'); xlim(ax, [0 255]);
        savefig_(f, outDir, prefix, '12_linearisation', true);
    catch ME, warning('12_linearisation failed: %s', ME.message); end

    fprintf('Figures saved in %s\n', outDir);
end

%% Helpers
function f = newfig(w, h)
    f = figure('Visible', 'off', 'Units', 'centimeters', 'Position', [2 2 w h]);
    if isprop(f, 'Theme'), f.Theme = 'light'; end   % white figure with black text, also in dark mode
    f.Color = 'w';
end

function showimg(ax, I)
    imagesc(ax, I); colormap(ax, gray); clim(ax, [0 255]);
    axis(ax, 'image'); axis(ax, 'off'); hold(ax, 'on');
end

function overlay(ax, mask, rgb, a)
    h = image(ax, repmat(reshape(rgb, 1, 1, 3), size(mask, 1), size(mask, 2)));
    h.AlphaData = a * double(mask);
end

function h = prompts(ax, fg, bg)
    h(1) = scatter(ax, fg(:, 1), fg(:, 2), 45, [0.1 0.9 0.2], 'filled', 'MarkerEdgeColor', 'k');
    h(2) = scatter(ax, bg(:, 1), bg(:, 2), 45, [0.95 0.2 0.2], 'filled', 'MarkerEdgeColor', 'k');
end

function savefig_(f, outDir, prefix, name, vector, setOnly)
    % savefig_([], [], [], [], [], only) sets which figure numbers are saved (empty = all)
    persistent only
    if nargin == 6, only = setOnly; return; end
    num = sscanf(name, '%d', 1);
    if ~isempty(only) && ~ismember(num, only), close(f); return; end
    base = fullfile(outDir, sprintf('%s_%s', prefix, name));
    exportgraphics(f, [base '.png'], 'Resolution', 300);
    if vector, exportgraphics(f, [base '.pdf'], 'ContentType', 'vector'); end
    close(f);
    fprintf('  saved %s\n', base);
end

%% Same as transform_mask_to_raw in analyze_rois
function True_Mask = to_raw(Mask, angle_deg, geom)
    M_rot = imrotate(Mask, -angle_deg, 'nearest', 'crop');
    M = padarray(M_rot, [geom.crop_top - 1, 0], 0, 'pre');
    M = padarray(M, [geom.target_sy - geom.Y_max, 0], 0, 'post');
    M = padarray(M, [0, geom.Margin], 0, 'both');
    True_Mask = imresize(M, [geom.orig_sy, geom.orig_sx], 'nearest');
end
