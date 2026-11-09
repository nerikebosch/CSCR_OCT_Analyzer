function q = fdr_bh(p)
% FDR_BH Benjamini-Hochberg adjusted p-values (q). NaN entries are ignored; shape is kept.
    q = nan(size(p));
    idx = find(~isnan(p));
    if isempty(idx), return; end
    [ps, ord] = sort(p(idx));
    ps = ps(:);
    nT = numel(ps);
    qs = ps .* nT ./ (1:nT)';
    qs = min(1, flipud(cummin(flipud(qs))));
    q(idx(ord)) = qs;
end
