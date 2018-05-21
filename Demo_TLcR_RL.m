
% =========================================================================
% Simple demo codes for face hallucination via TLcR-RL
%=========================================================================

clc;close all;clear all;
addpath('.\utilities');

nTraining   = 360;        % number of training sample
nTesting    = 40;         % number of ptest sample
upscale     = 4;          % upscaling factor 
patch_size  = 12;         % image patch size
overlap     = 4;          % the overlap between neighborhood patches

% parameter settings
window      = 16;         % contextal patch,12, 16, 20, 24, 28, ... (12 means us no contextal information)
K           = 360;        % thresholding parameter
tau         = 0.04;       % locality constraint parameter
layer       = 6;          % the iteration value in reproducing learning

% construct the HR and LR training pairs from the FEI face database
% [YH YL] = Training_LH(upscale,nTraining);

load('FEI_YH_YL.mat','YH','YL')
YH = double(YH);
YL = double(YL);

for TestImgIndex = 1:nTesting
    fprintf('\nProcessing  %d_test.jpg\n', TestImgIndex);
    
    % read ground truth of one test face 
    strh    = strcat('.\testFaces\',num2str(TestImgIndex),'_test.jpg');
    im_h    = double(imread(strh));

    % generate the input LR face by smooth and down-sampleing
    psf         = fspecial('average', [4 4]); 
    im_s    = imfilter(im_h,psf);
    im_l    = imresize(im_s,1/upscale,'bicubic');
    % upscale the LR face to HR size
    im_b = imresize(im_l,upscale,'bicubic');

    % hallucinate the high frequency face via TLcR
    [im_SR] = TLcR_RL(im_b,YH,YL,upscale,patch_size,overlap,window,tau,K); 
    % add the high frequency face to result
    [im_SR] = im_SR+im_b;
    
    % write results    
    imwrite(uint8(im_SR),strcat('./results/TLcR_',num2str(TestImgIndex),'.bmp'),'bmp');    

    % compute PSNR and SSIM for Bicubic and TLcR method
    bicubic_psnr(TestImgIndex) = psnr(im_b,im_h);
    bicubic_ssim(TestImgIndex) = ssim(im_b,im_h);
    TLcR_psnr(TestImgIndex) = psnr(im_SR,im_h);
    TLcR_ssim(TestImgIndex) = ssim(im_SR,im_h);   
    
    % updata the result by reproducing learning
    for ls = 1:layer
        im_lSR  = imfilter(im_SR,psf);
        im_lSR  = imresize(im_lSR,1/upscale,'bicubic');    
        im_lSR  = imresize(im_lSR,size(im_SR));
        [im_SR] = TLcR_RL(im_b,cat(3,YH,im_SR-im_lSR),cat(3,YL,im_lSR),upscale,patch_size,overlap,window,tau,K);
        [im_SR] = im_SR+im_b;
        % compute PSNR and SSIM for Bicubic and TLcR-RL method
        TLcRRL_psnr(ls,TestImgIndex) = psnr(im_SR,im_h);
        TLcRRL_ssim(ls,TestImgIndex) = ssim(im_SR,im_h);          
    end      

    % display the objective results (PSNR and SSIM)
    fprintf('PSNR for Bicubic:  %f dB\n', bicubic_psnr(TestImgIndex));
    fprintf('PSNR for TLcR:     %f dB\n', TLcR_psnr(TestImgIndex));
    fprintf('PSNR for TLcR-RL:  %f dB\n', TLcRRL_psnr(layer,TestImgIndex));
    fprintf('SSIM for Bicubic:  %f dB\n', bicubic_ssim(TestImgIndex));
    fprintf('SSIM for TLcR:     %f dB\n', TLcR_ssim(TestImgIndex));
    fprintf('SSIM for TLcR-RL:  %f dB\n', TLcRRL_ssim(layer,TestImgIndex));

    % write results    
    imwrite(uint8(im_SR),strcat('./results/TLcR-RL_',num2str(TestImgIndex),'.bmp'),'bmp');  

end
fprintf('===============================================\n');
fprintf('Average PSNR for Bicubic:  %f dB\n', sum(bicubic_psnr)/nTesting);
fprintf('Average PSNR for TLcR:     %f dB\n', sum(TLcR_psnr)/nTesting);
fprintf('Average PSNR for TLcR-RL:  %f dB\n', sum(TLcRRL_psnr(layer,:))/nTesting);
fprintf('Average SSIM for Bicubic:  %f dB\n', sum(bicubic_ssim)/nTesting);
fprintf('Average SSIM for TLcR:     %f dB\n', sum(TLcR_ssim)/nTesting);
fprintf('Average SSIM for TLcR-RL:  %f dB\n', sum(TLcRRL_ssim(layer,:))/nTesting);
fprintf('===============================================\n');

% plot the values
figure,plot([1:nTesting],[bicubic_psnr;TLcR_psnr;TLcRRL_psnr(layer,:)],'--*','linewidth',2);
xlabel('testing index');ylabel('PSNR (dB)');
legend('Bicubic','TLcR','TLcR-RL');
figure,plot([1:nTesting],[bicubic_ssim;TLcR_ssim;TLcRRL_ssim(layer,:)],'--*','linewidth',2);
xlabel('testing index');ylabel('SSIM');
legend('Bicubic','TLcR','TLcR-RL');