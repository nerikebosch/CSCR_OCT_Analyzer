%% Main Script: OCT Retinal Scan Analysis
MODEL = segmentAnythingModel;
plotoption = 1;

% Select Folder
folderPath = uigetdir('', 'Select folder containing OCT scans');
if folderPath == 0
    disp('Folder selection canceled.');
    return;
end

[~, folderName, ~] = fileparts(folderPath);
fileList = dir(fullfile(folderPath, '*.bmp'));
numFiles = length(fileList);
if numFiles == 0
    disp('No .bmp files found in the selected folder.');
    return;
else
    targetIndices = [1, 2, numFiles];
end

CR_Results_Matrix = NaN(15, 3); 

% Loop through the targeted indices
for i = 1:length(targetIndices)
    idx = targetIndices(i);
    fileName = fileList(idx).name;
    
    disp(['Folder Name: ', folderName]);
    disp(['Processing File (Index ', num2str(idx), '): ', fileName]);

    try
    
        % Load and Preprocess
        [I_crop_orig, I_crop_aligned, embeddings_aligned, sy, sx, angle_deg] = preprocess_OCT(folderPath, fileName, MODEL);
        
        % Get the real ILM on the flat image
        [Layer_ILM, h1] = segment_ILM(I_crop_aligned, MODEL, embeddings_aligned, sy, sx, plotoption);
       
        % Detect Macular Hole
        [is_hole_found, Mask_Hole, MaxPH, indMaxPH] = detect_hole(I_crop_aligned, MODEL, embeddings_aligned, sy, sx, Layer_ILM, plotoption, h1);
        
        % Segment Remaining Layers
        [Layer_Blue1, Layer_Blue2, Layer_Blue3, Layer_Blue4, Layer_Inner_Bot, Layer_RPE_bot, Layer_RPE_top] = ...
            segment_layers(I_crop_aligned, MODEL, sy, sx, MaxPH, indMaxPH, Layer_ILM, Mask_Hole, plotoption, h1);
        
        % Extract ROIs and Calculate Statistics
        [STATS_Full, STATS_Right, STATS_Left] = ...
            analyze_rois(I_crop_orig, I_crop_aligned, angle_deg, is_hole_found, Mask_Hole, sy, sx, Layer_Blue1, Layer_Blue2, Layer_Blue3, Layer_Blue4, Layer_Inner_Bot, Layer_RPE_bot, Layer_RPE_top, Layer_ILM, h1);
            
        

        % Right Side (Rows 1-5)
        if isstruct(STATS_Right)
            if isfield(STATS_Right, 'R1') && ~isempty(STATS_Right.R1), CR_Results_Matrix(1, i) = STATS_Right.R1.CR; end
            if isfield(STATS_Right, 'R2') && ~isempty(STATS_Right.R2), CR_Results_Matrix(2, i) = STATS_Right.R2.CR; end
            if isfield(STATS_Right, 'R3') && ~isempty(STATS_Right.R3), CR_Results_Matrix(3, i) = STATS_Right.R3.CR; end
            if isfield(STATS_Right, 'R4') && ~isempty(STATS_Right.R4), CR_Results_Matrix(4, i) = STATS_Right.R4.CR; end
            if isfield(STATS_Right, 'R5') && ~isempty(STATS_Right.R5), CR_Results_Matrix(5, i) = STATS_Right.R5.CR; end
        end
        
        % Left Side (Rows 6-10)
        if isstruct(STATS_Left)
            if isfield(STATS_Left, 'L1') && ~isempty(STATS_Left.L1), CR_Results_Matrix(6, i) = STATS_Left.L1.CR; end
            if isfield(STATS_Left, 'L2') && ~isempty(STATS_Left.L2), CR_Results_Matrix(7, i) = STATS_Left.L2.CR; end
            if isfield(STATS_Left, 'L3') && ~isempty(STATS_Left.L3), CR_Results_Matrix(8, i) = STATS_Left.L3.CR; end
            if isfield(STATS_Left, 'L4') && ~isempty(STATS_Left.L4), CR_Results_Matrix(9, i) = STATS_Left.L4.CR; end
            if isfield(STATS_Left, 'L5') && ~isempty(STATS_Left.L5), CR_Results_Matrix(10, i) = STATS_Left.L5.CR; end
        end
        
        % Full Width (Rows 11-15)
        if isstruct(STATS_Full)
            if isfield(STATS_Full, 'Layer1') && ~isempty(STATS_Full.Layer1), CR_Results_Matrix(11, i) = STATS_Full.Layer1.CR; end
            if isfield(STATS_Full, 'Layer2') && ~isempty(STATS_Full.Layer2), CR_Results_Matrix(12, i) = STATS_Full.Layer2.CR; end
            if isfield(STATS_Full, 'Layer3') && ~isempty(STATS_Full.Layer3), CR_Results_Matrix(13, i) = STATS_Full.Layer3.CR; end
            if isfield(STATS_Full, 'Layer4') && ~isempty(STATS_Full.Layer4), CR_Results_Matrix(14, i) = STATS_Full.Layer4.CR; end
            if isfield(STATS_Full, 'Layer5') && ~isempty(STATS_Full.Layer5), CR_Results_Matrix(15, i) = STATS_Full.Layer5.CR; end
        end
    
    catch ME
        warning(['An error occurred while processing image: ', fileName])
        disp(['Error message: ', ME.message]);
        continue
    end
end
disp('All targeted files have been processed successfully!');

% Create the row labels
Layer_Names = {
    'ROI_Right_L1'; 'ROI_Right_L2'; 'ROI_Right_L3'; 'ROI_Right_L4'; 'ROI_Right_L5';
    'ROI_Left_L1';  'ROI_Left_L2';  'ROI_Left_L3';  'ROI_Left_L4';  'ROI_Left_L5';
    'ROI_Full_L1';  'ROI_Full_L2';  'ROI_Full_L3';  'ROI_Full_L4';  'ROI_Full_L5'
};

ResultTable = table(Layer_Names, ...
                    CR_Results_Matrix(:,1), ...
                    CR_Results_Matrix(:,2), ...
                    CR_Results_Matrix(:,3), ...
                    'VariableNames', {'Different_Layers', 'Image_1', 'Image_2', 'Image_3'});

excelFilePath = fullfile('C:\School\Thesis\Coding', 'OCT_ROI_Stats.xlsx');

% Write the table to an Excel file
writetable(ResultTable, excelFilePath);

disp(['Results successfully exported to Excel at: ', excelFilePath]);