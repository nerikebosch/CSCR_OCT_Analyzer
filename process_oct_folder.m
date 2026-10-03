function visitNum = process_oct_folder(folderPath, options)
% PROCESS_OCT_FOLDER Analyzes OCT scans in a folder and saves results to the local database.
%
% USAGE:
%   visitNum = process_oct_folder(folderPath)
%   visitNum = process_oct_folder(folderPath, options)
%
% OPTIONS:
%   options.MODEL         - Instantiated segmentAnythingModel (optional, creates if empty)
%   options.plotoption    - 1 to display figures, 0 for headless (default: 0)
%   options.targetIndices - Slices to analyze (default: [1, 2, numFiles])
%   options.VisitNum      - Explicit visit number (optional, auto-detected if empty)
%   options.VisitDate     - Explicit visit date (optional, auto-detected from folder name)
%   options.EyeSide       - 'OD' (Right) or 'OS' (Left) (default auto-detected)
%   options.CentralThickness_OD - Central thickness for Right eye in um (optional)
%   options.CentralThickness_OS - Central thickness for Left eye in um (optional)

    if nargin < 2, options = struct(); end

    if ~isfield(options, 'plotoption'), options.plotoption = 0; end
    if ~isfield(options, 'MODEL') || isempty(options.MODEL)
        disp('Initializing SAM segmentAnythingModel...');
        MODEL = segmentAnythingModel;
    else
        MODEL = options.MODEL;
    end

    if ~isfolder(folderPath)
        error('Specified folder does not exist: %s', folderPath);
    end

    [~, folderName, ~] = fileparts(folderPath);
    fileList = dir(fullfile(folderPath, '*.bmp'));
    numFiles = length(fileList);

    if numFiles == 0
        error('No .bmp scan files found in: %s', folderPath);
    end

    % Determine target slices (default: slice 1, slice 2, and last slice)
    if isfield(options, 'targetIndices') && ~isempty(options.targetIndices)
        targetIndices = options.targetIndices;
    else
        targetIndices = [1, 2, numFiles];
    end
    % Ensure indices are within bounds
    targetIndices = targetIndices(targetIndices >= 1 & targetIndices <= numFiles);

    %% 1. Metadata Extraction (Date, Eye Side, Visit Number)
    [extractedDate, extractedEye] = parse_folder_metadata(folderName);

    % Resolve Eye Side
    eyeSide = extractedEye;
    if isfield(options, 'EyeSide') && ~isempty(options.EyeSide)
        eyeSide = upper(string(options.EyeSide));
    end

    % Resolve Visit Date
    visitDate = extractedDate;
    if isfield(options, 'VisitDate') && ~isempty(options.VisitDate)
        if isa(options.VisitDate, 'datetime')
            visitDate = options.VisitDate;
        else
            visitDate = datetime(options.VisitDate, 'InputFormat', 'yyyy-MM-dd');
        end
    end

    % Resolve Visit Number from Database
    Visits = db_manager('get_visits');
    if isfield(options, 'VisitNum') && ~isempty(options.VisitNum)
        visitNum = int32(options.VisitNum);
    else
        % Check if a visit already exists on this date
        matchedIdx = find(Visits.VisitDate == visitDate, 1);
        if ~isempty(matchedIdx)
            visitNum = Visits.VisitNum(matchedIdx);
            fprintf('Matched existing Visit #%d for date %s.\n', visitNum, datestr(visitDate, 'yyyy-mm-dd'));
        else
            if isempty(Visits)
                visitNum = int32(1);
            else
                visitNum = int32(max(Visits.VisitNum) + 1);
            end
            fprintf('Assigned new Visit #%d for date %s.\n', visitNum, datestr(visitDate, 'yyyy-mm-dd'));
        end
    end

    % Prepare/Update Visit record in Database
    vData = struct();
    vData.VisitNum = visitNum;
    vData.VisitDate = visitDate;
    if isfield(options, 'CentralThickness_OD'), vData.CentralThickness_OD = options.CentralThickness_OD; end
    if isfield(options, 'CentralThickness_OS'), vData.CentralThickness_OS = options.CentralThickness_OS; end
    if isfield(options, 'Notes'), vData.Notes = options.Notes; end
    db_manager('save_visit', vData);

    fprintf('====================================================\n');
    fprintf('Processing OCT Folder: %s\n', folderName);
    fprintf('Visit: #%d | Date: %s | Eye: %s | Slices: %s\n', ...
        visitNum, datestr(visitDate, 'yyyy-mm-dd'), eyeSide, mat2str(targetIndices));
    fprintf('====================================================\n');

    %% 2. Process Target Slices
    for i = 1:length(targetIndices)
        idx = targetIndices(i);
        fileName = fileList(idx).name;
        fprintf('  --> Processing Slice %d of %d (Index %d): %s\n', i, length(targetIndices), idx, fileName);

        try
            % 1. Preprocess & Align
            [I_crop_orig, I_crop_aligned, embeddings_aligned, sy, sx, angle_deg] = ...
                preprocess_OCT(folderPath, fileName, MODEL);

            % 2. Segment ILM
            [Layer_ILM, h1] = segment_ILM(I_crop_aligned, MODEL, embeddings_aligned, sy, sx, options.plotoption);

            % 3. Detect Macular Hole
            [is_hole_found, Mask_Hole, MaxPH, indMaxPH] = ...
                detect_hole(I_crop_aligned, MODEL, embeddings_aligned, sy, sx, Layer_ILM, options.plotoption, h1);

            % 4. Segment Remaining Layers
            [Layer_Blue1, Layer_Blue2, Layer_Blue3, Layer_Blue4, Layer_Inner_Bot, Layer_RPE_bot, Layer_RPE_top] = ...
                segment_layers(I_crop_aligned, MODEL, sy, sx, MaxPH, indMaxPH, Layer_ILM, Mask_Hole, options.plotoption, h1);

            % 5. Extract ROIs & Calculate Speckle Stats
            [STATS_Full, STATS_Right, STATS_Left] = ...
                analyze_rois(I_crop_orig, I_crop_aligned, angle_deg, is_hole_found, Mask_Hole, sy, ...
                             sx, Layer_Blue1, Layer_Blue2, Layer_Blue3, Layer_Blue4, ...
                             Layer_Inner_Bot, Layer_RPE_bot, Layer_RPE_top, Layer_ILM, h1);

            % If plotoption was off, close any lingering figures created by functions
            if ~options.plotoption
                close all hidden;
            end

            % 6. Assemble Scan Record
            scanRecord = struct();
            scanRecord.VisitNum = visitNum;
            scanRecord.ImageIndex = i; % 1, 2, 3
            scanRecord.EyeSide = eyeSide;
            scanRecord.FileName = fileName;

            % Right ROIs
            if isstruct(STATS_Right)
                if isfield(STATS_Right, 'R1') && ~isempty(STATS_Right.R1), scanRecord.ROI_Right_L1 = STATS_Right.R1.CR; end
                if isfield(STATS_Right, 'R2') && ~isempty(STATS_Right.R2), scanRecord.ROI_Right_L2 = STATS_Right.R2.CR; end
                if isfield(STATS_Right, 'R3') && ~isempty(STATS_Right.R3), scanRecord.ROI_Right_L3 = STATS_Right.R3.CR; end
                if isfield(STATS_Right, 'R4') && ~isempty(STATS_Right.R4), scanRecord.ROI_Right_L4 = STATS_Right.R4.CR; end
                if isfield(STATS_Right, 'R5') && ~isempty(STATS_Right.R5), scanRecord.ROI_Right_L5 = STATS_Right.R5.CR; end
            end

            % Left ROIs
            if isstruct(STATS_Left)
                if isfield(STATS_Left, 'L1') && ~isempty(STATS_Left.L1), scanRecord.ROI_Left_L1 = STATS_Left.L1.CR; end
                if isfield(STATS_Left, 'L2') && ~isempty(STATS_Left.L2), scanRecord.ROI_Left_L2 = STATS_Left.L2.CR; end
                if isfield(STATS_Left, 'L3') && ~isempty(STATS_Left.L3), scanRecord.ROI_Left_L3 = STATS_Left.L3.CR; end
                if isfield(STATS_Left, 'L4') && ~isempty(STATS_Left.L4), scanRecord.ROI_Left_L4 = STATS_Left.L4.CR; end
                if isfield(STATS_Left, 'L5') && ~isempty(STATS_Left.L5), scanRecord.ROI_Left_L5 = STATS_Left.L5.CR; end
            end

            % Full Width ROIs
            if isstruct(STATS_Full)
                if isfield(STATS_Full, 'Layer1') && ~isempty(STATS_Full.Layer1), scanRecord.ROI_Full_L1 = STATS_Full.Layer1.CR; end
                if isfield(STATS_Full, 'Layer2') && ~isempty(STATS_Full.Layer2), scanRecord.ROI_Full_L2 = STATS_Full.Layer2.CR; end
                if isfield(STATS_Full, 'Layer3') && ~isempty(STATS_Full.Layer3), scanRecord.ROI_Full_L3 = STATS_Full.Layer3.CR; end
                if isfield(STATS_Full, 'Layer4') && ~isempty(STATS_Full.Layer4), scanRecord.ROI_Full_L4 = STATS_Full.Layer4.CR; end
                if isfield(STATS_Full, 'Layer5') && ~isempty(STATS_Full.Layer5), scanRecord.ROI_Full_L5 = STATS_Full.Layer5.CR; end
            end

            % Save slice to database
            db_manager('save_scan', scanRecord);
            fprintf('      Successfully saved slice %d (CR values recorded).\n', i);

        catch ME
            warning('Failed processing file %s: %s', fileName, ME.message);
        end
    end

    %% 3. Automatically Update All Longitudinal Statistics in DB
    fprintf('\nUpdating longitudinal statistics and rates of change across visits...\n');
    compute_statistics('update_all');
    fprintf('Folder processing complete! Database updated for Visit #%d.\n\n', visitNum);
end

%% Helper: Parse Date and Eye Side from Folder Name
function [vDate, eyeSide] = parse_folder_metadata(folderName)
    % Default fallbacks
    vDate = datetime('today');
    eyeSide = "OD";

    % Check Eye side
    if contains(folderName, '_Retina_Radial_L_', 'IgnoreCase', true) || ...
       contains(folderName, '_L_', 'IgnoreCase', true)
        eyeSide = "OS";
    elseif contains(folderName, '_Retina_Radial_R_', 'IgnoreCase', true) || ...
           contains(folderName, '_R_', 'IgnoreCase', true)
        eyeSide = "OD";
    end

    % Extract date matching 8 consecutive digits starting with 20 (e.g. 20240603)
    dateTokens = regexp(folderName, '(20\d{6})', 'match');
    if ~isempty(dateTokens)
        try
            vDate = datetime(dateTokens{1}, 'InputFormat', 'yyyyMMdd');
        catch
            % Leave as today if parsing fails
        end
    end
end
