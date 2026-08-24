function[STATS] = speckle_stats(ROI,ROIraw)
% STATS = speckle_stats(ROI,ROIrect)
% calculates ALL speckle statistic for the ImSpeckle Tool 

% Created by D. Robert Iskander
% September/October 2019
% March 2020 (ver. 0.2)
% May/June 2020 (ver. 0.3), added goodness-of-fit measures
% July 2020 (ver. 0.4), fixed support for ksdensity
% July 2021 (ver 0.5), added contrast ratio (CR)
% October 2021 (ver 0.6), added Burr-2 distribution
% March 2022 (ver 0.72), ROIrect could be empty for very small set CCT
% April 2023 (ver 1.40), Densitometry

ROI = ROI(ROI>0);

% Kernel density estimation
pts = linspace(min(ROI)+eps,max(ROI),1000);
KDE = ksdensity(ROI,pts,'Kernel','epanechnikov','Support','positive'); 

%keyboard


% Burr-2 
STATS.BURR = burrfit2(ROI);
% Exponential
STATS.EXP = expfit(ROI);
% Gamma
STATS.GAM = gamfit(ROI);
% Generalized Gamma
% using 3rd part package wafo-2.1.0
STATS.GGAM = wggamfit(ROI,0);
% K - distribution    
STATS.K = kfit(ROI);
% Log-normal
STATS.LN = lognfit(ROI);
% Nakagami
FD = fitdist(ROI,'Nakagami');
STATS.NK = [FD.mu FD.omega];
% Rayleigh
STATS.RAY = raylfit(ROI); 
% Weibull
STATS.WBL = wblfit(ROI); 

% evaluate all pdfs
PDF_BURR = burr2pdf(pts,STATS.BURR);
PDF_EXP = exppdf(pts,STATS.EXP);
PDF_GAM = gampdf(pts,STATS.GAM(1),STATS.GAM(2));
PDF_GGAM = wggampdf(pts,STATS.GGAM(1),STATS.GGAM(2),STATS.GGAM(3));
PDF_K = kpdf(pts,STATS.K(1),STATS.K(2));
PDF_LN = lognpdf(pts,STATS.LN(1),STATS.LN(2));
PD = makedist('Nakagami',FD.mu,FD.omega);
PDF_NK = pdf(PD,pts);
PDF_RAY = raylpdf(pts,STATS.RAY(1));
PDF_WBL = wblpdf(pts,STATS.WBL(1),STATS.WBL(2));

% Goodness-of-fit (in the domain of PDF)
GoF_BURR = sqrt(mean((PDF_BURR-KDE).^2));
GoF_EXP = sqrt(mean((PDF_EXP-KDE).^2));
GoF_GAM = sqrt(mean((PDF_GAM-KDE).^2));
GoF_GGAM = sqrt(mean((PDF_GGAM-KDE).^2));
GoF_K = sqrt(mean((PDF_K-KDE).^2));
GoF_LN = sqrt(mean((PDF_LN-KDE).^2));
GoF_NK = sqrt(mean((PDF_NK-KDE).^2));
GoF_RAY = sqrt(mean((PDF_RAY-KDE).^2));
GoF_WBL = sqrt(mean((PDF_WBL-KDE).^2));

STATS.GOF = [GoF_BURR GoF_EXP GoF_GAM GoF_GGAM GoF_K GoF_LN GoF_NK GoF_RAY GoF_WBL];

% contrast ratio
STATS.CR = std(ROI)/mean(ROI);
% densitometry
STATS.Densito = mean(ROIraw);
