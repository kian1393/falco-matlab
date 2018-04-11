% Copyright 2018, by the California Institute of Technology. ALL RIGHTS
% RESERVED. United States Government Sponsorship acknowledged. Any
% commercial use must be negotiated with the Office of Technology Transfer
% at the California Institute of Technology.
% -------------------------------------------------------------------------
%
% function Eout = model_full_SPLC(mp, DM, modvar)
%--Full-knowledge optical model.
%    --> Not used by the estimator and controller.
%    --> Only used to create simulated intensity images.
%
% REVISION HISTORY:
% --------------
% Modified on 2018-01-23 by A.J. Riggs to allow DM1 to not be at a pupil
%  and to have an aperture stop.
% Modified on 2017-10-17 by A.J. Riggs to have model_full.m be a wrapper. All the 
%  actual full models, including this one, have been moved to sub-routines for clarity.
% Modified by A.J. Riggs from hcil_simTestbed.m to model_full.m.
% Modified on 2015-02-18 by A.J. Riggs from hcil_model.m to hcil_simTestbed.m to inclue
%  extra errors in the model to simulate the actual testbed for fake images.
%
% ---------------
% INPUTS:
% -mp = structure of model parameters
% -DM = structure of DM settings
% -modvar = structure of model variables
%
%
% OUTPUTS:
% -Eout
%
% modvar structure fields (4):
% -sbpIndex
% -wpsbpIndex
% -whichSource
% -flagGenMat


function Eout = model_full_SPLC(mp, DM, modvar)

lambda = mp.sbp_center_vec(modvar.sbpIndex)*mp.lamFac_vec(modvar.wpsbpIndex);
mirrorFac = 2; % Phase change is twice the DM surface height.
NdmPad = DM.full.NdmPad;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Input E-fields
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--Set the point source as the exoplanet or the star
if strcmpi(modvar.whichSource, 'exoplanet') %--Don't include tip/tilt jitter for planet wavefront since the effect is minor
    %--The planet does not move in sky angle, so the actual tip/tilt angle needs to scale inversely with wavelength.
    planetAmp = sqrt(mp.c_planet);  % Scale the E field to the correct contrast
    planetPhase = (-1)*(2*pi*(mp.x_planet*mp.P2.full.XsDL + mp.y_planet*mp.P2.full.YsDL));
    Ein = planetAmp*exp(1i*planetPhase*mp.lambda0/lambda);

elseif strcmpi(modvar.whichSource,'offaxis') %--Use for throughput calculations 
    TTphase = (-1)*(2*pi*(modvar.x_offset*mp.P2.full.XsDL + modvar.y_offset*mp.P2.full.YsDL));
    Ett = exp(1i*TTphase*mp.lambda0/lambda);
    Ein = Ett.*mp.P1.full.E(:,:,modvar.wpsbpIndex,modvar.sbpIndex); 
    
else % Default to using the starlight
    %--Include the tip/tilt in the input stellar wavefront
    if(isfield(mp,'ttx'))  % #NEWFORTIPTILT
        x_offset = mp.ttx(modvar.ttIndex);
        y_offset = mp.tty(modvar.ttIndex);

        TTphase = (-1)*(2*pi*(x_offset*mp.P2.full.XsDL + y_offset*mp.P2.full.YsDL));
        Ett = exp(1i*TTphase*mp.lambda0/lambda);
        Ein = Ett.*mp.P1.full.E(:,:,modvar.wpsbpIndex,modvar.sbpIndex);  

    else %--Backward compatible with code without tip/tilt offsets in the Jacobian
%         Ein = mp.Estar(:,:,modvar.wpsbpIndex,modvar.sbpIndex);  
        Ein = mp.P1.full.E(:,:,modvar.wpsbpIndex,modvar.sbpIndex);  
    end
end

fn_PSD = sprintf('maps_PSD_%s.mat',mp.coro);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Masks and DM surfaces
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% %--Set nominal DM plane array sizes as a power of 2 for angular spectrum propagation with FFTs
% NdmPad = 2.^ceil(1 + log2(max([DM.dm1.NdmPad,DM.dm2.NdmPad]))); 
% while( NdmPad < lambda*abs(mp.d_dm1_dm2)/mp.P2.full.dx^2 ) %--Double the zero-padding until the angular spectrum sampling requirement is not violated
%     NdmPad = 2*NdmPad; 
% end

if(any(DM.dm_ind==1)); 
    if( isfield(DM.dm1,'surfM') );   DM1surf = padOrCropEven(DM.dm1.surfM, NdmPad);
    else                            DM1surf = falco_gen_dm_surf(DM.dm1,DM.dm1.dx,NdmPad); end;
else DM1surf = 0;
end
if(any(DM.dm_ind==2)); 
    if( isfield(DM.dm2,'surfM') );   DM2surf = padOrCropEven(DM.dm2.surfM, NdmPad);
    else                            DM2surf = falco_gen_dm_surf(DM.dm2,DM.dm2.dx,NdmPad); end;
else DM2surf = 0;
end

pupil = padOrCropEven(mp.P1.full.mask,NdmPad);
Ein = padOrCropEven(Ein,NdmPad);

if(mp.flagDM1stop); DM1stop = padOrCropEven(mp.dm1.full.mask, NdmPad); else DM1stop = 1; end
if(mp.flagDM2stop); DM2stop = padOrCropEven(mp.dm2.full.mask, NdmPad); else DM2stop = 1; end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Propagation: entrance pupil, 2 DMs, apodizer, binary-amplitude FPM, LS, and final focal plane
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--Define pupil P1 and Propagate to pupil P2
EP1 = pupil.*Ein; %--E-field at pupil plane P1
EP2 = propcustom_2FT(EP1,mp.centering); %--Forward propagate to the next pupil plane (P2) by rotating 180 deg.
% EP2 = rot90(EP1,2); %--Forward propagate to the next pupil plane (P2) by rotating 180 deg.
% if( strcmpi(mp.centering,'pixel') ); EP2 = circshift(EP2,[1 1]); end;   %--To undo center offset when beam and mask are pixel centered and rotating by 180 degrees.

%--Propagate from P2 to DM1, and apply DM1 surface and aperture stop
if( abs(mp.d_P2_dm1)~=0 ); Edm1 = propcustom_PTP(EP2,mp.P2.full.dx*NdmPad,lambda,mp.d_P2_dm1); else Edm1 = EP2; end  %--E-field arriving at DM1
Edm1 = DM1stop.*exp(mirrorFac*2*pi*1i*DM1surf/lambda).*Edm1; %--E-field leaving DM1

%--Propagate from DM1 to DM2, and apply DM2 surface and aperture stop
Edm2 = propcustom_PTP(Edm1,mp.P2.full.dx*NdmPad,lambda,mp.d_dm1_dm2); 
Edm2 = DM2stop.*exp(mirrorFac*2*pi*1i*DM2surf/lambda).*Edm2;

%--Back-propagate to pupil P2, rotate 180 degrees to propagate to pupil P3, and apply the SP mask.
if( mp.d_P2_dm1 + mp.d_dm1_dm2 == 0 ); EP3 = Edm2; else EP3 = propcustom_PTP(Edm2,mp.P2.full.dx*NdmPad,lambda,-1*(mp.d_dm1_dm2 + mp.d_P2_dm1)); end %--Back propagate to pupil P2
EP3 = rot90(EP3,2); %--Forward propagate to the next pupil plane (with the SP) by rotating 180 deg.
if( strcmpi(mp.centering,'pixel') ); EP3 = circshift(EP3,[1 1]); end;   %--To undo center offset when beam and mask are pixel centered and rotating by 180 degrees.
EP3 = mp.P3.full.mask.*padOrCropEven(EP3, mp.P3.full.Narr); %--Apply SP mask.

%--MFT from SP to FPM (i.e., P3 to F3)
EF3inc = propcustom_mft_PtoF(EP3, mp.fl,lambda,mp.P2.full.dx,mp.F3.full.dxi,mp.F3.full.Nxi,mp.F3.full.deta,mp.F3.full.Neta,mp.centering); %--E-field incident upon the FPM
EF3 = mp.F3.full.mask.amp.*EF3inc; % Apply FPM

%--Do NOT apply FPM if normalization value is being found
if(isfield(modvar,'flagGetNormVal'))
    if(modvar.flagGetNormVal==true)
        EF3 = EF3inc;
    end
end    

%--MFT from FPM to Lyot Plane (i.e., F3 to P4)
EP4 = propcustom_mft_FtoP(EF3,mp.fl,lambda,mp.F3.full.dxi,mp.F3.full.deta,mp.P4.full.dx,mp.P4.full.Narr,mp.centering); %--E-field incident upon the Lyot stop 
EP4 = mp.P4.full.croppedMask.*padOrCropEven(EP4,mp.P4.full.Narr);% Apply Lyot stop

%--MFT from Lyot Stop to final focal plane (i.e., P4 to F4)
EF4 = propcustom_mft_PtoF(EP4,mp.fl,lambda,mp.P4.full.dx,mp.F4.full.dxi,mp.F4.full.Nxi,mp.F4.full.deta,mp.F4.full.Neta,mp.centering);


%--Don't apply FPM if normalization value is being found, or if the flag doesn't exist (for testing only)
Eout = EF4; %--Don't normalize if normalization value is being found
if(isfield(modvar,'flagGetNormVal'))
    if(modvar.flagGetNormVal==false)
        Eout = EF4/sqrt(mp.F4.full.I00(modvar.sbpIndex)); %--Apply normalization
    end
elseif(isfield(mp.F4.full,'I00'))
    Eout = EF4/sqrt(mp.F4.full.I00(modvar.sbpIndex)); %--Apply normalization
end


end % End of function


    
