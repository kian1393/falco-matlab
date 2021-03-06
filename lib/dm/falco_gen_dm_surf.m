% Copyright 2018-2021, by the California Institute of Technology. ALL RIGHTS
% RESERVED. United States Government Sponsorship acknowledged. Any
% commercial use must be negotiated with the Office of Technology Transfer
% at the California Institute of Technology.
% -------------------------------------------------------------------------
% 
% Generate a deformable mirror(DM) surface using PROPER.
%
% INPUTS
% ------
% dm: structure of DM parameters
%
% OUTPUTS
% -------
% DMsurf: 2-D DM surface in meters

function DMsurf = falco_gen_dm_surf(dm, dx, N)

%--Set the order of operations
orderOfOps = 'XYZ';
if(isfield(dm,'flagZYX'))
    if(dm.flagZYX)
        orderOfOps = 'ZYX'; 
    end
end

% Adjust the centering of the output DM surface. The shift needs to be in
% units of actuators, not meters, for prop_dm.m.
switch dm.centering % 0 shift for pixel-centered pupil, or -dx/2 shift for inter-pixel centering
    case {'interpixel'}
        cshift = -dx/2/dm.dm_spacing; 
    case {'pixel'}
        cshift = 0;
    otherwise
        error('falco_gen_dm_surf: centering variable must be either pixel or interpixel')
end

%--PROPER initialization
pupil_ratio = 1; % beam diameter fraction
wl_dummy = 1e-6; %--dummy value needed to initialize wavelength in PROPER (meters)
bm = prop_begin(N*dx, wl_dummy, N, pupil_ratio);

%--Apply various constraints to DM commands
dm = falco_enforce_dm_constraints(dm);

%--Quantization of DM actuation steps based on least significant bit of the
% DAC (digital-analog converter). In height, so called HminStep
% If HminStep (minimum step in H) is defined, then quantize the DM voltages
if(isfield(dm,'HminStep') && ~any(isnan(dm.HminStep(:))))
    % If desired method is not defined, set it to the default. 
    if(~isfield(dm,'HminStepMethod'))
        dm.HminStepMethod = 'round';
    end

    % Discretize/Quantize the DM voltages (creates dm.Vquantized)
	dm = falco_discretize_dm_surf(dm, dm.HminStepMethod);
    dm.V = dm.Vquantized;
end

heightMap = falco_calc_act_height_from_voltage(dm);

%--Generate the DM surface
[~, DMsurf] = propcustom_dm(bm, heightMap, dm.xc-cshift, dm.yc-cshift, dm.dm_spacing,...
    'XTILT', dm.xtilt, 'YTILT', dm.ytilt, 'ZTILT', dm.zrot,orderOfOps, ...
    'inf_sign', dm.inf_sign, 'inf_fn', dm.inf_fn);

end %--END OF FUNCTION