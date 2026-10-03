function[av] = kfit(X)
%  av=kfit(X)
%  The Maximum Likelihood Estimators of the parametrs a and v 
%  of the K_distribution

N = length(X);
m = sum(log(X))/N;
s_2 = sum((log(X)-m).^2)/N;
C = 4*s_2-pi/6;
M = (1+sqrt(1+3.8*C))/2/C;
g = 0.5772;
D = m+g+1/2/M-0.92*M/2/(M+1)-0.5*log(1+M);
b = 2*exp(-D);

v = M-1;
a = 1/b;
av(1) = a;
av(2) = v;