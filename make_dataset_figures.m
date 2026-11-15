function make_dataset_figures(dateFolder, outDir)
% MAKE_DATASET_FIGURES Figures for the dataset section of the thesis.
%
%   make_dataset_figures(dateFolder)          saves in ./figs
%   make_dataset_figures(dateFolder, outDir)
%
%   dateFolder - one visit folder that contains both an _R_ and an _L_ scan folder,
%                e.g. 'C:\School\Thesis\20251024'
%
%   Saves (.png and .pdf, all 14.5 cm wide = \textwidth, text at the thesis font size):
%     dataset_eyes               (a, b) schematic fundus of OD and OS as seen facing the patient
%                                (OD left, OS right) with the radial scan pattern, the processed
%                                B-scans 1, 2, 32 and the OD fluid; (c, d) B-scan 1 of each eye
%     dataset_raw_OD_OS          B-scan 1 of OD and OS as exported, with nasal/temporal labels
%     dataset_central_thickness  central thickness of both eyes over the follow-up
%
%   Every figure with both eyes shows OD on the left and OS on the right.

    if nargin < 2, outDir = 'figs'; end
    if ~isfolder(outDir), mkdir(outDir); end
    ST = thesis_style();
    W = ST.width;

    %% B-scan 1 of OD and OS of the same visit
    sub = dir(dateFolder); sub = sub([sub.isdir]);
    odDir = sub(contains({sub.name}, '_Radial_R_', 'IgnoreCase', true));
    osDir = sub(contains({sub.name}, '_Radial_L_', 'IgnoreCase', true));
    if isempty(odDir) || isempty(osDir), error('Need both an _R_ and an _L_ folder in %s', dateFolder); end
    dirs = {odDir(1), osDir(1)};
    I = cell(1, 2); nScans = zeros(1, 2);
    for e = 1:2
        bmps = list_bscans(fullfile(dirs{e}.folder, dirs{e}.name));
        nScans(e) = numel(bmps);
        I{e} = imread(fullfile(bmps(1).folder, bmps(1).name));
        if size(I{e}, 3) == 3, I{e} = rgb2gray(I{e}); end
    end
    ar = size(I{1}, 1) / size(I{1}, 2);
    tileW = (W - 0.2) / 2;
    eyeNames = {'OD (right eye, affected)', 'OS (left eye, fellow)'};

    %% dataset_eyes: fundus schematics (top) and B-scan 1 (bottom), OD left, OS right
    f = newfig(W, 2 * (tileW * ar + 0.55));
    tl = tiledlayout(f, 2, 2, 'TileSpacing', 'tight', 'Padding', 'tight');
    for e = 1:2
        ax = nexttile(tl);
        draw_fundus(ax, e == 1, nScans(e), ST);
        title(ax, sprintf('(%c) %s', 'a' + e - 1, eyeNames{e}));
    end
    for e = 1:2
        ax = nexttile(tl);
        show_bscan(ax, I{e}, e == 1, ST);
        title(ax, sprintf('(%c) %s, B-scan 1', 'c' + e - 1, eyeNames{e}(1:2)));
    end
    save_fig(f, fullfile(outDir, 'dataset_eyes'), 'image');

    %% dataset_raw_OD_OS: only the two B-scans
    f = newfig(W, tileW * ar + 0.55);
    tl = tiledlayout(f, 1, 2, 'TileSpacing', 'tight', 'Padding', 'tight');
    for e = 1:2
        ax = nexttile(tl);
        show_bscan(ax, I{e}, e == 1, ST);
        title(ax, sprintf('(%c) %s, B-scan 1', 'a' + e - 1, eyeNames{e}(1:2)));
    end
    save_fig(f, fullfile(outDir, 'dataset_raw_OD_OS'), 'image');

    %% Central thickness of both eyes over the follow-up
    V = db_manager('get_visits');
    V = sortrows(V, 'VisitDate');
    d = days(V.VisitDate - V.VisitDate(1));
    f = newfig(W, 7);
    ax = axes(f); hold(ax, 'on');
    plot(ax, d, V.CentralThickness_OD, '-o', 'Color', ST.OD, 'MarkerFaceColor', ST.OD, ...
         'MarkerSize', 4, 'LineWidth', 1.3, 'DisplayName', 'OD (affected)');
    plot(ax, d, V.CentralThickness_OS, '-s', 'Color', ST.OS, 'MarkerFaceColor', ST.OS, ...
         'MarkerSize', 4, 'LineWidth', 1.3, 'DisplayName', 'OS (fellow)');
    xlabel(ax, 'Days since first visit'); ylabel(ax, 'Central thickness (\mum)');
    legend(ax, 'Location', 'northwest', 'Box', 'off'); grid(ax, 'on'); box(ax, 'on');
    xlim(ax, [0, max(d) + 10]);
    save_fig(f, fullfile(outDir, 'dataset_central_thickness'), 'vector');

    fprintf('Saved dataset figures in %s\n', outDir);
end

%% Schematic fundus as seen when facing the patient: the optic disc is on the nasal side,
%  which is on the right for OD and on the left for OS
function draw_fundus(ax, isOD, nScans, ST)
    hold(ax, 'on');
    nas = 1; if ~isOD, nas = -1; end
    th = linspace(0, 2 * pi, 300);
    fill(ax, cos(th), sin(th), [0.97 0.82 0.70], 'EdgeColor', [0.45 0.3 0.25], 'LineWidth', 1);
    dx = nas * 0.80;                                  % optic disc centre
    t = linspace(0, 1, 100)';
    for s = [1 -1]                                    % upper and lower vessel arcade
        P0 = [dx, 0.06 * s]; P1 = [nas * 0.05, 0.85 * s]; P2 = [-nas * 0.88, 0.32 * s];
        B = (1 - t).^2 .* P0 + 2 * (1 - t) .* t .* P1 + t.^2 .* P2;
        plot(ax, B(:, 1), B(:, 2), '-', 'Color', [0.78 0.35 0.3], 'LineWidth', 1.4);
    end
    fill(ax, dx + 0.15 * cos(th), 0.18 * sin(th), [1 0.94 0.72], 'EdgeColor', [0.85 0.7 0.4]);
    fill(ax, 0.09 * cos(th), 0.09 * sin(th), [0.8 0.52 0.42], 'EdgeColor', 'none');   % fovea
    if isOD                                           % subretinal fluid around the fovea
        fill(ax, 0.30 * cos(th), 0.20 * sin(th), ST.fluid, 'FaceAlpha', 0.55, 'EdgeColor', ST.fluid);
    end
    % 32 radial B-scans of 9 mm (radius ~ distance fovea - disc edge), processed ones highlighted
    r = 0.62; sel = [1, 2, 32];
    for k = 1:32
        a = (k - 1) * pi / 32;
        if ~ismember(k, sel)
            plot(ax, r * [-cos(a) cos(a)], r * [-sin(a) sin(a)], '-', 'Color', [0.35 0.35 0.35], 'LineWidth', 0.3);
        end
    end
    for k = sel
        a = (k - 1) * pi / 32;
        plot(ax, r * [-cos(a) cos(a)], r * [-sin(a) sin(a)], 'k-', 'LineWidth', 1.4);
    end
    text(ax, nas * 1.1, 0, 'N', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    text(ax, -nas * 1.1, 0, 'T', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    axis(ax, 'equal', 'off'); xlim(ax, [-1.2 1.2]); ylim(ax, [-1.02 1.02]);
    if nScans ~= 32
        fprintf('Note: %d B-scans in this acquisition; the schematic shows 32.\n', nScans);
    end
end

%% B-scan as exported, with the nasal (N) and temporal (T) side marked
function show_bscan(ax, I, isOD, ST)
    imagesc(ax, I); colormap(ax, gray); clim(ax, [0 255]); axis(ax, 'image', 'off'); hold(ax, 'on');
    lr = {'T', 'N'}; if ~isOD, lr = {'N', 'T'}; end
    sx = size(I, 2); m = 0.04 * sx;
    text(ax, m, m, lr{1}, 'Color', 'w', 'FontWeight', 'bold', 'FontSize', ST.fs, 'VerticalAlignment', 'top');
    text(ax, sx - m, m, lr{2}, 'Color', 'w', 'FontWeight', 'bold', 'FontSize', ST.fs, ...
         'VerticalAlignment', 'top', 'HorizontalAlignment', 'right');
end

function f = newfig(w, h)
    f = figure('Visible', 'off', 'Units', 'centimeters', 'Position', [2 2 w h]);
    thesis_style(f);
end

function save_fig(f, base, content)
    thesis_style(f, 'finish');
    exportgraphics(f, [base '.png'], 'Resolution', 300);
    if strcmp(content, 'vector')
        exportgraphics(f, [base '.pdf'], 'ContentType', 'vector');
    else
        exportgraphics(f, [base '.pdf'], 'ContentType', 'image', 'Resolution', 300);
    end
    close(f);
    fprintf('Saved %s.png / .pdf\n', base);
end
