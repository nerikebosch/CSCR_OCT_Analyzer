function make_dataset_figures(dateFolder, outDir)
% MAKE_DATASET_FIGURES Figures for the dataset section of the thesis.
%
%   make_dataset_figures(dateFolder)          saves in ./figs
%   make_dataset_figures(dateFolder, outDir)
%
%   dateFolder - one visit folder that contains both an _R_ and an _L_ scan folder,
%                e.g. 'C:\School\Thesis\20251024'
%
%   Saves:
%     dataset_raw_OD_OS.png          first B-scan of OD and OS from that visit, as exported
%     dataset_central_thickness.png  central thickness of both eyes over the follow-up (+ .pdf)
%   The radial scan pattern figure is made by make_thesis_figures (02_scan_pattern).

    if nargin < 2, outDir = 'figs'; end
    if ~isfolder(outDir), mkdir(outDir); end

    %% Raw OD and OS B-scan of the same visit
    sub = dir(dateFolder); sub = sub([sub.isdir]);
    odDir = sub(contains({sub.name}, '_Radial_R_', 'IgnoreCase', true));
    osDir = sub(contains({sub.name}, '_Radial_L_', 'IgnoreCase', true));
    if isempty(odDir) || isempty(osDir), error('Need both an _R_ and an _L_ folder in %s', dateFolder); end
    [~, visitName] = fileparts(strip(dateFolder, 'right', filesep));

    f = newfig(24, 9);
    tl = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    dirs = {odDir(1), osDir(1)};
    names = {'OD (affected eye)', 'OS (fellow eye)'};
    for e = 1:2
        bmps = list_bscans(fullfile(dirs{e}.folder, dirs{e}.name));
        I = imread(fullfile(bmps(1).folder, bmps(1).name));
        if size(I, 3) == 3, I = rgb2gray(I); end
        ax = nexttile(tl);
        imagesc(ax, I); colormap(ax, gray); clim(ax, [0 255]); axis(ax, 'image', 'off');
        title(ax, sprintf('(%c) %s, B-scan 1 (%d \\times %d px)', 'a' + e - 1, names{e}, size(I, 2), size(I, 1)));
    end
    title(tl, sprintf('Visit %s', visitName), 'FontWeight', 'bold');
    exportgraphics(f, fullfile(outDir, 'dataset_raw_OD_OS.png'), 'Resolution', 300);
    close(f);

    %% Central thickness of both eyes over the follow-up
    V = db_manager('get_visits');
    V = sortrows(V, 'VisitDate');
    days = days_between(V.VisitDate(1), V.VisitDate);
    f = newfig(16, 8);
    ax = axes(f); hold(ax, 'on');
    plot(ax, days, V.CentralThickness_OD, '-o', 'Color', [0.8 0.25 0.2], 'MarkerFaceColor', [0.8 0.25 0.2], ...
         'MarkerSize', 4, 'LineWidth', 1.3, 'DisplayName', 'OD (affected)');
    plot(ax, days, V.CentralThickness_OS, '-s', 'Color', [0.2 0.4 0.75], 'MarkerFaceColor', [0.2 0.4 0.75], ...
         'MarkerSize', 4, 'LineWidth', 1.3, 'DisplayName', 'OS (fellow)');
    xlabel(ax, 'Days since first visit'); ylabel(ax, 'Central thickness (\mum)');
    legend(ax, 'Location', 'northwest'); grid(ax, 'on'); box(ax, 'on');
    xlim(ax, [0, max(days) + 10]);
    title(ax, sprintf('Central thickness at %d visits', height(V)));
    exportgraphics(f, fullfile(outDir, 'dataset_central_thickness.png'), 'Resolution', 300);
    exportgraphics(f, fullfile(outDir, 'dataset_central_thickness.pdf'), 'ContentType', 'vector');
    close(f);

    fprintf('Saved dataset figures in %s\n', outDir);
end

function d = days_between(t0, t)
    d = days(t - t0);
end

function f = newfig(w, h)
    f = figure('Visible', 'off', 'Units', 'centimeters', 'Position', [2 2 w h]);
    if isprop(f, 'Theme'), f.Theme = 'light'; end
    f.Color = 'w';
end
