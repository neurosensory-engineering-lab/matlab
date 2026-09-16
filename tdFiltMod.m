%%Time-stamp: "2005-12-19 23:03:00 matlabuser"
%to filter the stroke signals
function output=tdFiltMod(mydata,myfiltersize)

%gaussian sliding filter
width=ceil(myfiltersize./2)/2;
gaussaxis=-2.*width:1:width.*2;
myfunction= exp( - (gaussaxis.^2./2./width.^2));
myfunction=myfunction./sum(myfunction);
dataMean=mean(mydata);
wasColumn=size(mydata,1)>size(mydata,2);
output=conv(mydata(:).'-dataMean,myfunction,'same')+dataMean;
if wasColumn
	output=output.';
end

