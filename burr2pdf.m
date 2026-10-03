function[f] = burr2pdf(x,ak)
%   f = burr2pdf(x,ak)
%   The PDF of the two parameter Burr distribution
a = ak(1);
k = ak(2);
f = 2*k/a*(x/a).*(1+(x/a).^2).^(-k-1);