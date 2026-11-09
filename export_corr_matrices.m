function export_corr_matrices(options)
% EXPORT_CORR_MATRICES Saves the per-ROI correlation matrices as figures for the thesis.
%
%   export_corr_matrices()            Spearman, legacy ROIs, saved in ./figures
%   export_corr_matrices(options)     with fields (all optional):
%       Method   - 'Spearman' (default) or 'Pearson'
%       RoiMode  - 'legacy' (default) or 'fw' (fixed-width ROIs)
%       Layers   - layer numbers to show, default 1:5
%       OutDir   - output folder, default 'figures'
%
%   Makes two figures, both with rows = eye (OD, OS) and columns = layer:
%       1) Right ROIs  ->  corr_matrix_Right_<method>_<mode>.png/.pdf
%       2) Left ROIs   ->  corr_matrix_Left_<method>_<mode>.png/.pdf
%
%   Same as the dashboard's Correlation Matrix tab: correlation across visits
%   (one value per visit = median of its scans), FDR over the unique pairs.
%   * p < 0.05   ** survives FDR (q < 0.05)   box = also |r| >= r_min (80% power)
%   Thesis page layouts (OD | OS per layer) are made by make_results_figures.

    if nargin < 1, options = struct(); end
    if ~isfield(options, 'Method'),  options.Method  = 'Spearman'; end
    if ~isfield(options, 'RoiMode'), options.RoiMode = 'legacy'; end
    if ~isfield(options, 'Layers'),  options.Layers  = 1:5; end
    if ~isfield(options, 'OutDir'),  options.OutDir  = 'figures'; end

    addpath(genpath(fullfile(fileparts(mfilename('fullpath')), 'stats_utils')));
    SummaryData = db_manager('get_summary');
    if isempty(SummaryData), error('The database has no summary data.'); end
    if ~isfolder(options.OutDir), mkdir(options.OutDir); end

    sfx = ''; if strcmp(options.RoiMode, 'fw'), sfx = '_fw'; end
    modeName = 'Legacy ROI'; if strcmp(options.RoiMode, 'fw'), modeName = 'Fixed-width ROI'; end
    eyes = {'OD', 'OS'};
    eyeNames = {'OD (diseased)', 'OS (fellow)'};

    nC = 128; cBlue = [0.2 0.4 0.75]; cRed = [0.8 0.25 0.2];
    corrCmap = [interp1([0 1], [cBlue; 1 1 1], linspace(0, 1, nC)); ...
                interp1([0 1], [1 1 1; cRed], linspace(0, 1, nC))];

    sides = {'Right', 'Left'};
    for s = 1:numel(sides)
        side = sides{s};
        nL = numel(options.Layers);

        fig = figure('Color', 'w', 'Units', 'centimeters', 'Position', [1 1 17*nL + 4 36], ...
                     'Name', sprintf('%s ROIs', side));
        tl = tiledlayout(fig, 2, nL, 'TileSpacing', 'compact', 'Padding', 'compact');
        title(tl, sprintf('%s ROIs  |  %s correlation across visits  |  %s', side, options.Method, modeName), ...
              'FontWeight', 'bold', 'Color', 'k');
        subtitle(tl, ['* p < 0.05     ** survives FDR (q < 0.05)     box = also |r| \geq r_{min} ' ...
                      '(80% power, \alpha = 0.05)     black lines separate morphology + thickness from speckle statistics'], ...
                 'Color', 'k');

        for e = 1:2
            for li = 1:nL
                ax = nexttile(tl);
                roi = sprintf('%s_L%d', side, options.Layers(li));
                [X, labels, nMorph] = corr_matrix_build(SummaryData, eyes{e}, roi, sfx);
                nVisits = corr_matrix_draw(ax, X, labels, nMorph, options.Method, corrCmap);
                title(ax, sprintf('%s  L%d  (n = %d)', eyeNames{e}, options.Layers(li), nVisits), ...
                      'FontWeight', 'bold', 'FontSize', 9, 'Color', 'k');
            end
        end
        cb = colorbar(ax);
        cb.Layout.Tile = 'east';
        cb.Label.String = sprintf('%s correlation', options.Method);
        cb.Color = 'k';

        baseName = fullfile(options.OutDir, sprintf('corr_matrix_%s_%s_%s', side, options.Method, options.RoiMode));
        exportgraphics(fig, [baseName '.png'], 'Resolution', 300);
        exportgraphics(fig, [baseName '.pdf'], 'ContentType', 'vector');
        fprintf('Saved %s.png / .pdf\n', baseName);
    end
end
