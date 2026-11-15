function S = thesis_style(f, action)
% THESIS_STYLE Shared look of every thesis figure (sizes, fonts, colours).
%
%   S = thesis_style()             returns the settings
%   thesis_style(f)                prepares a new figure (white, light theme)
%   thesis_style(f, 'finish')      sets every text element of f to the thesis font size;
%                                  called by the save functions right before exporting
%
%   Figures are made at the width they are printed at (\textwidth = 14.5 cm for A4 with
%   3.25 cm side margins), so the font sizes below are the sizes in the printed thesis.
%   Include them with width=\textwidth unless the script says otherwise.
%
%   S.fs      - all figure text: titles, labels, ticks, legends, colour bars (pt)
%   S.fsSmall - only dense annotations: numbers inside heat-map cells and the tick labels
%               of the 30-variable correlation matrices (axes with Tag 'small')
%   S.OD/S.OS - colours of the two eyes (OD red, OS blue) in every figure
%   S.fluid   - colour of the fluid pocket (cyan) in every image overlay

    S.width   = 14.5;            % cm, \textwidth
    S.fs      = 10;              % pt
    S.fsSmall = 8;               % pt
    S.OD      = [0.80 0.25 0.20];
    S.OS      = [0.20 0.40 0.75];
    S.fluid   = [0 0.9 1];
    S.layerCols = [0.95 0.35 0.25; 0.98 0.75 0.15; 0.35 0.8 0.35; 0.25 0.65 0.95; 0.75 0.4 0.9];

    if nargin < 1, return; end
    if nargin < 2, action = 'new'; end
    switch action
        case 'new'
            if isprop(f, 'Theme'), f.Theme = 'light'; end   % white background, black text also in dark mode
            f.Color = 'w';
        case 'finish'
            for ax = findall(f, 'Type', 'axes')'
                fsA = S.fs; if strcmp(ax.Tag, 'small'), fsA = S.fsSmall; end
                set(ax, 'FontSize', fsA, 'TitleFontSizeMultiplier', 1, 'LabelFontSizeMultiplier', 1, ...
                        'TitleFontWeight', 'normal');
                % titles and axis labels stay at the full size, also on 'small' axes
                set([ax.Title, ax.XLabel, ax.YLabel, ax.Subtitle], 'FontSize', S.fs);
                if isprop(ax, 'ZLabel'), ax.ZLabel.FontSize = S.fs; end
            end
            set(findall(f, 'Type', 'legend'), 'FontSize', S.fs);
            set(findall(f, 'Type', 'colorbar'), 'FontSize', S.fs);
            set(findall(f, 'Type', 'constantline'), 'FontSize', S.fs);
            for tl = findall(f, 'Type', 'tiledlayout')'
                set(tl.Title, 'FontSize', S.fs, 'FontWeight', 'normal');
                set(tl.Subtitle, 'FontSize', S.fs);
            end
    end
end
