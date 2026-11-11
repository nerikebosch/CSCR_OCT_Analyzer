% batch_process_folders.m
% Reprocesses every visit and rebuilds the scan table of oct_study_db.mat.
%
% 1. Asks for the MAIN folder that contains all DATE sub-folders (e.g. 20240603, ...),
%    each holding the eye folders (..._Radial_R_... = OD, ..._Radial_L_... = OS).
% 2. Copies oct_study_db.mat to oct_study_db_backup_<timestamp>.mat.
% 3. Clears the old scan values of the visits found in the selected folder (the visit
%    table with dates and central thickness is kept), so no old values remain for scans
%    that fail in this run. Visits not in the folder keep their old values: select the
%    folder with ALL 23 visits to have every visit processed with the same code.
% 4. Processes B-scans 1, 2 and 32 of every eye folder and prints a summary at the end.
%
% Note: if an eye has two acquisitions on the same date, both are processed into the
% same visit and the LAST one (alphabetical folder order) is what remains stored.
clear; clc;
codeDir = fileparts(mfilename('fullpath'));
cd(codeDir);
addpath(genpath(fullfile(codeDir, 'stats_utils')));

mainFolder = uigetdir('C:\School\Thesis', 'Select the MAIN folder containing all the DATE sub-folders');
if isequal(mainFolder, 0), return; end

% --- Back up the database and clear the scan table -------------------------------------
dbPath = db_manager('db_path');
if isfile(dbPath)
    backupPath = fullfile(codeDir, sprintf('oct_study_db_backup_%s.mat', datestr(now, 'yyyymmdd_HHMMSS'))); %#ok<TNOW1,DATST>
    copyfile(dbPath, backupPath);
    fprintf('Backup of the database saved as %s\n', backupPath);
    data = load(dbPath);
    % Only the visits whose date folder (yyyyMMdd) is in the selected folder are cleared
    df = dir(mainFolder);
    df = df([df.isdir] & ~cellfun(@isempty, regexp({df.name}, '^20\d{6}$', 'once')));
    runDates = datetime({df.name}, 'InputFormat', 'yyyyMMdd');
    runVisits = data.DB.Visits.VisitNum(ismember(data.DB.Visits.VisitDate, runDates));
    rows = ismember(data.DB.Scans.VisitNum, runVisits);
    keyCols = {'ScanID', 'VisitNum', 'ImageIndex', 'EyeSide'};
    vn = data.DB.Scans.Properties.VariableNames;
    for c = 1:numel(vn)
        if ismember(vn{c}, keyCols), continue; end
        colVals = data.DB.Scans.(vn{c});
        if isnumeric(colVals), data.DB.Scans.(vn{c})(rows) = NaN;
        elseif isstring(colVals), data.DB.Scans.(vn{c})(rows) = "";
        end
    end
    save(dbPath, '-struct', 'data', '-v7.3');
    fprintf('Cleared old values of %d scans in %d visits found in the selected folder (other visits untouched).\n', ...
        sum(rows), numel(runVisits));
end
db_manager('init');   % adds any new columns (e.g. the DarkFrac / NCols quality checks)

options = struct('plotoption', 1);   % 1 keeps valid figure handles for the pipeline
disp('Initializing SAM segmentAnythingModel...');
options.MODEL = segmentAnythingModel;   % load SAM once

dateFolders = dir(mainFolder);
dateFolders = dateFolders([dateFolders.isdir] & ~startsWith({dateFolders.name}, '.'));
failed = {};
tStart = tic;
for i = 1:numel(dateFolders)
    dateFolderPath = fullfile(mainFolder, dateFolders(i).name);
    fprintf('\n>>> Entering Date Folder: %s\n', dateFolders(i).name);
    eyeFolders = dir(dateFolderPath);
    for j = 1:numel(eyeFolders)
        folderName = eyeFolders(j).name;
        isEyeFolder = contains(folderName, '_R_', 'IgnoreCase', true) || contains(folderName, '_L_', 'IgnoreCase', true);
        if ~eyeFolders(j).isdir || startsWith(folderName, '.') || ~isEyeFolder, continue; end
        fprintf('Found Valid Scan Folder: %s\n', folderName);
        try
            process_oct_folder(fullfile(dateFolderPath, folderName), options);   % OS flip is decided from the folder name
        catch ME
            fprintf('Skipped %s: %s\n', folderName, ME.message);
            failed{end + 1} = folderName; %#ok<SAGROW>
        end
        close all;
    end
end

% --- Summary: scans stored per visit and eye (expected 3 each) -------------------------
Scans = db_manager('get_scans');
Visits = db_manager('get_visits');
fprintf('\n================ BATCH SUMMARY (%.0f min) ================\n', toc(tStart) / 60);
for v = 1:height(Visits)
    done = ~isnan(Scans.ROI_Left_L1_fw);   % rows filled in this run
    nOD = sum(done & Scans.VisitNum == Visits.VisitNum(v) & Scans.EyeSide == "OD");
    nOS = sum(done & Scans.VisitNum == Visits.VisitNum(v) & Scans.EyeSide == "OS");
    flag = ''; if nOD < 3 || nOS < 3, flag = '   <-- missing scans (or not in the selected folder)'; end
    fprintf('Visit %2d  %s   OD %d   OS %d%s\n', Visits.VisitNum(v), datestr(Visits.VisitDate(v), 'yyyy-mm-dd'), nOD, nOS, flag); %#ok<DATST>
end
if ~isempty(failed), fprintf('Folders that failed completely:\n'); fprintf('  %s\n', failed{:}); end
disp('Full batch reprocessing complete! Dashboard is ready.');
