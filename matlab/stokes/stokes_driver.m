
%% Build a differentiation matrix, test hyperviscosity and run the vortex
%% roll PDE.
%clc;
%clear all;
close all;


constantViscosity = 1; 

%fdsize = 17; c1 = 0.026; c2 = 0.08;  hv_k = 2; hv_gamma = 8;
fdsize = 31; c1 = 0.035; c2 = 0.1 ; hv_k = 4; hv_gamma = 800;
%fdsize = 31; c1 = 0.035; c2 = 0.1 ; hv_k = 2; hv_gamma = 800;

%fdsize = 105; c1 = 0.044; c2 = 0.14; hv_k = 4; hv_gamma = 145;
%fdsize = 110; c1 = 0.058; c2 = 0.16;  hv_k = 4; hv_gamma = 40;
%%fdsize = 40;  c1 = 0.027; c2 = 0.274; hv_k = 4; hv_gamma = 800; 

% Switch Hyperviscosity ON (1) and OFF (0)
useHV = 0;

start_time = 0; 
end_time = 3; 
dt = 0.05; 
dim = 2; 


%nodes = load('~/GRIDS/md/md004.00025');
%nodes = load('~/GRIDS/md/md006.00049');
%nodes = load('~/GRIDS/md/md009.00100');
%nodes = load('~/GRIDS/md/md019.00400');
%nodes = load('~/GRIDS/md/md031.01024');
%nodes = load('~/GRIDS/md/md031.01024');
%nodes = load('~/GRIDS/md/md050.02601'); 
%nodes = load('~/GRIDS/md/md059.03600'); 
nodes = load('~/GRIDS/md/md063.04096');
%nodes = load('~/GRIDS/md/md079.06400');
%nodes = load('~/GRIDS/md/md089.08100'); 
%nodes = load('~/GRIDS/md/md099.10000');
%nodes = load('~/GRIDS/md/md100.10201');
%nodes = load('~/GRIDS/md/md122.15129');
%nodes = load('~/GRIDS/md/md159.25600');

%nodes = load('~/GRIDS/icos/icos42.mat');
%nodes = load('~/GRIDS/icos/icos162.mat');
%nodes = load('~/GRIDS/icos/icos642.mat');
%nodes = load('~/GRIDS/icos/icos2562.mat');
%nodes = load('~/GRIDS/icos/icos10242.mat');
%nodes = load('~/GRIDS/icos/icos40962.mat');
%nodes = load('~/GRIDS/icos/icos163842.mat');

%% Handle the case when icos grids are read in from mat files and they are structures
if isstruct(nodes) 
    nodes = nodes.nodes;
end

nodes=nodes(:,1:3);
N = length(nodes);

output_dir = sprintf('./direct_convergence_N%d_n%d_eta%d/', N, fdsize, constantViscosity);
fprintf('Making directory: %s\n', output_dir);
mkdir(output_dir); 

delete([output_dir,'runlog.txt'])
diary([output_dir,'runlog.txt'])
diary on; 

%% Simple profiling
%profile on -timer 'real'

ep = c1 * sqrt(N) - c2;

fprintf('Using RBF Support Parameter ep=%f\n', ep); 


% We declare this to be global so we can use the weights produced in the
% following subroutine. 
global RBFFD_WEIGHTS;

% Calculate weights and update global struct. Will overwrite existing
% weights, or append newly calculated weights to those already calculated. 
% We replace the nodes JUST IN CASE our weight calculator re-orders them
% for cache optimality. 
fprintf('Calculating weights (N=%d, n=%d, ep=%f, hv_k=%d, hv_gamma=%e)\n', N, fdsize, ep, hv_k, hv_gamma); 
tic
[weights_available, nodes] = Calc_RBFFD_Weights({'lsfc', 'xsfc', 'ysfc', 'zsfc','hv'}, N, nodes, fdsize, ep, hv_k);
toc

% NO need for hyperviscosity at this point
if useHV 
RBFFD_WEIGHTS.scaled_hv = - ( hv_gamma / N^(hv_k) ) * RBFFD_WEIGHTS.hv; 
end

fprintf('Filling LHS Collocation Matrix\n'); 
tic
if useHV
    fprintf('Stokes with hyperviscosity')
    [LHS, DIV_operator, eta] = stokes_hv_p(nodes, N, fdsize, useHV, constantViscosity);
else 
    [LHS, DIV_operator, eta] = stokes(nodes, N, fdsize, useHV, constantViscosity);
end
toc

hhh=figure('visible', 'off');
% resize the window to most of my laptop screen
set(hhh,'Units', 'normalized'); 
set(hhh,'Position',[0 0 0.5 1]);
% Get the window size in terms of inches of realestate
set(hhh,'Units','inches');
figpos = get(hhh,'Position');
% Change the paper size to match the window size
set(hhh,'PaperUnits','inches','PaperPosition',figpos);
spy(LHS); 
%title('LHS (L)', 'FontSize', 26);
set(gca, 'FontSize', 22); 
figFileName=[output_dir,'LHS'];
fprintf('Printing figure: %s\n',figFileName);
print(hhh,'-zbuffer','-dpng',[figFileName,'.png']);
hgsave(hhh,[figFileName,'.fig']); 
fprintf('Printing figure: %s\n',figFileName);

if 0
print(hhh,'-zbuffer','-r300','-depsc2',[figFileName,'.eps']);

hhh=figure('visible', 'off');
set(hhh,'Units', 'normalized'); 
set(hhh,'Position',[0 0 0.5 1]);
set(hhh,'Units','inches');
figpos = get(hhh,'Position');
set(hhh,'PaperUnits','inches','PaperPosition',figpos);
spy(LHS, 10);       % Plot with dot size of 10
axis([10 50 10 50])
%title('LHS (L)', 'FontSize', 26);
set(gca, 'FontSize', 22); 
figFileName=[output_dir,'LHS_10to50'];
fprintf('Printing figure: %s\n',figFileName);
print(hhh,'-zbuffer','-dpng',[figFileName,'.png']);
hgsave(hhh,[figFileName,'.fig']); 
fprintf('Printing figure: %s\n',figFileName);
print(hhh,'-zbuffer','-r300','-depsc2',[figFileName,'.eps']);
return
end 

% Spend some time reordering initially. 
%r = symrcm(LHS); 
%LHS = LHS(r,r); 

% Manufacture a RHS given our LHS
    
%% Test 2: Using a Spherical Harmonic on the RHS, lets get the steady state
%% velocity
fprintf('Filling RHS Vector\n'); 
tic;
[RHS_continuous, RHS_discrete, U_exact] = fillRHS(nodes, LHS, constantViscosity, eta, 0);
fprintf('Elapsed Time: %f\n', toc); 

hhh=figure('visible', 'off') ;
plotVectorComponents(RHS_continuous, nodes, 'RHS_{continuous} (F)'); 
figFileName=[output_dir,'RHS'];
fprintf('Printing figure: %s\n',figFileName);
print(hhh,'-zbuffer','-dpng',[figFileName,'.png']);
hgsave(hhh,[figFileName,'.fig']); 
close(hhh);

hhh=figure('visible', 'off') ;
plotVectorComponents(RHS_discrete, nodes, 'RHS_{discrete} (F)'); 
figFileName=[output_dir,'RHS_discrete'];
fprintf('Printing figure: %s\n',figFileName);
print(hhh,'-zbuffer','-dpng',[figFileName,'.png']);
hgsave(hhh,[figFileName,'.fig']); 
close(hhh);

hhh=figure('visible', 'off');
RHS_abs_err = abs(RHS_continuous-RHS_discrete);
plotVectorComponents(RHS_abs_err, nodes, 'RHS Abs Error (|RHS_{continuous}-RHS_{discrete}|)'); 
figFileName=[output_dir,'RHS_AbsError'];
fprintf('Printing figure: %s\n',figFileName);
print(hhh,'-zbuffer','-dpng',[figFileName,'.png']);
hgsave(hhh,[figFileName,'.fig']); 
close(hhh);

hhh=figure('visible', 'off') ;
plotVectorComponents(U_exact, nodes, 'Manufactured Solution'); 
figFileName=[output_dir,'U_exact'];
fprintf('Printing figure: %s\n',figFileName);
print(hhh,'-zbuffer','-dpng',[figFileName,'.png']);
hgsave(hhh,[figFileName,'.fig']); 
close(hhh);

if 0
dlmwrite(sprintf('%sRHS_continuous_%d.mtx',output_dir,N),RHS_continuous); 
dlmwrite(sprintf('%sU_exact_%d.mtx',output_dir, N),U_exact); 
mmwrite(sprintf('%sLHS_%d.mtx',output_dir, N),LHS);

return; 
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% SOLVE SYSTEM (Solver types: 'lsq', 'gmres', 'direct', 'gmres+ilu', 'gmres+ilu_k'
fprintf('Solving Lu=F\n'); 
%U = solve_system(LHS, RHS_continuous, N, 'gmres+ilu0'); 
U = solve_system(LHS, RHS_continuous, N, 'direct', true); 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% Check error in solution
hhh=figure('visible', 'off') ;
plotVectorComponents(U, nodes, 'Computed Solution (U = L^{-1}F)'); 
figFileName=[output_dir,'U_computed'];
fprintf('Printing figure: %s\n',figFileName);
print(hhh,'-zbuffer','-dpng',[figFileName,'.png']);
hgsave(hhh,[figFileName,'.fig']); 
close(hhh);



U_abs_err = abs(U-U_exact);

% fprintf('\n\n--> Checking Absolute Error of Computed Solution: \n');
% U_abs_err_l1 = norm(U_abs_err(1:N), 1)
% V_abs_err_l1 = norm(U_abs_err(N+1:2*N), 1)
% W_abs_err_l1 = norm(U_abs_err(2*N+1:3*N), 1)
% P_abs_err_l1 = norm(U_abs_err(3*N+1:4*N), 1)
% 
% U_abs_err_l2 = norm(U_abs_err(1:N), 2)
% V_abs_err_l2 = norm(U_abs_err(N+1:2*N), 2)
% W_abs_err_l2 = norm(U_abs_err(2*N+1:3*N), 2)
% P_abs_err_l2 = norm(U_abs_err(3*N+1:4*N), 2)
% 
% U_abs_err_linf = norm(U_abs_err(1:N), inf)
% V_abs_err_linf = norm(U_abs_err(N+1:2*N), inf)
% W_abs_err_linf = norm(U_abs_err(2*N+1:3*N), inf)
% P_abs_err_linf = norm(U_abs_err(3*N+1:4*N), inf)

fprintf('\n\n--> Checking Relative Error of Computed Solution: \n');
U_rel_err_l1 = norm(U_abs_err(1:N), 1) / norm(U_exact(1:N), 1)
U_rel_err_l2 = norm(U_abs_err(1:N), 2) / norm(U_exact(1:N), 2)
U_rel_err_linf = norm(U_abs_err(1:N), inf) / norm(U_exact(1:N), inf)

V_rel_err_l1 = norm(U_abs_err(N+1:2*N), 1) / norm(U_exact(N+1:2*N), 1)
V_rel_err_l2 = norm(U_abs_err(N+1:2*N), 2) / norm(U_exact(N+1:2*N), 2)
V_rel_err_linf = norm(U_abs_err(N+1:2*N), inf) / norm(U_exact(N+1:2*N), inf)

W_rel_err_l1 = norm(U_abs_err(2*N+1:3*N), 1) / norm(U_exact(2*N+1:3*N), 1)
W_rel_err_l2 = norm(U_abs_err(2*N+1:3*N), 2) / norm(U_exact(2*N+1:3*N), 2)
W_rel_err_linf = norm(U_abs_err(2*N+1:3*N), inf) / norm(U_exact(2*N+1:3*N), inf)

P_rel_err_l1 = norm(U_abs_err(3*N+1:4*N), 1) / norm(U_exact(3*N+1:4*N), 1)
P_rel_err_l2 = norm(U_abs_err(3*N+1:4*N), 2) / norm(U_exact(3*N+1:4*N), 2)
P_rel_err_linf = norm(U_abs_err(3*N+1:4*N), inf) / norm(U_exact(3*N+1:4*N), inf)

fprintf('\n\n');

hhh=figure('visible', 'off');
plotVectorComponents(U_abs_err, nodes, 'Solution Abs Error (|U-U_{exact}|)'); 
figFileName=[output_dir,'U_AbsError'];
fprintf('Printing figure: %s\n',figFileName);
print(hhh,'-zbuffer','-dpng',[figFileName,'.png']);
hgsave(hhh,[figFileName,'.fig']); 
close(hhh);

hhh=figure('visible', 'off');
U_rel_err = U_abs_err ./ abs(U_exact); 
U_rel_err(abs(U_exact) < 1e-12) = U_abs_err(abs(U_exact) < 1e-12); 
plotVectorComponents(U_rel_err, nodes, 'Solution Rel Error (|U-U_{exact}|/|U_{exact}|)'); 
figFileName=[output_dir,'U_RelError'];
fprintf('Printing figure: %s\n',figFileName);
print(hhh,'-zbuffer','-dpng',[figFileName,'.png']);
hgsave(hhh,[figFileName,'.fig']); 
close(hhh);

clear U_rel_err; 
clear U_abs_err; 


%%% Test Pressure
if 0
%% The lapl(P) should equal projected_div(T)
lapl_p = RBFFD_WEIGHTS.lsfc * U(3*N+1:4*N); 
lapl_g = RBFFD_WEIGHTS.lsfc * RHS_continuous(3*N+1:4*N); 
p_div_T = RBFFD_WEIGHTS.xsfc * RHS_continuous(1:N) + RBFFD_WEIGHTS.ysfc * RHS_continuous(1*N+1:2*N) + RBFFD_WEIGHTS.zsfc * RHS_continuous(2*N+1:3*N); 

p_abs_err = ((lapl_p) - (p_div_T + lapl_g)); 

p_error_l1 = norm(p_abs_err,1)
p_error_l2 = norm(p_abs_err,2)
p_error_linf = norm(p_abs_err,inf)

hhh=figure('visible', 'off');
plotScalarfield(lapl_p, nodes, 'lapl(P)'); 
figFileName=[output_dir,'P_lapl'];
fprintf('Printing figure: %s\n',figFileName);
print(hhh,'-zbuffer','-dpng',[figFileName,'.png']);
hgsave(hhh,[figFileName,'.fig']); 
close(hhh);

hhh=figure('visible', 'off');
plotScalarfield(p_div_T, nodes, 'div(RHS)'); 
figFileName=[output_dir,'RHS_div'];
fprintf('Printing figure: %s\n',figFileName);
print(hhh,'-zbuffer','-dpng',[figFileName,'.png']);
hgsave(hhh,[figFileName,'.fig']); 
close(hhh);

hhh=figure('visible', 'off');
plotScalarfield((lapl_p + lapl_g), nodes, 'lapl(p)+lapl(g)'); 
figFileName=[output_dir,'lP_lG'];
fprintf('Printing figure: %s\n',figFileName);
print(hhh,'-zbuffer','-dpng',[figFileName,'.png']);
hgsave(hhh,[figFileName,'.fig']); 
close(hhh);

hhh=figure('visible', 'off');
plotScalarfield((p_div_T + lapl_g), nodes, 'div(RHS)+lapl(g)'); 
figFileName=[output_dir,'dR_lg'];
fprintf('Printing figure: %s\n',figFileName);
print(hhh,'-zbuffer','-dpng',[figFileName,'.png']);
hgsave(hhh,[figFileName,'.fig']); 
close(hhh);

hhh=figure('visible', 'off');
plotScalarfield(p_abs_err, nodes, '| lapl(P) - div(RHS) |'); 
figFileName=[output_dir,'P_AbsError'];
fprintf('Printing figure: %s\n',figFileName);
print(hhh,'-zbuffer','-dpng',[figFileName,'.png']);
hgsave(hhh,[figFileName,'.fig']); 
close(hhh);
end

if 0
dlmwrite(sprintf('%sU_%d.mtx',output_dir, N),U); 
end


%profile off 

%profsave(profile('info'), [output_dir, 'profiler_output']);

diary off; 

clear div_U; 

% Force all hidden figures to close: 
close all hidden;
