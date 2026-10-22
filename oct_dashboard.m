function oct_dashboard()
% OCT_DASHBOARD Interactive MATLAB UI Dashboard for Longitudinal OCT Analysis.
% Displays temporal evolution of speckle contrast ratios, rates of change,
% central retinal thickness, and clinical correlations for patient CSCR_M_011.
%
% USAGE:
%   oct_dashboard()
    % Ensure DB is initialized
    db_manager('init');
    % Create Main Window
    fig = uifigure('Name', 'OCT Clinical Study Dashboard | CSCR Longitudinal Study', ...
                   'Position', [80, 60, 1280, 780], ...
                   'Color', [0.95 0.96 0.98]);
    % Main Layout Grid: 2 rows (Header, Content)
    mainGrid = uigridlayout(fig, [2, 1]);
    mainGrid.RowHeight = {55, '1x'};
    mainGrid.Padding = [10, 10, 10, 10];
    mainGrid.RowSpacing = 8;
    %% Header Bar
    headerPanel = uipanel(mainGrid, 'BackgroundColor', [0.15 0.22 0.35], 'BorderType', 'none');
    headerGrid = uigridlayout(headerPanel, [1, 6]); % 6 columns
    headerGrid.ColumnWidth = {'1x', 180, 160, 140, 130, 110};
    headerGrid.Padding = [12, 6, 12, 6];
    
    titleLabel = uilabel(headerGrid, ...
        'Text', 'OCT Clinical Study Dashboard  |  Patient CSCR_M_011', ...
        'FontSize', 16, 'FontWeight', 'bold', 'FontColor', [1 1 1]);
       
    ddEyeSelect = uidropdown(headerGrid, 'Items', {'Right Eye (OD - Diseased)', 'Left Eye (OS - Healthy)'}, ...
        'ItemsData', {'OD', 'OS'}, 'FontWeight', 'bold', ...
        'ValueChangedFcn', @(~,~) refresh_all_data());

    ddRoiMode = uidropdown(headerGrid, 'Items', {'Legacy ROI (Wide)', 'Fixed-Width ROI (120px)'}, ...
        'ItemsData', {'legacy', 'fw'}, 'FontWeight', 'bold', ...
        'ValueChangedFcn', @(~,~) refresh_all_data());
        
    btnProcess = uibutton(headerGrid, 'push', 'Text', '+ Process Folder', ...
        'BackgroundColor', [0.2 0.6 0.35], 'FontColor', [1 1 1], 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(~,~) on_process_folder());
    btnExport = uibutton(headerGrid, 'push', ...
        'Text', 'Export Excel', ...
        'BackgroundColor', [0.25 0.45 0.7], 'FontColor', [1 1 1], 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(~,~) on_export_excel());
    btnRefresh = uibutton(headerGrid, 'push', ...
        'Text', 'Refresh', ...
        'BackgroundColor', [0.3 0.35 0.45], 'FontColor', [1 1 1], ...
        'ButtonPushedFcn', @(~,~) refresh_all_data());
    %% Content Area Grid (Left: Sidebar, Right: Tabs)
    contentGrid = uigridlayout(mainGrid, [1, 2]);
    contentGrid.ColumnWidth = {330, '1x'};
    contentGrid.Padding = [0, 0, 0, 0];
    contentGrid.ColumnSpacing = 10;
    %% Left Sidebar: Visit Details & Editor
    sidePanel = uipanel(contentGrid, 'Title', 'Visit & Clinical Details', ...
                        'FontSize', 12, 'FontWeight', 'bold', ...
                        'BackgroundColor', [1 1 1]);
    sideGrid = uigridlayout(sidePanel, [9, 2]);
    sideGrid.RowHeight = {28, 28, 28, 28, 28, '1x', 34, 34, 22};
    sideGrid.ColumnWidth = {110, '1x'};
    sideGrid.Padding = [10, 10, 10, 10];
    sideGrid.RowSpacing = 8;
    % Visit Selector
    uilabel(sideGrid, 'Text', 'Select Visit:', 'FontWeight', 'bold');
    ddVisit = uidropdown(sideGrid, 'Items', {'Visit 1'}, 'ValueChangedFcn', @(~,~) on_visit_selected());
    % Visit Date
    uilabel(sideGrid, 'Text', 'Visit Date:');
    lblDate = uilabel(sideGrid, 'Text', '2024-06-03', 'FontColor', [0.2 0.3 0.6], 'FontWeight', 'bold');
    % Days from Baseline
    uilabel(sideGrid, 'Text', 'Days from Base:');
    lblDays = uilabel(sideGrid, 'Text', '0 days');
    % Central Thickness OD
    uilabel(sideGrid, 'Text', 'Thickness OD (\mum):');
    efThicknessOD = uieditfield(sideGrid, 'numeric', 'Value', 282, 'RoundFractionalValues', 'on');
    % Central Thickness OS
    uilabel(sideGrid, 'Text', 'Thickness OS (\mum):');
    efThicknessOS = uieditfield(sideGrid, 'numeric', 'Value', 248, 'RoundFractionalValues', 'on');
    % Notes
    uilabel(sideGrid, 'Text', 'Clinical Notes:');
    taNotes = uitextarea(sideGrid, 'Value', {''});
    % Save Visit Button
    btnSaveVisit = uibutton(sideGrid, 'push', ...
        'Text', 'Save Visit Changes', ...
        'BackgroundColor', [0.15 0.45 0.75], 'FontColor', [1 1 1], 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(~,~) on_save_visit());
    btnSaveVisit.Layout.Column = [1 2];
    % Add New Visit Button
    btnAddVisit = uibutton(sideGrid, 'push', ...
        'Text', '+ Add New Visit (e.g. Visit 23)', ...
        'BackgroundColor', [0.3 0.5 0.35], 'FontColor', [1 1 1], ...
        'ButtonPushedFcn', @(~,~) on_add_new_visit());
    btnAddVisit.Layout.Column = [1 2];
    lblDbStatus = uilabel(sideGrid, 'Text', 'Database: Connected', 'FontSize', 9, 'FontColor', [0.4 0.4 0.4]);
    lblDbStatus.Layout.Column = [1 2];

    %% Right Area: Tab Group
    tabGroup = uitabgroup(contentGrid);
    % Tab 1: Longitudinal Trends
    tabTrends = uitab(tabGroup, 'Title', 'Longitudinal Trends & Evolution');
    gridTrends = uigridlayout(tabTrends, [3, 1]);
    gridTrends.RowHeight = {30, '1x', '1x'};
    gridTrends.Padding = [8, 8, 8, 8];
    gridTrends.RowSpacing = 6;
    % Controls row for Tab 1
    tControlsPanel = uipanel(gridTrends, 'BorderType', 'none');
    tControlsGrid = uigridlayout(tControlsPanel, [1, 4]);
    tControlsGrid.ColumnWidth = {180, 200, 160, '1x'};
    tControlsGrid.Padding = [0, 0, 0, 0];
    cbZones = uicheckbox(tControlsGrid, 'Text', 'Show Clinical Zones', 'Value', true, ...
                         'ValueChangedFcn', @(~,~) render_longitudinal_plot());
    cbThickness = uicheckbox(tControlsGrid, 'Text', 'Overlay Central Thickness', 'Value', true, ...
                            'ValueChangedFcn', @(~,~) render_longitudinal_plot());
    cbErrorBars = uicheckbox(tControlsGrid, 'Text', 'Show Error Bars (\pm \sigma)', 'Value', true, ...
                            'ValueChangedFcn', @(~,~) render_longitudinal_plot());
    % Axes 1: Dual Axis Plot (L4/L5 Ratio vs Central Thickness)
    axEvolution = uiaxes(gridTrends);
    axEvolution.FontSize = 10;
    % Axes 2: Rate of Change Bar Chart
    axVelocity = uiaxes(gridTrends);
    axVelocity.FontSize = 10;
    
    % Tab 2: Clinical Correlations
    tabCorr = uitab(tabGroup, 'Title', 'Thickness vs. Speckle Correlations');
    gridCorr = uigridlayout(tabCorr, [3, 1]);
    gridCorr.RowHeight = {40, '1x', 140};
    gridCorr.Padding = [10, 10, 10, 10];
    
    % Dropdown to select which layer/ratio to correlate
    panelDropdown = uipanel(gridCorr, 'BorderType', 'none');
    
    lblDrop = uilabel(panelDropdown, 'Text', 'Select Metric to Correlate:', 'Position', [10, 10, 180, 22], 'FontWeight', 'bold');
    ddCorrMetric = uidropdown(panelDropdown, 'Position', [195, 10, 280, 22], ...
        'ValueChangedFcn', @(~,~) on_metric_changed());
        
    axCorr = uiaxes(gridCorr);
    axCorr.FontSize = 11;
    panelCorrSummary = uipanel(gridCorr, 'Title', 'Correlation Analysis Findings', 'FontSize', 11, 'FontWeight', 'bold');
    gridCorrText = uigridlayout(panelCorrSummary, [2, 3]);
    gridCorrText.RowHeight = {28, 28};
    gridCorrText.ColumnWidth = {'1x', '1x', '1x'};
    lblPearson = uilabel(gridCorrText, 'Text', 'Pearson r: --', 'FontWeight', 'bold', 'FontSize', 12);
    lblSpearman = uilabel(gridCorrText, 'Text', 'Spearman \rho: --', 'FontWeight', 'bold', 'FontSize', 12);
    lblR2 = uilabel(gridCorrText, 'Text', 'Linear R^2: --', 'FontWeight', 'bold', 'FontSize', 12);
    lblSignif = uilabel(gridCorrText, 'Text', 'Significance: --', 'FontColor', [0.2 0.5 0.2], 'FontWeight', 'bold');
    lblAnalyzedN = uilabel(gridCorrText, 'Text', 'Analyzed Visits: --');
    uilabel(gridCorrText, 'Text', 'Condition: CSCR Flare vs Remission', 'FontColor', [0.4 0.4 0.4]);
    
    % Tab 3: Complete Database Table View
    tabTable = uitab(tabGroup, 'Title', 'All Visits Data Table');
    gridTable = uigridlayout(tabTable, [1, 1]);
    gridTable.Padding = [8, 8, 8, 8];
    tblAllVisits = uitable(gridTable, 'FontSize', 10);
    tblAllVisits.CellSelectionCallback = @(~, e) on_table_cell_selected(e);

    % Tab 4: Texture Distribution Curves (PDF Viewer)
    tabDist = uitab(tabGroup, 'Title', 'Texture Distributions (PDFs)');
    gridDist = uigridlayout(tabDist, [2, 1]);
    gridDist.RowHeight = {40, '1x'};
    gridDist.Padding = [10, 10, 10, 10];
    
    distControlPanel = uipanel(gridDist, 'BorderType', 'none');
    distControlGrid = uigridlayout(distControlPanel, [1, 3]);
    distControlGrid.ColumnWidth = {250, 250, '1x'};
    distControlGrid.Padding = [0,0,0,0];
    
    uilabel(distControlGrid, 'Text', 'Select Layer to Visualize:', 'FontWeight', 'bold');
    ddDistLayer = uidropdown(distControlGrid, ...
        'Items', {'Left L1', 'Left L2', 'Left L3', 'Left L4', 'Left L5', 'Right L1', 'Right L2', 'Right L3', 'Right L4', 'Right L5'}, ...
        'ItemsData', {'Left_L1', 'Left_L2', 'Left_L3', 'Left_L4', 'Left_L5', 'Right_L1', 'Right_L2', 'Right_L3', 'Right_L4', 'Right_L5'}, ...
        'ValueChangedFcn', @(~,~) render_distribution_plot());
        
    axDist = uiaxes(gridDist);
    axDist.FontSize = 11;
    %% Initialize & Load Data
    SummaryData = [];
    VisitsData  = [];
    ScansData   = [];
    refresh_all_data();
    %% Nested Event Callbacks
    function refresh_all_data()
        compute_statistics('update_all');
        SummaryData = db_manager('get_summary'); % Removed targetEye here
        VisitsData  = db_manager('get_visits');
        ScansData   = db_manager('get_scans');
        
        if isempty(SummaryData)
            uialert(fig, 'No study data found in database.', 'Empty Database');
            return;
        end
        
        % Update Visit Dropdown
        visitItems = cell(height(VisitsData), 1);
        for v = 1:height(VisitsData)
            visitItems{v} = sprintf('Visit %d (%s)', ...
                VisitsData.VisitNum(v), datestr(VisitsData.VisitDate(v), 'yyyy-mm-dd'));
        end
        ddVisit.Items = visitItems;
        ddVisit.Value = visitItems{end}; % Default to last visit
        on_visit_selected();
        
        % Populate the metric dropdown, which will automatically trigger the plots
        update_metric_dropdown();
        render_all_visits_table();
        
        lblDbStatus.Text = sprintf('Database: %d Visits | %d Scans | Updated %s', ...
            height(VisitsData), height(ScansData), datestr(now, 'HH:MM:SS'));
    end

    function on_metric_changed()
        render_correlation_plot();
        render_longitudinal_plot();
    end

    function update_metric_dropdown()
        eye = char(ddEyeSelect.Value); % 'OD' or 'OS'
        mode = char(ddRoiMode.Value);  % 'legacy' or 'fw'
        sfx = '';
        if strcmp(mode, 'fw')
            sfx = '_fw';
        end
        
        curr_val = char(ddCorrMetric.Value);
        
        % DYNAMICALLY BUILD THE DROPDOWN TO INCLUDE TEXTURES
        dispNames = {};
        dbVars = {};
        
        for side = ["Left", "Right"]
            % 1. Standard CR Ratios
            dispNames{end+1} = sprintf('%s ROI: CR Ratio L3/L4', side); dbVars{end+1} = sprintf('Median_%s_%s_Ratio_L3_L4%s', eye, side, sfx);
            dispNames{end+1} = sprintf('%s ROI: CR Ratio L4/L5', side); dbVars{end+1} = sprintf('Median_%s_%s_Ratio_L4_L5%s', eye, side, sfx);
            
            % 2. Loop through all 5 layers to add CR, Densito, Gamma, Nakagami
            for L = 1:5
                % Speckle Contrast (CR)
                dispNames{end+1} = sprintf('%s ROI: Contrast (CR) L%d', side, L);
                dbVars{end+1} = sprintf('Median_%s_%s_L%d%s', eye, side, L, sfx);
                
                % Densitometry (Mean Intensity)
                dispNames{end+1} = sprintf('%s ROI: Densitometry L%d', side, L);
                dbVars{end+1} = sprintf('Median_%s_%s_L%d_Densito%s', eye, side, L, sfx);
                
                % Gamma Shape Parameter
                dispNames{end+1} = sprintf('%s ROI: Gamma Shape L%d', side, L);
                dbVars{end+1} = sprintf('Median_%s_%s_L%d_GAM%s', eye, side, L, sfx);
                
                % Nakagami Mu
                dispNames{end+1} = sprintf('%s ROI: Nakagami \\mu L%d', side, L);
                dbVars{end+1} = sprintf('Median_%s_%s_L%d_NK%s', eye, side, L, sfx);
            end
        end
        
        ddCorrMetric.Items = dispNames;
        ddCorrMetric.ItemsData = dbVars;
        
        % Reconstruct their selection for the new mode/eye
        if isempty(curr_val)
            ddCorrMetric.Value = sprintf('Median_%s_Left_Ratio_L4_L5%s', eye, sfx); 
        else
            core_metric = strrep(strrep(strrep(curr_val, 'OD_', ''), 'OS_', ''), '_fw', '');
            new_target = strrep(core_metric, 'Median_', sprintf('Median_%s_', eye));
            new_target = [new_target, sfx];
            
            if ismember(new_target, dbVars)
                ddCorrMetric.Value = new_target;
            else
                ddCorrMetric.Value = sprintf('Median_%s_Left_Ratio_L4_L5%s', eye, sfx); 
            end
        end
        on_metric_changed();
    end

function render_distribution_plot()
        if isempty(ScansData), return; end
        cla(axDist);
        
        % Get the target data from the UI selections
        eye = char(ddEyeSelect.Value);
        mode = char(ddRoiMode.Value);
        sfx = ''; if strcmp(mode, 'fw'), sfx = '_fw'; end
        layer_selection = char(ddDistLayer.Value); % e.g., 'Left_L4'
        
        % Get the current visit number
        tok = regexp(ddVisit.Value, 'Visit (\d+)', 'tokens');
        if isempty(tok), return; end
        currVisitNum = str2double(tok{1}{1});
        
        % Find the row in the Scans Database
        % We take the FIRST slice (ImageIndex = 1) for the distribution visualization
        scanRow = ScansData(ScansData.VisitNum == currVisitNum & ScansData.EyeSide == eye & ScansData.ImageIndex == 1, :);
        if isempty(scanRow)
            title(axDist, 'No scan data available for this visit/eye combination.', 'FontWeight', 'normal');
            return;
        end
        
        % Extract the parameters for the selected layer
        base_col = sprintf('ROI_%s', layer_selection); % e.g. 'ROI_Left_L4'
        try
            gam_a = scanRow.(sprintf('%s_GAM_A%s', base_col, sfx))(1);
            gam_b = scanRow.(sprintf('%s_GAM_B%s', base_col, sfx))(1);
            nk_mu = scanRow.(sprintf('%s_NK_mu%s', base_col, sfx))(1);
            nk_om = scanRow.(sprintf('%s_NK_om%s', base_col, sfx))(1);
            exp_mu = scanRow.(sprintf('%s_EXP%s', base_col, sfx))(1);
            ray_b = scanRow.(sprintf('%s_RAY%s', base_col, sfx))(1);
            wbl_a = scanRow.(sprintf('%s_WBL_A%s', base_col, sfx))(1);
            wbl_b = scanRow.(sprintf('%s_WBL_B%s', base_col, sfx))(1);
        catch
            title(axDist, 'Missing parameter data. Please re-run batch processing.', 'Color', 'red');
            return;
        end
        
        if isnan(gam_a)
            title(axDist, 'Layer data is NaN (tissue not found in this scan).');
            return;
        end
        
        % Generate the X-axis mathematically based on the Gamma mean
        dist_mean = gam_a * gam_b;
        dist_std = sqrt(gam_a * (gam_b^2));
        x_max = dist_mean + (4 * dist_std);
        x = linspace(0.001, x_max, 1000);
        
        % Calculate all the PDF curves
        pdf_gam = gampdf(x, gam_a, gam_b);
        pdf_exp = exppdf(x, exp_mu);
        pdf_ray = raylpdf(x, ray_b);
        pdf_wbl = wblpdf(x, wbl_a, wbl_b);
        pd_nk = makedist('Nakagami', nk_mu, nk_om);
        pdf_nk = pdf(pd_nk, x);
        
        % Plot them all on one graph
        hold(axDist, 'on');
        plot(axDist, x, pdf_gam, 'LineWidth', 2.5, 'Color', [0.8 0.2 0.2], 'DisplayName', 'Gamma Distribution');
        plot(axDist, x, pdf_nk, 'LineWidth', 2, 'Color', [0.2 0.6 0.2], 'LineStyle', '--', 'DisplayName', 'Nakagami Distribution');
        plot(axDist, x, pdf_ray, 'LineWidth', 1.5, 'Color', [0.2 0.2 0.8], 'DisplayName', 'Rayleigh Distribution');
        plot(axDist, x, pdf_wbl, 'LineWidth', 1.5, 'Color', [0.8 0.5 0.1], 'DisplayName', 'Weibull Distribution');
        plot(axDist, x, pdf_exp, 'LineWidth', 1, 'Color', [0.4 0.4 0.4], 'LineStyle', ':', 'DisplayName', 'Exponential (Reference)');
        hold(axDist, 'off');
        
        % 7. Format the graph beautifully
        title(axDist, sprintf('Texture Distributions for %s | Visit %d (%s)', strrep(layer_selection, '_', ' '), currVisitNum, eye), 'FontWeight', 'bold', 'FontSize', 14);
        xlabel(axDist, 'Transformed Pixel Intensity', 'FontWeight', 'bold');
        ylabel(axDist, 'Probability Density', 'FontWeight', 'bold');
        grid(axDist, 'on'); box(axDist, 'on');
        legend(axDist, 'Location', 'northeast', 'FontSize', 11);
    end

    function on_visit_selected()
        if isempty(VisitsData), return; end
        vIdx = ddVisit.Value;
        tok = regexp(vIdx, 'Visit (\d+)', 'tokens');
        if isempty(tok), return; end
        currVisitNum = str2double(tok{1}{1});
        rowIdx = find(VisitsData.VisitNum == currVisitNum, 1);
        if isempty(rowIdx), return; end
        vRow = VisitsData(rowIdx, :);
        
        lblDate.Text = datestr(vRow.VisitDate, 'yyyy-mm-dd');
        lblDays.Text = sprintf('%.0f days', vRow.DaysFromBaseline);
        
        % Safely handle NaN thickness values for UI
        thOD = vRow.CentralThickness_OD; if isnan(thOD), thOD = 0; end
        thOS = vRow.CentralThickness_OS; if isnan(thOS), thOS = 0; end
        efThicknessOD.Value = thOD;
        efThicknessOS.Value = thOS;
        
        taNotes.Value = {char(vRow.Notes)};
        render_distribution_plot();
    end

    function on_save_visit()
        tok = regexp(ddVisit.Value, 'Visit (\d+)', 'tokens');
        if isempty(tok), return; end
        vNum = str2double(tok{1}{1});
        rowIdx = find(VisitsData.VisitNum == vNum, 1);
        if isempty(rowIdx), return; end
        vStruct = struct();
        vStruct.VisitNum = vNum;
        vStruct.VisitDate = VisitsData.VisitDate(rowIdx);
        vStruct.CentralThickness_OD = efThicknessOD.Value;
        vStruct.CentralThickness_OS = efThicknessOS.Value;
        notesCell = taNotes.Value;
        vStruct.Notes = strjoin(notesCell, ' ');
        db_manager('save_visit', vStruct);
        refresh_all_data();
        uialert(fig, sprintf('Successfully saved updates for Visit %d.', vNum), 'Saved', 'Icon', 'success');
    end
    function on_add_new_visit()
        nextNum = max(VisitsData.VisitNum) + 1;
        prompt = {sprintf('Enter Visit Number [Default: %d]:', nextNum), ...
                  'Enter Visit Date (YYYY-MM-DD):', ...
                  'Central Thickness OD (um):', ...
                  'Central Thickness OS (um):', ...
                  'Clinical Notes:'};
        dlgtitle = 'Add New Clinical Visit';
        dims = [1 45];
        definput = {num2str(nextNum), datestr(today, 'yyyy-mm-dd'), '300', '250', ''};
        answer = inputdlg(prompt, dlgtitle, dims, definput);
        if isempty(answer), return; end
        try
            newV = struct();
            newV.VisitNum = str2double(answer{1});
            newV.VisitDate = datetime(answer{2}, 'InputFormat', 'yyyy-MM-dd');
            newV.CentralThickness_OD = str2double(answer{3});
            newV.CentralThickness_OS = str2double(answer{4});
            newV.Notes = answer{5};
            db_manager('save_visit', newV);
            refresh_all_data();
            uialert(fig, sprintf('Visit #%d added to database!', newV.VisitNum), 'Success', 'Icon', 'success');
        catch ME
            uialert(fig, sprintf('Failed to add visit: %s', ME.message), 'Error', 'Icon', 'error');
        end
    end
    function on_process_folder()
        fPath = uigetdir('', 'Select OCT scan folder for a visit');
        if fPath == 0, return; end
        d = uiprogressdlg(fig, 'Title', 'Processing OCT Scans', ...
                          'Message', 'Running SAM segmentation pipeline...', ...
                          'Indeterminate', 'on');
        try
            opts = struct('plotoption', 1);
            vNum = process_oct_folder(fPath, opts);
            close(d);
            refresh_all_data();
            uialert(fig, sprintf('Folder processed successfully and assigned to Visit #%d!', vNum), ...
                    'Complete', 'Icon', 'success');
        catch ME
            close(d);
            uialert(fig, sprintf('Scan processing failed: %s', ME.message), 'Processing Error', 'Icon', 'error');
        end
    end
    function on_export_excel()
        [file, path] = uiputfile('*.xlsx', 'Save Consolidated Study Excel Report', 'OCT_Study_Export.xlsx');
        if file == 0, return; end
        fullP = fullfile(path, file);
        db_manager('export_excel', fullP);
        uialert(fig, sprintf('Excel report exported to: %s', fullP), 'Export Complete', 'Icon', 'success');
    end
    function on_table_cell_selected(e)
        if isempty(e.Indices), return; end
        selRow = e.Indices(1);
        if selRow <= length(ddVisit.Items)
            ddVisit.Value = ddVisit.Items{selRow};
            on_visit_selected();
        end
    end
    %% Visual Rendering Functions
    function render_longitudinal_plot()
        if isempty(SummaryData), return; end
        
        % Explicitly clear BOTH sides of the dual-axis plot
        yyaxis(axEvolution, 'left');
        cla(axEvolution);
        yyaxis(axEvolution, 'right');
        cla(axEvolution);
        
        % Clear the bottom velocity chart
        cla(axVelocity);

        visits = SummaryData.VisitNum;
        dates  = SummaryData.VisitDate;
        
        % Get the currently selected metric from the dropdown!
        selected_metric = ddCorrMetric.Value;
        
        % Secure fallback for selected metric
        if ismember(selected_metric, SummaryData.Properties.VariableNames)
            ratio_mean = SummaryData.(selected_metric);
        else
            ratio_mean = zeros(height(SummaryData), 1);
        end
        
        % Standard deviation is currently unused, set to 0
        ratio_std = zeros(height(SummaryData), 1);
        if ddEyeSelect.Value == "OD"
            th_data = SummaryData.CentralThickness_OD;
            thickness_label = 'Central Thickness OD (\mum)';
        else
            th_data = SummaryData.CentralThickness_OS;
            thickness_label = 'Central Thickness OS (\mum)';
        end
        
        % DYNAMIC RATE OF CHANGE CALCULATION
        % Calculate velocity based on whatever metric is currently selected
        roc = zeros(length(visits), 1);
        for b = 2:length(visits)
            dtDays = double(days(dates(b) - dates(b-1)));
            if dtDays > 0 && ~isnan(ratio_mean(b)) && ~isnan(ratio_mean(b-1))
                roc(b) = (ratio_mean(b) - ratio_mean(b-1)) / dtDays;
            end
        end
        
        xLimits = [min(visits)-0.5, max(visits)+0.5];
        hold(axEvolution, 'on');
        
        % Background Clinical Bands
        if cbZones.Value
            patch(axEvolution, [xLimits(1), xLimits(2), xLimits(2), xLimits(1)], [0.4, 0.4, 0.75, 0.75], ...
                [1 0.9 0.9], 'EdgeColor', 'none', 'FaceAlpha', 0.6, 'HandleVisibility', 'off');
            patch(axEvolution, [xLimits(1), xLimits(2), xLimits(2), xLimits(1)], [0.75, 0.75, 0.95, 0.95], ...
                [1 1 0.88], 'EdgeColor', 'none', 'FaceAlpha', 0.6, 'HandleVisibility', 'off');
            patch(axEvolution, [xLimits(1), xLimits(2), xLimits(2), xLimits(1)], [0.95, 0.95, 1.4, 1.4], ...
                [0.9 1 0.9], 'EdgeColor', 'none', 'FaceAlpha', 0.6, 'HandleVisibility', 'off');
        end
        
        % Left Axis: Selected Metric
        yyaxis(axEvolution, 'left');
        hEB = plot(axEvolution, visits, ratio_mean, 'o-', ...
            'Color', [0.15 0.3 0.75], 'MarkerSize', 6, 'MarkerFaceColor', [0.35 0.55 0.95], ...
            'LineWidth', 1.8, 'DisplayName', strrep(selected_metric, '_', ' '));
            
        ylabel(axEvolution, strrep(selected_metric, '_', ' '), 'FontWeight', 'bold');
        
        % Safely set y-limits to fit the data
        if max(ratio_mean) > 0
            ylim(axEvolution, [min(ratio_mean)*0.8, max(ratio_mean)*1.2]);
        end
        
        % Right Axis: Central Thickness OD
        yyaxis(axEvolution, 'right');
        if cbThickness.Value
            validTh = ~isnan(th_data);
            if any(validTh)
                plot(axEvolution, visits(validTh), th_data(validTh), 's--', ...
                    'Color', [0.85 0.35 0.1], 'MarkerSize', 6, 'MarkerFaceColor', [1 0.65 0.35], ...
                    'LineWidth', 1.5, 'DisplayName', thickness_label);
                ylabel(axEvolution, thickness_label, 'FontWeight', 'bold');
                ylim(axEvolution, [min(th_data(validTh))-30, max(th_data(validTh))+40]);
            end
        else
            ylabel(axEvolution, '');
            set(axEvolution, 'YTick', []);
        end
        title(axEvolution, ['Temporal Evolution: ', strrep(selected_metric, '_', ' '), ' vs. Central Retinal Thickness'], 'FontWeight', 'bold');
        xlim(axEvolution, xLimits);
        xticks(axEvolution, visits);
        grid(axEvolution, 'on');
        legend(axEvolution, 'Location', 'northwest');
        hold(axEvolution, 'off');
        
        % Rate of Change Velocity Bar Chart (Bottom Axes)
        hold(axVelocity, 'on');
        plot(axVelocity, xLimits, [0 0], 'k--', 'LineWidth', 1, 'HandleVisibility', 'off');
        barColors = zeros(length(visits), 3);
        for b = 1:length(visits)
            if roc(b) >= 0
                barColors(b, :) = [0.2 0.7 0.3];
            else
                barColors(b, :) = [0.85 0.25 0.25];
            end
        end
        bHandle = bar(axVelocity, visits, roc, 0.6, 'FaceColor', 'flat');
        bHandle.CData = barColors;
        ylabel(axVelocity, '\Delta Value / \Delta Day', 'FontWeight', 'bold');
        xlabel(axVelocity, 'Clinical Visit Date', 'FontWeight', 'bold');
        title(axVelocity, ['Rate of Change Velocity for ', strrep(selected_metric, '_', ' ')], 'FontWeight', 'bold');
        xlim(axVelocity, xLimits);
        xticks(axVelocity, visits);
        dateLabels = cellstr(datestr(dates, 'dd-mmm-yy'));
        set(axVelocity, 'XTickLabel', dateLabels, 'XTickLabelRotation', 40);
        grid(axVelocity, 'on');
        hold(axVelocity, 'off');
    end

    function render_all_visits_table()
        if isempty(SummaryData), return; end
        
        currEye = string(ddEyeSelect.Value);
        thCol  = sprintf('CentralThickness_%s', currEye);
        l4Col  = sprintf('Median_%s_Left_L4', currEye);
        ratCol = sprintf('Median_%s_Left_Ratio_L4_L5', currEye);
        rocCol = sprintf('Median_%s_Left_RateOfChange', currEye);

        desiredCols = {'VisitNum', 'VisitDate', 'DaysFromBaseline', ...
                       thCol, l4Col, ratCol, rocCol, 'Notes'};
                       
        actualCols = desiredCols(ismember(desiredCols, SummaryData.Properties.VariableNames));
        
        displayT = SummaryData(:, actualCols);
        tblAllVisits.Data = displayT;
    end
    function render_correlation_plot()
        if isempty(SummaryData), return; end
        cla(axCorr);
        
        % Get the metric chosen by the user in the dropdown
        selected_metric = ddCorrMetric.Value;
        
        % Compute correlation for this specific metric
        targetEye = string(ddEyeSelect.Value); 
        corrs = compute_statistics('correlations', selected_metric, targetEye);
        
        if targetEye == "OD"
            th_all = SummaryData.CentralThickness_OD;
            th_label = 'Central Retinal Thickness OD (\mum)';
        else
            th_all = SummaryData.CentralThickness_OS;
            th_label = 'Central Retinal Thickness OS (\mum)';
        end

        valid = ~isnan(th_all) & ~isnan(SummaryData.(selected_metric));
        xMetric = SummaryData.(selected_metric)(valid);
        yTh = th_all(valid);
        metric_label = strrep(selected_metric, '_', ' ');
        
        hold(axCorr, 'on');
        scatter(axCorr, xMetric, yTh, 55, [0.2 0.4 0.75], 'filled', 'MarkerEdgeColor', 'k');
        
        % Fit regression line (Predicting Thickness from Speckle Biomarker)
        if length(xMetric) > 1
            p = polyfit(xMetric, yTh, 1);
            xRange = max(xMetric) - min(xMetric);
            if xRange == 0, xRange = 0.1; end
            xMargin = xRange * 0.08;
            xLine = linspace(min(xMetric) - xMargin, max(xMetric) + xMargin, 100);
            yLine = polyval(p, xLine);
            plot(axCorr, xLine, yLine, 'r-', 'LineWidth', 1.8);
        end
        
        xlabel(axCorr, metric_label, 'FontWeight', 'bold');
        ylabel(axCorr, th_label, 'FontWeight', 'bold');
        title(axCorr, sprintf('Biomarker Prediction: %s vs. %s (r = %.3f)', ...
            metric_label, th_label, corrs.Pearson_r), 'FontWeight', 'bold');
        grid(axCorr, 'on'); box(axCorr, 'on');
        hold(axCorr, 'off');
        
        % Update metrics card
        lblPearson.Text  = sprintf('Pearson r: %.4f (p = %.3e)', corrs.Pearson_r, corrs.Pearson_p);
        lblSpearman.Text = sprintf('Spearman \\rho: %.4f (p = %.3e)', corrs.Spearman_rho, corrs.Spearman_p);
        lblR2.Text       = sprintf('Linear R^2: %.4f', corrs.R_squared);
        lblAnalyzedN.Text= sprintf('Analyzed Visits: %d of %d', corrs.N, height(SummaryData));
        
        if corrs.Pearson_p < 0.05
            lblSignif.Text = 'Significance: Statistically Significant (p < 0.05)';
            lblSignif.FontColor = [0.15 0.6 0.2];
        else
            lblSignif.Text = 'Significance: Trend only (p >= 0.05)';
            lblSignif.FontColor = [0.7 0.4 0.1];
        end
    end
end