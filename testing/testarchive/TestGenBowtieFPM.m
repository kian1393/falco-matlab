%---------------------------------------------------------------------------
% Copyright 2018-2021, by the California Institute of Technology. ALL RIGHTS
% RESERVED. United States Government Sponsorship acknowledged. Any
% commercial use must be negotiated with the Office of Technology Transfer
% at the California Institute of Technology.
%---------------------------------------------------------------------------
%% Test falco_gen_annular_FPM.m
%
% We define some tests for falco_gen_bowtie_FPM.m to test responses to
% different input parameters. 
classdef TestGenBowtieFPM < matlab.unittest.TestCase    
%% Properties
%
% A presaved file with FALCO parameters was saved and is lodaded to be used
% by methods. In this case we only use the mp.path.falco + lib/utils to
% addpath to utils functions to be tested.
    properties
        mp=Parameters();
    end

%% Setup and Teardown Methods
%
%  Add and remove path to utils functions to be tested.
%
    methods (TestClassSetup)
        function addPath(testCase)
            addpath(genpath([testCase.mp.path.falco filesep 'lib']));
        end
    end
    methods (TestClassTeardown)
        function removePath(testCase)
            rmpath(genpath([testCase.mp.path.falco filesep 'lib']))
        end
    end    
%% Tests
%
%  Creates four tests:
%
% # *testBowtieArea* verify that the area of the bowtie generated by
%                     falco_gen_bowtie_FPM.m is within 0.1% of the
%                     expected area.
% # *testBowtieTranslation* verify that the the actual translation of
%                            the bowtie is equal to the expected translation.
% # *testBowtieshape* Verify that the shape of the bowtie with rund corners
%                     satisfies the constraint sum(abs(diffFillet(:)))/inputs.pixresFPM^2 < pi*inputs.Rfillet^2
% # *testBowtieTranslationRotation* Verify that the translated and rotated 
%                                   bowtie satisties the constraint
%                                   diff<1e-4 where diff = pad_crop(fpmRot, size(fpmOffset))...
%                                   - circshift(fpmRotOffset, -inputs.pixresFPM*[inputs.yOffset, inputs.xOffset]);   
    methods (Test)    
        function testBowtieArea(testCase)
            inputs.pixresFPM = 6; %--pixels per lambda_c/D
            inputs.rhoInner = 2.6; % radius of inner FPM amplitude spot (in lambda_c/D)
            inputs.rhoOuter = 9.4; % radius of outer opaque FPM ring (in lambda_c/D)
            inputs.ang = 65 ;
            inputs.centering = 'pixel';
            fpm = falco_gen_bowtie_FPM(inputs);
            
            % Area test for bowtie
            areaExpected = pi*(inputs.rhoOuter^2 - inputs.rhoInner^2)*(2*inputs.ang/360)*(inputs.pixresFPM^2);
            area = sum(fpm(:));

            import matlab.unittest.constraints.IsEqualTo
            import matlab.unittest.constraints.RelativeTolerance
            testCase.verifyThat(area, IsEqualTo(areaExpected,'Within', RelativeTolerance(0.001)))
        end
        function testBowtieTranslation(testCase)
            inputs.pixresFPM = 6; %--pixels per lambda_c/D
            inputs.rhoInner = 2.6; % radius of inner FPM amplitude spot (in lambda_c/D)
            inputs.rhoOuter = 9.4; % radius of outer opaque FPM ring (in lambda_c/D)
            inputs.ang = 65 ;
            inputs.centering = 'pixel';
            fpm = falco_gen_bowtie_FPM(inputs);
            
            %--Optional Inputs
            inputs.xOffset = 5.5;
            inputs.yOffset = -10;
            
            fpmOffset = falco_gen_bowtie_FPM(inputs);
           
            diff = pad_crop(fpm, size(fpmOffset)) - circshift(fpmOffset, -inputs.pixresFPM*[inputs.yOffset, inputs.xOffset]);
            testCase.verifyLessThan(sum(abs(diff(:))), 1e-8)             
        end
        function testBowtieshape(testCase)
            inputs.pixresFPM = 6; %--pixels per lambda_c/D
            inputs.rhoInner = 2.6; % radius of inner FPM amplitude spot (in lambda_c/D)
            inputs.rhoOuter = 9.4; % radius of outer opaque FPM ring (in lambda_c/D)
            inputs.ang = 65 ;
            inputs.centering = 'pixel';
            
            %--Optional Inputs
            inputs.xOffset = 5.5;
            inputs.yOffset = -10;
            fpmOffset = falco_gen_bowtie_FPM(inputs);
            
            % Test shape of version with rounded corners
            inputs.Rfillet = 0.50;
            fpmOffsetFillet = falco_gen_bowtie_FPM(inputs);
            
            diffFillet = fpmOffset - fpmOffsetFillet;          
            testCase.verifyLessThan(sum(abs(diffFillet(:)))/inputs.pixresFPM^2, pi*inputs.Rfillet^2) 
        end
        function testBowtieTranslationRotation(testCase)
            inputs.pixresFPM = 6; %--pixels per lambda_c/D
            inputs.rhoInner = 2.6; % radius of inner FPM amplitude spot (in lambda_c/D)
            inputs.rhoOuter = 9.4; % radius of outer opaque FPM ring (in lambda_c/D)
            inputs.ang = 65 ;
            inputs.centering = 'pixel';
            
            fpm = falco_gen_bowtie_FPM(inputs);
            
            %--Optional Inputs
            inputs.xOffset = 5.5;
            inputs.yOffset = -10;
            fpmOffset = falco_gen_bowtie_FPM(inputs);
            
            % Test rotation
            inputs.Rfillet = 0;
            inputs.clocking = 90;
            fpmRotOffset = falco_gen_bowtie_FPM(inputs);
            fpmRot = zeros(size(fpm));
            fpmRot(2:end, 2:end) = rot90(fpm(2:end, 2:end));
            diff = pad_crop(fpmRot, size(fpmOffset)) - circshift(fpmRotOffset, -inputs.pixresFPM*[inputs.yOffset, inputs.xOffset]);            
            testCase.verifyLessThan(diff, 1e-4) 
        end
    end    
end