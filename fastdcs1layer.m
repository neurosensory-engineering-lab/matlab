function [bfi,g2data,g2fit,beta,rho,intdcs] = fastdcs1layer(sname,fdet,G2,int,taus,mua,mus,blf)
%This function determines DCS flow index using semi-infinite model
%sname is the name of the mat file that all relevent DCS data will be saved
%to.
%
%fdet is a structure where the fields are vectors.  The first entry of each
%vector is the DCS source-detector separation.  The next entries are the
%APD channels at this source-detector separation.
%
%G2 is the raw correlation data, shaped as [numch numtau numframes]
%int is the DCS intensity, shaped as [numch numframes]
%
%mua is the absorption coefficient at the DCS wavelength
%mus is the scattering coefficient at the DCS wavelength
%
%blf = [fmin fmax] are the frames denoting the baseline.  These are
%for assessing beta.

if length(mua)==1
    mua = mua * ones(1,size(G2,3));
end
if length(mus)==1
    mus = mus * ones(1,size(G2,3));
end

n = 1.4;
Reff = 0;
lambda = 785;
cutoff = 1.05;

intdcs = zeros(size(G2,3),length(fdet));
rho = zeros(1,length(fdet));

bfi = intdcs;
beta = bfi;
for k = 1:length(fdet)
    rho(k) = fdet(k).values(1);
    g2data(k) = {squeeze(mean(G2(fdet(k).values(2:end),:,:),1))'};
    intdcs(:,k) = mean(int(fdet(k).values(2:end),:),1)';
    
    %Semi-infinite fitting
    %First, fit for beta during baseline
    g2 = g2data{k};
    I = blf(1):blf(end);
    g20 = mean(g2(I,:),1);
    mua0 = mean(mua(I));
    mus0 = mean(mus(I));
    [bfi0,beta0,g2fit0] = seminfdcsfit(g20,taus,rho(k),mua0,mus0,n,Reff,lambda,cutoff);
    plotdcsg2(g20,g2fit0,taus,[],[],rho(k),bfi0,beta0)
    
    %Now, do fast DCS fitting at fixed beta
    [bfi(:,k),beta(:,k),g2f] = seminfdcsfit(g2,taus,rho(k),mua,mus,n,Reff,lambda,cutoff,[],beta0);
%     fsavefig(gcf,['Figs/BaselineSeminfFit_nrho' num2str(k)],1)
    g2fit(k) = {g2f};
end

eval(['save ' sname ])


