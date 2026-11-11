function make_visit_comparison(visitFolders, options)
% MAKE_VISIT_COMPARISON B-scans of OD and OS side by side at several visits, with the
% segmentation, fluid outline and fixed-width ROIs drawn on top (Results, temporal evolution).
%
%   make_visit_comparison({'C:\School\Thesis\20260224', 'C:\School\Thesis\20260331'})
%   make_visit_comparison(visitFolders, options)   with fields (all optional):
%       ScanIndex - which B-scan of each acquisition (default 1)
%       OutDir    - output folder (default 'figs/results')
%       MODEL     - an existing segmentAnythingModel
%
%   Rows = visits, columns = OD | OS. The first acquisition of each eye in a visit folder is used.
%   OS is shown flipped, as it is processed (same anatomical side as OD).
%   Saves res_visit_comparison.png / .pdf

    if nargin < 2, options = struct(); end
    if ~isfield(options, 'ScanIndex'), options.ScanIndex = 1; end
    if ~isfield(options, 'OutDir'), options.OutDir = fullfile('figs', 'results'); end
    addpath(genpath(fullfile(fileparts(mfilename('fullpath')), 'stats_utils')));
    if ~isfield(options, 'MODEL') || isempty(options.MODEL)
        disp('Initializing SAM segmentAnythingModel...');
        options.MODEL = segmentAnythingModel;
    end
    if ~isfolder(options.OutDir), mkdir(options.OutDir); end

    V = db_manager('get_visits');
    nV = numel(visitFolders);
    layerCols = [0.95 0.35 0.25; 0.98 0.75 0.15; 0.35 0.8 0.35; 0.25 0.65 0.95; 0.75 0.4 0.9];

    f = figure('Visible', 'off', 'Units', 'centimeters', 'Position', [1 1 17 3.3 * nV + 1.5], 'Color', 'w');
    if isprop(f, 'Theme'), f.Theme = 'light'; end
    tl = tiledlayout(f, nV, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    letter = 'a';
    for v = 1:nV
        folder = strip(visitFolders{v}, 'right', filesep);
        [~, dateStr] = fileparts(folder);
        dt = datetime(dateStr, 'InputFormat', 'yyyyMMdd');
        k = find(V.VisitDate == dt, 1);
        sub = dir(folder); sub = sub([sub.isdir] & ~startsWith({sub.name}, '.'));
        for e = 1:2
            tag = '_Radial_R_'; eyeName = 'OD'; isLeft = false;
            if e == 2, tag = '_Radial_L_'; eyeName = 'OS'; isLeft = true; end
            ax = nexttile(tl);
            d = sub(contains({sub.name}, tag, 'IgnoreCase', true));
            if isempty(d)
                axis(ax, 'off'); title(ax, sprintf('(%c) %s %s: no scan', letter, eyeName, dateStr));
                letter = letter + 1; continue;
            end
            R = run_scan(fullfile(d(1).folder, d(1).name), options.ScanIndex, isLeft, options.MODEL);
            imagesc(ax, R.I); colormap(ax, gray); clim(ax, [0 255]); axis(ax, 'image', 'off'); hold(ax, 'on');
            masks = [R.M.Left, R.M.Right];
            for m = 1:numel(masks)
                h = image(ax, repmat(reshape(layerCols(mod(m - 1, 5) + 1, :), 1, 1, 3), R.sy, R.sx));
                h.AlphaData = 0.45 * double(masks{m}); h.HandleVisibility = 'off';
            end
            plot(ax, 1:R.sx, R.ILM, 'r-', 'LineWidth', 0.6, 'HandleVisibility', 'off');
            plot(ax, 1:R.sx, R.RPE_bot, 'm-', 'LineWidth', 0.6, 'HandleVisibility', 'off');
            if R.isHole
                bnd = bwboundaries(R.Hole);
                for b = 1:numel(bnd), plot(ax, bnd{b}(:, 2), bnd{b}(:, 1), 'w-', 'LineWidth', 0.9, 'HandleVisibility', 'off'); end
            end
            crt = NaN; day = NaN;
            if ~isempty(k)
                crt = V.(sprintf('CentralThickness_%s', eyeName))(k);
                day = days(V.VisitDate(k) - min(V.VisitDate));
            end
            fl = 'no fluid'; if R.isHole, fl = 'fluid'; end
            title(ax, sprintf('(%c) %s, %s (day %d), CRT %d \\mum, %s', letter, eyeName, ...
                  datestr(dt, 'dd.mm.yyyy'), round(day), round(crt), fl), 'FontWeight', 'normal', 'FontSize', 7); %#ok<DATST>
            letter = letter + 1;
        end
    end
    % Legend for the ROI colours
    for L = 1:5
        plot(ax, NaN, NaN, 's', 'MarkerFaceColor', layerCols(L, :), 'MarkerEdgeColor', 'none', ...
             'MarkerSize', 7, 'DisplayName', sprintf('L%d', L));
    end
    lg = legend(ax, 'Orientation', 'horizontal', 'TextColor', 'k', 'FontSize', 7);
    lg.Layout.Tile = 'south';

    base = fullfile(options.OutDir, 'res_visit_comparison');
    exportgraphics(f, [base '.png'], 'Resolution', 300);
    exportgraphics(f, [base '.pdf'], 'ContentType', 'image', 'Resolution', 300);
    close(f);
    fprintf('Saved %s.png / .pdf\n', base);
end

%% Same pipeline calls as process_oct_folder for one B-scan
function R = run_scan(folderPath, idx, isLeft, MODEL)
    files = list_bscans(folderPath);   % sorted by B-scan number
    figsBefore = findall(0, 'Type', 'figure');
    [I_orig, I, emb, sy, sx, ang, I_raw, geom] = preprocess_OCT(folderPath, files(idx).name, MODEL, isLeft);
    ILM = segment_ILM(I, MODEL, emb, sy, sx, 0);
    h1 = figure('Visible', 'off'); hold on;
    [isFound, Hole, MaxPH, indMaxPH, isReal] = detect_hole(I, MODEL, emb, sy, sx, ILM, 0, h1);
    [B1, B2, B3, B4, Inner, RPE_bot, RPE_top] = segment_layers(I, MODEL, sy, sx, MaxPH, indMaxPH, ILM, Hole, 0, h1);
    [~, ~, ~, M] = analyze_rois_fixed_width(I_orig, I, ang, isFound, Hole, sy, sx, B1, B2, B3, B4, ...
                                            Inner, RPE_bot, RPE_top, ILM, h1, I_raw, geom);
    delete(setdiff(findall(0, 'Type', 'figure'), figsBefore));
    R = struct('I', I, 'sy', sy, 'sx', sx, 'ILM', ILM, 'RPE_bot', RPE_bot, 'Hole', Hole, ...
               'isHole', isReal, 'M', M);
end
