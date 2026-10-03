%% Main Script: OCT Retinal Scan Analysis
% Modular pipeline integrated with local study database (oct_study_db.mat).
% Analyzes selected folder, updates longitudinal statistics, and exports consolidated reports.

clear; clc;

fprintf('====================================================\n');
fprintf('       OCT Retinal Scan Analysis - Single Run       \n');
fprintf('====================================================\n');

% 1. Initialize Database
db_manager('init');

% 2. Select Folder
folderPath = uigetdir('', 'Select folder containing OCT scans');
if folderPath == 0
    disp('Folder selection canceled.');
    return;
end

% 3. Process Selected Folder
options = struct();
options.plotoption = 1; % Enable visual diagnostic plots
options.targetIndices = []; % Default [1, 2, numFiles]

try
    visitNum = process_oct_folder(folderPath, options);

    % 4. Generate Updated Statistics & Report
    fprintf('\nGenerating updated clinical report...\n');
    compute_statistics('report');

    % 5. Auto-export to Excel for audit
    excelExportPath = fullfile(fileparts(mfilename('fullpath')), 'OCT_ROI_Stats.xlsx');
    db_manager('export_excel', excelExportPath);
    fprintf('Updated results exported to: %s\n', excelExportPath);

    % 6. Prompt to Launch Dashboard
    reply = input('Would you like to open the interactive OCT Dashboard? (y/n) [y]: ', 's');
    if isempty(reply) || strcmpi(reply, 'y')
        oct_dashboard();
    end

catch ME
    warning('An error occurred during scan processing: %s', ME.message);
    disp(ME.stack);
end