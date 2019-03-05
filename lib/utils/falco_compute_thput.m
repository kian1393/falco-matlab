% Copyright 2018, by the California Institute of Technology. ALL RIGHTS
% RESERVED. United States Government Sponsorship acknowledged. Any
% commercial use must be negotiated with the Office of Technology Transfer
% at the California Institute of Technology.
% -------------------------------------------------------------------------
%
%
% REVISION HISTORY:
% --------------
% Created by A.J. Riggs on 2018-10-01 by extracting material from falco_wfsc_loop.m.
% ---------------

function [mp,thput] = falco_compute_thput(mp)




    ImTemp = falco_sim_image_compact_offaxis(mp, mp.thput_eval_x, mp.thput_eval_y,'eval');
    if(mp.flagPlot); figure(324); imagesc(mp.Fend.eval.xisDL,mp.Fend.eval.etasDL,ImTemp); axis xy equal tight; title('Off-axis PSF for Throughput Calculation','Fontsize',20); set(gca,'Fontsize',20); colorbar; drawnow;  end

    switch lower(mp.thput_metric)
        
        case{'hmi'} %--Absolute energy within half-max isophote(s)
            
            maskHM = 0*mp.FP4.eval.RHOS;
            maskHM(ImTemp>=1/2*max(max(ImTemp))) = 1;
            % figure(325); imagesc(mp.Fend.full.xisDL,mp.Fend.full.etasDL,mp.maskCore); axis xy equal tight; drawnow;
            thput = sum(ImTemp(maskHM==1))/mp.sumPupil*mean(mp.Fend.eval.I00);
            fprintf('Core throughput with the half-max isophote(s) = %.2f%% \tat separation = (%.1f, %.1f) lambda0/D.\n',100*thput,mp.thput_eval_x,mp.thput_eval_y);
            
        case{'ee','e.e.'} %--Absolute energy encircled within a given radius

            % (x,y) location [lambda_c/D] in dark hole at which to evaluate throughput
            maskEE  = 0*mp.FP4.eval.RHOS;
            maskEE(mp.FP4.eval.RHOS<=mp.thput_radius) = 1;
            
            % figure(325); imagesc(mp.Fend.full.xisDL,mp.Fend.full.etasDL,mp.maskCore); axis xy equal tight; drawnow;
            thput = sum(ImTemp(maskEE==1))/mp.sumPupil*mean(mp.Fend.eval.I00);
            fprintf('E.E. throughput within a %.2f lambda/D radius = %.2f%% \tat separation = (%.1f, %.1f) lambda/D.\n',mp.thput_radius,100*thput,mp.thput_eval_x,mp.thput_eval_y);
    end
end %--END OF FUNCTION
