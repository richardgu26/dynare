function y_=simult_(y0,dr,ex_,iorder)
% Simulates the model using a perturbation approach, given the path for the exogenous variables and the
% decision rules.
%
% INPUTS
%    y0       [double]   n*1 vector, initial value (n is the number of declared endogenous variables plus the number 
%                        of auxilliary variables for lags and leads)
%    dr       [struct]   matlab's structure where the reduced form solution of the model is stored.
%    ex_      [double]   T*q matrix of innovations.
%    iorder   [integer]  order of the taylor approximation.
%
% OUTPUTS
%    y_       [double]   n*(T+1) time series for the endogenous variables.
%
% SPECIAL REQUIREMENTS
%    none

% Copyright (C) 2001-2010 Dynare Team
%
% This file is part of Dynare.
%
% Dynare is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% Dynare is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with Dynare.  If not, see <http://www.gnu.org/licenses/>.

global M_ options_

iter = size(ex_,1);

y_ = zeros(size(y0,1),iter+M_.maximum_lag);

y_(:,1) = y0;

if options_.k_order_solver% Call dynare++ routines.
    options_.seed = 77;
    ex_ = [zeros(1,M_.exo_nbr); ex_];
    switch options_.order
      case 1
        [err, y_] = dynare_simul_(1,dr.nstatic,dr.npred-dr.nboth,dr.nboth,dr.nfwrd,M_.exo_nbr, ...
                           y_(dr.order_var,1),ex_',M_.Sigma_e,options_.seed,dr.ys(dr.order_var),...
                           zeros(M_.endo_nbr,1),dr.g_1);
      case 2
        [err, y_] = dynare_simul_(2,dr.nstatic,dr.npred-dr.nboth,dr.nboth,dr.nfwrd,M_.exo_nbr, ...
                           y_(dr.order_var,1),ex_',M_.Sigma_e,options_.seed,dr.ys(dr.order_var),dr.g_0, ...
                           dr.g_1,dr.g_2);
      case 3
        [err, y_] = dynare_simul_(3,dr.nstatic,dr.npred-dr.nboth,dr.nboth,dr.nfwrd,M_.exo_nbr, ...
                           y_(dr.order_var,1),ex_',M_.Sigma_e,options_.seed,dr.ys(dr.order_var),dr.g_0, ...
                           dr.g_1,dr.g_2,dr.g_3);
      otherwise
        error(['order = ' int2str(order) ' isn''t supported'])
    end
    mexErrCheck('dynare_simul_', err);
    y_(dr.order_var,:) = y_;
else
    k2 = dr.kstate(find(dr.kstate(:,2) <= M_.maximum_lag+1),[1 2]);
    k2 = k2(:,1)+(M_.maximum_lag+1-k2(:,2))*M_.endo_nbr;
    switch iorder
      case 1
        if isempty(dr.ghu)
            for i = 2:iter+M_.maximum_lag
                yhat = y_(dr.order_var(k2),i-1)-dr.ys(dr.order_var(k2));
                y_(dr.order_var,i) = dr.ys(dr.order_var)+dr.ghx*yhat;
            end
        else
            for i = 2:iter+M_.maximum_lag
                yhat = y_(dr.order_var(k2),i-1)-dr.ys(dr.order_var(k2));
                y_(dr.order_var,i) = dr.ys(dr.order_var) + dr.ghx*yhat + dr.ghu*ex_(i-1,:)';
            end
        end
      case 2
        constant = dr.ys(dr.order_var)+.5*dr.ghs2;
        if options_.pruning
            y__ = y0;
            for i = 2:iter+M_.maximum_lag
                yhat1 = y__(dr.order_var(k2))-dr.ys(dr.order_var(k2));
                yhat2 = y_(dr.order_var(k2),i-1)-dr.ys(dr.order_var(k2));
                epsilon = ex_(i-1,:)';

                [err, abcOut1] = A_times_B_kronecker_C(.5*dr.ghxx,yhat1);
                mexErrCheck('A_times_B_kronecker_C', err);
                [err, abcOut2] = A_times_B_kronecker_C(.5*dr.ghuu,epsilon);
                mexErrCheck('A_times_B_kronecker_C', err);
                [err, abcOut3] = A_times_B_kronecker_C(dr.ghxu,yhat1,epsilon);
                mexErrCheck('A_times_B_kronecker_C', err);

                y_(dr.order_var,i) = constant + dr.ghx*yhat2 + dr.ghu*epsilon ...
                    + abcOut1 + abcOut2 + abcOut3;
                y__(dr.order_var) = dr.ys(dr.order_var) + dr.ghx*yhat1 + dr.ghu*epsilon;
            end
        else
            for i = 2:iter+M_.maximum_lag
                yhat = y_(dr.order_var(k2),i-1)-dr.ys(dr.order_var(k2));
                epsilon = ex_(i-1,:)';

                [err, abcOut1] = A_times_B_kronecker_C(.5*dr.ghxx,yhat);
                mexErrCheck('A_times_B_kronecker_C', err);
                [err, abcOut2] = A_times_B_kronecker_C(.5*dr.ghuu,epsilon);
                mexErrCheck('A_times_B_kronecker_C', err);
                [err, abcOut3] = A_times_B_kronecker_C(dr.ghxu,yhat,epsilon);
                mexErrCheck('A_times_B_kronecker_C', err);

                y_(dr.order_var,i) = constant + dr.ghx*yhat + dr.ghu*epsilon ...
                    + abcOut1 + abcOut2 + abcOut3;
            end
        end
    end
end