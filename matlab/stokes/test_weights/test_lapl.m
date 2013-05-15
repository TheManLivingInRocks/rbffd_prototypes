
%% Build a differentiation matrix, test hyperviscosity and run the vortex
%% roll PDE.
%clc;
%clear all;
close all;

test_cases = ['md010.00121'; 'md015.00256'; 'md019.00400'; 'md028.00841'; 'md031.01024'; 'md049.02500'; 'md063.04096'; 'md079.06400'; 'md089.08100' ; 'md100.10201' ; 'md127.16384' ; 'md165.27556'];
prob_sizes = zeros(size(test_cases,1),1); 
l1_err_indirect = zeros(size(test_cases,1),1); 
l2_err_indirect = zeros(size(test_cases,1),1); 
linf_err_indirect = zeros(size(test_cases,1),1); 
l1_err_direct = zeros(size(test_cases,1),1); 
l2_err_direct = zeros(size(test_cases,1),4); 
linf_err_direct = zeros(size(test_cases,1),1); 

l1_diff = zeros(size(test_cases, 1),1);
l2_diff = zeros(size(test_cases, 1),1);
linf_diff = zeros(size(test_cases, 1),1);

conds = zeros(size(test_cases,1), 4); 

constantViscosity = 1; 

%fdsize = 17; c1 = 0.026; c2 = 0.08;  hv_k = 2; hv_gamma = 8;
%fdsize = 31; c1 = 0.035; c2 = 0.1 ; hv_k = 4; hv_gamma = 800;
%%fdsize = 31; c1 = 0.035; c2 = 0.1 ; hv_k = 2; hv_gamma = 800;

%fdsize = 105; c1 = 0.044; c2 = 0.14; hv_k = 4; hv_gamma = 145;
%fdsize = 110; c1 = 0.058; c2 = 0.16;  hv_k = 4; hv_gamma = 40;
%%fdsize = 40;  c1 = 0.027; c2 = 0.274; hv_k = 4; hv_gamma = 800; 

%% From COSINE BELL: 
abs_l1_diff = zeros(size(test_cases,1),4); 
abs_l2_diff = zeros(size(test_cases,1),4);
abs_linf_diff = zeros(size(test_cases,1),4);

for indx = 1:4

switch indx
    case 1
        fdsize = 17; c1 = 0.026; c2 = 0.08;  hv_k = 2; hv_gamma = 8e-4; nsteps = 1000;
    case 2
        fdsize = 31; c1 = 0.035; c2 = 0.1 ;  hv_k = 4; hv_gamma = 5e-2; nsteps=1000; 
    case 3
        fdsize = 50; c1 = 0.044; c2 = 0.14;  hv_k = 6; hv_gamma = 5e-1; nsteps=1000;
    case 4
        fdsize = 101; c1 = 0.058; c2 = 0.16;  hv_k = 8; hv_gamma = 5e-2; nsteps=1000;
    otherwise
        error('barf');
end

% Switch Hyperviscosity ON (1) and OFF (0)
useHV = 0;

start_time = 0; 
end_time = 3; 
dt = 0.05; 
dim = 2; 

    % Start fresh. 
    clearvars -global RBFFD_WEIGHTS; 
    clear weights_available;
    global RBFFD_WEIGHTS;
    global RBFFD_WEIGHTS2;
    
for i = 1:size(test_cases,1)
    test = test_cases(i,:);
    
    nodes = load(['~/GRIDS/md/', test]); 
    
    nodes=nodes(:,1:3);
    N = length(nodes);
    
    prob_sizes(i) = N; 
    
    ep = c1 * sqrt(N) - c2;

    
    fprintf('Calculating weights (N=%d, n=%d, ep=%f, hv_k=%d, hv_gamma=%e)\n', N, fdsize, ep, hv_k, hv_gamma); 
    tic
    [weights_available, nodes] = Calc_RBFFD_Weights({'lsfc','xsfc','ysfc','zsfc'}, N, nodes, fdsize, ep, hv_k);
    [weights_available, nodes] = Calc_RBFFD_Weights_Unit_Circle({'lsfc','xsfc','ysfc','zsfc'}, N, nodes, fdsize, 4, hv_k);
    toc
    
    RBFFD_WEIGHTS = RBFFD_WEIGHTS2; 
    
    Xx = nodes(:,1); 
    Yy = nodes(:,2); 
    Zz = nodes(:,3);

%    myfunc = (sqrt(105/pi).*(Xx - Yy).*(Xx + Yy).*Zz)./(4.*(Xx.^2 + Yy.^2 + Zz.^2).^1.5);
%    myfunc_pdx = -(sqrt(105./pi).*Xx.*Zz.*(Xx.^2 - 5.*Yy.^2 - 2.*Zz.^2))./(4.*(Xx.^2 + Yy.^2 + Zz.^2).^2.5);
        
%% Generated with Mathematica (File: SphericalHarmonics_TimesSine.nb
 
myfunc = (sqrt(105./pi).*(Xx - Yy).*(Xx + Yy).*Zz.*sin(20.*Xx))./(4..*(Xx.^2 + Yy.^2 + Zz.^2).^1.5);
myfunc_pdx =         -(sqrt(105./pi).*Zz.*(20.*(-1 + Xx.^2).*(Xx - Yy).*(Xx + Yy).*(Xx.^2 + Yy.^2 + Zz.^2).*cos(20.*Xx) + Xx.*(Xx.^2 - 5.*Yy.^2 - 2.*Zz.^2).*sin(20.*Xx)))./(4..*(Xx.^2 + Yy.^2 + Zz.^2).^2.5); 
myfunc_pdy = (sqrt(105./pi).*Yy.*Zz.*(-20.*Xx.*(Xx - Yy).*(Xx + Yy).*(Xx.^2 + Yy.^2 + Zz.^2).*cos(20.*Xx) + (-5.*Xx.^2 + Yy.^2 - 2.*Zz.^2).*sin(20.*Xx)))./(4..*(Xx.^2 + Yy.^2 + Zz.^2).^2.5); 
myfunc_pdz = (sqrt(105./pi).*(Xx - Yy).*(Xx + Yy).*(-20.*Xx.*Zz.^2.*(Xx.^2 + Yy.^2 + Zz.^2).*cos(20.*Xx) + (Xx.^2 + Yy.^2 - 2.*Zz.^2).*sin(20.*Xx)))./(4..*(Xx.^2 + Yy.^2 + Zz.^2).^2.5);
myfunc_lsfc =         -((sqrt(105./pi).*Zz.*(-10.*Xx.*(3.*Xx.^6 + 5.*Yy.^2 + 2.*Zz.^2 - Yy.^2.*(Yy.^2 + Zz.^2).*(-4 + 3.*Yy.^2 + 3.*Zz.^2) + Xx.^4.*(-4 + 3.*Yy.^2 + 6.*Zz.^2) - Xx.^2.*(1 + 3.*Yy.^4 + 4.*Zz.^2 - 3.*Zz.^4)).*cos(20.*Xx) + (Xx - Yy).*(Xx + Yy).*(3 + 100.*Yy.^2 + 100.*Zz.^2 + 100.*Xx.^2.*(-1 + Xx.^2 + Yy.^2 + Zz.^2).^2).*sin(20.*Xx)))./(Xx.^2 + Yy.^2 + Zz.^2).^2.5);

       
    direct = RBFFD_WEIGHTS.lsfc * myfunc;
    
    direct_err = direct - myfunc_lsfc; 
    l1_err_direct(i) = norm(direct_err,1)/norm(myfunc_lsfc, 1);
    l2_err_direct(i,indx) = norm(direct_err,2)/norm(myfunc_lsfc, 2)
    linf_err_direct(i) = norm(direct_err,inf)/norm(myfunc_lsfc, inf);

 
    
    % For some strange reason, my signs are off here!
    %indirect = RBFFD_WEIGHTS.xsfc_alt * myfunc;
    gradx = RBFFD_WEIGHTS.xsfc * myfunc;
    grady = RBFFD_WEIGHTS.ysfc * myfunc;
    gradz = RBFFD_WEIGHTS.zsfc * myfunc;
    
    indirect_pdx = (spdiags(1-Xx.^2,0,N,N) * RBFFD_WEIGHTS.xsfc + spdiags(-Xx.*Yy,0,N,N) * RBFFD_WEIGHTS.ysfc + spdiags(-Xx.*Zz,0,N,N) * RBFFD_WEIGHTS.zsfc) * gradx;
    indirect_pdy = (spdiags(-Xx.*Yy,0,N,N) * RBFFD_WEIGHTS.xsfc + spdiags(1-Yy.^2,0,N,N) * RBFFD_WEIGHTS.ysfc + spdiags(-Yy.*Zz,0,N,N) * RBFFD_WEIGHTS.zsfc) * grady;
    indirect_pdz = (spdiags(-Xx.*Zz,0,N,N) * RBFFD_WEIGHTS.xsfc + spdiags(-Yy.*Zz,0,N,N) * RBFFD_WEIGHTS.ysfc + spdiags(1-Zz.^2,0,N,N) * RBFFD_WEIGHTS.zsfc) * gradz;
    
    indirect = indirect_pdx + indirect_pdy + indirect_pdz;
    
    indirect_err = indirect - myfunc_lsfc; 
    l1_err_indirect(i) = norm(indirect_err,1)/norm(myfunc_lsfc, 1);
    l2_err_indirect(i) = norm(indirect_err,2)/norm(myfunc_lsfc, 2)
    linf_err_indirect(i) = norm(indirect_err,inf)/norm(myfunc_lsfc, inf);
        
        
    if 0
        figure(1)
        plotScalarfield(direct, nodes, 'Direct')
        figure(2)
        plotScalarfield(indirect, nodes, 'Indirect')
        figure(3)
        plotScalarfield(myfunc_lsfc, nodes, 'Laplacian[ Sph[3,2] * Sin[20x] ]')
    pause
    end
    %conds(i,indx) = condest(RBFFD_WEIGHTS.xsfc);
end

% figure(1)
% hold on;
% loglog(prob_sizes, [l1_err_indirect, l1_err_direct]);
% title('l1 error [ norm(approx-exact,1)/norm(exact,1) ]');
% xlabel('N');
% ylabel('l1 error');
% legend('Indirect', 'Direct');
% hold off;
% 
% figure(2);
% hold on;
% loglog(prob_sizes, [l2_err_indirect, l2_err_direct]);
% title('l2 error [ norm(approx-exact,2)/norm(exact,2) ]');
% xlabel('N');
% ylabel('l2 error');
% legend('Indirect', 'Direct');
% hold off;
% 
% figure(3);
% hold on;
% loglog(prob_sizes, l1_err_indirect);
% title('l2 error Indirect Method [ norm(approx-exact,2)/norm(exact,2) ]');
% xlabel('N');
% ylabel('l2 error');
% hold off;
% 
% figure(4);
% hold on;
% loglog(prob_sizes, l2_err_direct);
% title('l2 error Direct Method [ norm(approx-exact,2)/norm(exact,2) ]');
% xlabel('N');
% ylabel('l2 error');
% hold off;
% 
% figure(5)
% hold on;
% loglog(prob_sizes, [linf_err_indirect, linf_err_direct]);
% title('linf error [ norm(approx-exact,inf)/norm(exact,inf) ]');
% xlabel('N');
% ylabel('linf error');
% legend('Indirect', 'Direct');
% hold off;
    
   abs_l1_diff(:,indx) = l1_err_direct - l1_err_indirect ;
   abs_l2_diff(:,indx) = l2_err_direct(:,indx)  - l2_err_indirect;
   abs_linf_diff(:,indx) = linf_err_direct - linf_err_indirect ;
end
%     figure(1)
%     %hold on;
%     loglog(prob_sizes, abs_l1_diff,'LineWidth',2); 
%     %title('Absolute Difference in l1 errors', 'FontSize', 28); 
%     xlabel('N','FontSize', 28); 
%     ylabel('Absolute Difference (l1 error)','FontSize', 28);
%     set(gca,'FontSize', 28);
%     legend('n=17', 'n=31', 'n=50', 'n=101');
%     %hold off; 
%     
    figure(1)
    %hold on;
    semilogx(prob_sizes, abs_l2_diff,'LineWidth',2); 
    %title({'Difference', 'Rel l2 Errors'}, 'FontSize', 28); 
    xlabel('N','FontSize', 28); 
    ylabel('error_{direct} - error_{indirect}','FontSize', 28);
    set(gca,'FontSize', 28);
    legend('n=17', 'n=31', 'n=50', 'n=101');
    %hold off; 
%     
%     figure(3)
%     %hold on;
%     loglog(prob_sizes, abs_linf_diff,'LineWidth',2); 
%     %title('Absolute Difference in linf errors', 'FontSize', 28); 
%     xlabel('N','FontSize', 28); 
%     ylabel('Absolute Difference (linf error)','FontSize', 28);
%     set(gca,'FontSize', 28);
%     legend('n=17', 'n=31', 'n=50', 'n=101');
%     %hold off; 
        
        figure(4)
    %hold on;
    loglog(prob_sizes, abs(abs_l2_diff),'LineWidth',2); 
    %title({'Difference', 'Rel l2 Errors'}, 'FontSize', 28); 
    xlabel('N','FontSize', 28); 
    ylabel('abs(error_{direct} - error_{indirect})','FontSize', 28);
    %set(gca,'YTick',[1e-14 1e-12 1e-10 1e-8 1e-6]);
    set(gca,'FontSize', 28);
    legend('n=17', 'n=31', 'n=50', 'n=101');
    %hold off; 
          
    figure(2)
    loglog(prob_sizes, l2_err_direct,'LineWidth',2);
    %title({'Relative l2 Error','norm(direct-exact)/norm(exact)'},'FontSize',28);
    xlabel('N','FontSize',28);
    ylabel('Relative l2 Error','FontSize',28);
    set(gca,'FontSize', 28);
    legend('n=17', 'n=31', 'n=50', 'n=101');
    
    figure(3)
    loglog(prob_sizes, conds,'LineWidth',2);
    %title({'Condition Estimates','condest(DM_{XSFC})'},'FontSize',28);
    xlabel('N','FontSize',28);
    ylabel('Condition Number','FontSize',28);
    set(gca,'YTick',[1e16 1e18 1e20]);
    set(gca,'FontSize', 28);
    legend('n=17', 'n=31', 'n=50', 'n=101');
return
