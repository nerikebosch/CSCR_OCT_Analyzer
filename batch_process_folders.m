function batch_process_folders(parentDir, options)
% BATCH_PROCESS_FOLDERS Recursively processes all OCT scan folders under parentDir
% and commits all metrics into the local study database.
%
% USAGE:
%   batch_process_folders()                  - Prompts for parent directory
%   batch_process_folders(parentDir)         - Processes all subfolders in parentDir
%   batch_process_folders(parentDir, options)- Processes with custom options
%
% OPTIONS:
%   options.skipExisting - If true (default), skips folders already in database
%   options.plotoption   - 1 to display figures, 0 for headless (default: 0)
%   options.targetIndices- Slices to process per folder (default: [1, 2, numFiles])

    if nargin < 1 || isempty(parentDir)
        parentDir = uigetdir('', 'Select parent folder containing OCT scan subdirectories');
        if parentDir == 0
            disp('Batch processing canceled by user.');
            return;
        end
    end

    if nargin < 2, options = struct(); end
    if ~isfield(options, 'skipExisting'), options.skipExisting = true; end
    if ~isfield(options, 'plotoption'),   options.plotoption = 0; end

    fprintf('========================================================================\n');
    fprintf('                 OCT BATCH FOLDER PROCESSING PIPELINE                  \n');
    fprintf('Parent Directory: %s\n', parentDir);
    fprintf('========================================================================\n\n');

    % 1. Find all subdirectories that contain .bmp files
    allDirs = dir(fullfile(parentDir, '**'));
    subDirs = allDirs([allDirs.isdir]);
    scanFolders = {};

    for d = 1:length(subDirs)
        currDir = fullfile(subDirs(d).folder, subDirs(d).name);
        if strcmp(subDirs(d).name, '.') || strcmp(subDirs(d).name, '..')
            continue;
        end
        bmps = dir(fullfile(currDir, '*.bmp'));
        if ~isempty(bmps)
            scanFolders{end+1} = currDir; %#ok<AGROW>
        end
    end

    totalFolders = length(scanFolders);
    if totalFolders == 0
        fprintf('No subfolders containing .bmp scan files were found in: %s\n', parentDir);
        return;
    end

    fprintf('Discovered %d scan folder(s) ready for analysis.\n', totalFolders);

    % 2. Initialize SAM Model ONCE to prevent overhead (Rule 2 in GEMINI.md)
    fprintf('Initializing SAM model (will be reused across all folders)...\n');
    MODEL = segmentAnythingModel;
    options.MODEL = MODEL;

    % 3. Check existing scans in database to enable skip/resume
    Scans = db_manager('get_scans');

    % 4. Iterate over folders
    successCount = 0;
    skipCount    = 0;
    failCount    = 0;

    for f = 1:totalFolders
        folderPath = scanFolders{f};
        [~, folderName, ~] = fileparts(folderPath);

        fprintf('\n[%d/%d] Inspecting: %s\n', f, totalFolders, folderName);

        % Check if already processed
        if options.skipExisting && ~isempty(Scans)
            % Check if files in this folder exist in Scans table
            fileList = dir(fullfile(folderPath, '*.bmp'));
            if ~isempty(fileList)
                firstFile = string(fileList(1).name);
                if any(Scans.FileName == firstFile)
                    fprintf('  [SKIP] Folder already processed in database. Skipping.\n');
                    skipCount = skipCount + 1;
                    continue;
                end
            end
        end

        try
            vNum = process_oct_folder(folderPath, options);
            successCount = successCount + 1;
            fprintf('  [SUCCESS] Finished folder %d/%d (Assigned Visit #%d)\n', f, totalFolders, vNum);
        catch ME
            failCount = failCount + 1;
            warning('Failed processing folder "%s": %s', folderName, ME.message);
        end
    end

    % 5. Final Statistics Update
    fprintf('\n========================================================================\n');
    fprintf('Batch Processing Summary:\n');
    fprintf('  Total Folders Inspected: %d\n', totalFolders);
    fprintf('  Successfully Processed:  %d\n', successCount);
    fprintf('  Skipped (Existing):      %d\n', skipCount);
    fprintf('  Failed:                  %d\n', failCount);
    fprintf('========================================================================\n\n');

    % Compute & print final report
    compute_statistics('report');
end
