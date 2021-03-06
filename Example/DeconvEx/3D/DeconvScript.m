%--------------------------------------------------------------
% This script performs 3D deconvolution using ADMM with
%    - Data-term: Least-Squares or Kullback-Leibler
%    - regul: TV or Hessian-Schatten norm
%--------------------------------------------------------------
clear; close all; clc;
help DeconvScript
%--------------------------------------------------------------
%  Copyright (C) 2017 E. Soubies emmanuel.soubies@epfl.ch
%
%  This program is free software: you can redistribute it and/or modify
%  it under the terms of the GNU General Public License as published by
%  the Free Software Foundation, either version 3 of the License, or
%  (at your option) any later version.
%
%  This program is distributed in the hope that it will be useful,
%  but WITHOUT ANY WARRANTY; without even the implied warranty of
%  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%  GNU General Public License for more details.
%
%  You should have received a copy of the GNU General Public License
%  along with this program.  If not, see <http://www.gnu.org/licenses/>.
%---------------------------------------------------------------

%% Parameters
lamb=1e-3;        % Hyperparameter for initial deconvolution
maxIt=20;         % Max iterations
Reg=1;            % 1 for TV, 2 for Hessian-Schatten 
DataTerm=2;       % 1 for LS, 2 for KL

%% fix the random seed (for reproductibility)
rng(1);

%% Input image and psf
if DataTerm==1
    [im,psf,y]=GenerateData3D('Gaussian',25);
elseif DataTerm==2
    [im,psf,y]=GenerateData3D('Poisson',5);
end
Orthoviews(im,[],'Input Image (GT)');
Orthoviews(y,[],'Convolved and noisy data');
sz=size(y);

%% Common operators and costs
H=LinOpConv(fftn(psf));                          % Convolution Operator
L2=CostL2(H.sizeout,y);                                % L2 cost function
LS=L2*H;                                               % Least-Sqaures data term
pos=CostNonNeg(sz);                                    % Non-Negativity: Indicator function
Id=LinOpIdentity(sz);                                  % Identity Operator
KL=CostKullLeib(sz,y,1e-6);                            % Kullback-Leibler divergence data term

if DataTerm==1, dt='0.5||Hx-y||_2^2'; else dt='KullLeib(Hx)'; end;
if Reg==1, rt='lamb*||x||_TV'; else rt='lamb*||x||_{Hess-Schat}'; end;
fprintf('Minimized Cost function : \n');
fprintf(['\t F(x) = ',dt,' + ',rt,' + i_+(x) \n \n']);

%% Deconvolution
% -- Functions definition
if Reg==1
    Freg=CostMixNorm21([sz,3],4);          % TV regularizer: Mixed Norm 2-1
    Opreg=LinOpGrad(sz);                   % TV regularizer: Operator Gradient
elseif Reg==2
    Freg=CostMixNormSchatt1([sz,6],1);     % Hessian-Shatten: Mixed Norm 1-Schatten (p=1)
    Opreg=LinOpHess(sz);                   % Hessian-Shatten: Hessian Operator
end

% -- ADMM
if DataTerm==1
    Fn={lamb*Freg,pos};           % Functionals F_n
    Hn={Opreg,Id};                    % Associated operators H_n
    rho_n=[1e-2,1e-2];                % Multipliers rho_n
    ADMM=OptiADMM(LS,Fn,Hn,rho_n);   
else
    Fn={KL,lamb*Freg,pos};          % Functionals F_n
    Hn={H,Opreg,Id};                    % Associated operators H_n
    rho_n=[1e-3,1e-3,1e-3];             % Multipliers rho_n
    ADMM=OptiADMM([],Fn,Hn,rho_n);
end
ADMM.OutOp=OutputOpti(1,im,round(maxIt/10),[1 2]);
ADMM.CvOp=TestCvgCombine(TestCvgCostRelative(1e-4), 'StepRelative',1e-4);  
ADMM.ItUpOut=round(maxIt/10);
ADMM.maxiter=maxIt;
ADMM.run(y);


%% Displays
Orthoviews(ADMM.xopt,[],'Deconvolved image');

% -- Plot Evolution SNR, cost  and Running Time for TV-Reg-Pos methods
figure;subplot(1,3,1); grid; hold all;
plot(ADMM.OutOp.iternum,ADMM.OutOp.evolcost,'LineWidth',1.5);  
set(gca,'FontSize',12);xlabel('Iterations');ylabel('Cost');
legend('ADMM');title('Cost evolution');
subplot(1,3,2); grid; hold all; title('Evolution SNR');set(gca,'FontSize',12);
semilogy(ADMM.OutOp.iternum,ADMM.OutOp.evolsnr,'LineWidth',1.5);
legend('ADMM','Location','southeast');xlabel('Iterations');ylabel('SNR (dB)');
subplot(1,3,3);hold on; grid; title('Runing Time');set(gca,'FontSize',12);
orderCol=get(gca,'ColorOrder');
bar(1,[ADMM.time],'FaceColor',orderCol(1,:),'EdgeColor','k');
set(gca,'xtick',[1 2 3 4]);ylabel('Time (s)');
set(gca,'xticklabels',{'ADMM'});set(gca,'XTickLabelRotation',45);