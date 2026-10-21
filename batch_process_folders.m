% batch_reprocess_all.m
clear; clc;
db_manager('init');

% Select the MAIN folder containing ALL the DATE sub-folders
mainFolder = uigetdir('', 'Select the MAIN folder containing all the DATE sub-folders');
if mainFolder == 0, return; end

dateFolders = dir(mainFolder);

% CHANGED TO 1: This creates the valid figure handles the AI needs to not crash!
options = struct('plotoption', 1); 
disp('Initializing SAM segmentAnythingModel...');
options.MODEL = segmentAnythingModel; % Load SAM once

% Loop through Level 1: The Date Folders (e.g., 20240603, 20240624...)
for i = 1:length(dateFolders)
    if dateFolders(i).isdir && ~startsWith(dateFolders(i).name, '.')
        dateFolderPath = fullfile(mainFolder, dateFolders(i).name);
        
        fprintf('\n>>> Entering Date Folder: %s\n', dateFolders(i).name);
        
        % Look inside the Date folder for Level 2: The Eye Folders
        eyeFolders = dir(dateFolderPath);
        
        for j = 1:length(eyeFolders)
            folderName = eyeFolders(j).name;
            
            % STRICT FILTER: Only process if the folder name contains _R_ or _L_
            isRightEye = contains(folderName, '_R_', 'IgnoreCase', true);
            isLeftEye  = contains(folderName, '_L_', 'IgnoreCase', true);
            
            if eyeFolders(j).isdir && ~startsWith(folderName, '.') && (isRightEye || isLeftEye)
                
                scanFolderPath = fullfile(dateFolderPath, folderName);
                fprintf('Found Valid Scan Folder: %s\n', folderName);
                
                % PASS THE LEFT EYE FLAG so preprocess_OCT knows to flip it
                options.isLeftEye = isLeftEye; 
                
                try
                    process_oct_folder(scanFolderPath, options);
                    
                    % IMMEDIATELY close the plotting windows after saving
                    close all; 
                catch ME
                    fprintf('Skipped %s: %s\n', folderName, ME.message);
                end
                
            end
        end
        
    end
end

disp('====================================================');
disp('Full batch reprocessing complete! Dashboard is ready.');
disp('====================================================');