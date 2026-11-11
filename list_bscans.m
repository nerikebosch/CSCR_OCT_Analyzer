function files = list_bscans(folderPath)
% LIST_BSCANS The .bmp B-scans of one acquisition, sorted by their B-scan number.
%   files = list_bscans(folderPath)
%   dir() sorts names alphabetically (scan1, scan10, scan11, ..., scan2, ..., scan9), so
%   files(2) would be scan10 and files(end) scan9. Here the files are sorted by the number
%   after 'scan' in the file name, so files(k) is B-scan k.
    files = dir(fullfile(folderPath, '*.bmp'));
    if isempty(files), return; end
    tok = regexp({files.name}, 'scan(\d+)\.bmp$', 'tokens', 'once', 'ignorecase');
    num = inf(numel(files), 1);
    for k = 1:numel(files)
        if ~isempty(tok{k}), num(k) = str2double(tok{k}{1}); end
    end
    [~, order] = sortrows([num, (1:numel(files))']);
    files = files(order);
end
