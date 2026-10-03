function[f] = kpdf(x,a,v)
%   f = kpdf(x,a,v)
%   The PDF of the K-distrubution 

if v <= 100 && v > -1
    f = 2/a/gamma(v+1)*((x/2/a).^(v+1)).*besselk(v,x/a);
else 
   disp('Error v<=-1 or v>100')
   f=zeros(1,length(x));
end
