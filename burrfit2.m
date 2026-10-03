function[ak] = burrfit2(data)

data = data(:);

Md = median(data);
k = linspace(0.501,500,5000);
F = Md./2./sqrt(2.^(1./k)-1).*beta(0.5,k-0.5);

Mn = mean(data);
ind = find(F<Mn);
if ~isempty(ind)
    ind = ind(1);
    khat = k(ind);
    alphahat = Md/sqrt(2.^(1./k(ind))-1);
    ak(1) = alphahat;
    ak(2) = khat;
else
    ak(1) = NaN;
    ak(2) = NaN;
end
%disp([ak(1) ak(2)])