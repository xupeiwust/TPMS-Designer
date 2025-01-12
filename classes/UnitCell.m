classdef UnitCell
    %UnitCell is a class to work with cellular solid structures
    %   UnitCell is designed to work within the TPMS Designer toolbox A
    %   UnitCell can be parametrically defined using an equation, type, two
    %   geometry parameters, resolution, and cell size
    %
    % TPMS Design Package - UnitCell class Created by Alistair Jones, RMIT
    % University 2022.
    
    properties
        type % Type of Cell equation 
        equation % - Equation or path to file describing
        u % Data/Equation describing features
        v1 % Geometry Parameter 1
        v2 % Geometry Parameter 2
        voxelSize % voxelSize (x,y,z)
        tform % Transformal mapping
        FV % SurfMesh Object
        F % V3Field Object
        M % Metrics Object
        B % Object describing the bulk object
    end
    
    methods
        function UnitCell = UnitCell(type,equation,v1,v2,voxelSize,tform,B)
            %Constructor for to initialising the UnitCell object 
            %   Inputs:
            %       type - (string) The type of unit cell (default = "network")
            %       equation - (string) The equation defining the unit cell
            %           (default = "gyroid") 
            %       v1 - (double) First geometric parameter (defualt = 0.5) 
            %       v2 - (double) Second geometric parameter (defualt = 0.5) 
            %       voxelSize - (1,1)(double) Size of a voxel in mm
            %       tform - (4,4)(double) Transform object
            %       B - Structure descirbing the bulk size of the
            %           object, includes a minimum and maxium bounding box coord and possibly other fields to describe the region)
            %   Outputs:
            %   Unit Cell - (UnitCell) UnitCell object
            arguments
                type string = "network";
                equation = "Gyroid";
                v1 double = 0.5; % Geometry parameter 1
                v2 double = 0; % Geometry parameter 2
                voxelSize (1,1) double = [1.0];
                tform = []; % see affinetform3d()
                B = [];
            end
            UnitCell.equation = equation;
            UnitCell.type = type;
            UnitCell.v1 = v1;
            UnitCell.v2 = v2;
            UnitCell.voxelSize = voxelSize;
            UnitCell.M = metrics();

            if isempty(tform)
                UnitCell.tform = rigidtform3d;
            else
                UnitCell.tform = tform;
            end

            if isempty(B) % Default bulk size is one unit cell starting at the origin
                temp = diag(tform.A);
                UnitCell.B = bulkSize('box',temp(1:3)');
            else
                UnitCell.B = B;
            end

            [classPath, ~, ~] = fileparts(mfilename('fullpath')); % Path to current file
            dataPath = fullfile(classPath,'..','data'); % Path to data

            p = [1 0]; % p is a polynomial fit for isovale as a function of volume fraction
            switch UnitCell.equation
                case "Diamond"
                    UnitCell.u = @(x,y,z) ((sin(2*pi*x).*sin(2*pi*y).*sin(2*pi*z)+...
                        sin(2*pi*x).*cos(2*pi*y).*cos(2*pi*z)+...
                        cos(2*pi*x).*sin(2*pi*y).*cos(2*pi*z)+...
                        cos(2*pi*x).*cos(2*pi*y).*sin(2*pi*z)));
                    p = [-15.38 38.56 -35.09 13.99 -4.702 1.315];
                case "Gyroid"
                    UnitCell.u = @(x,y,z) (cos(2*pi*x).*sin(2*pi*y)+ ...
                        cos(2*pi*y).*sin(2*pi*z)+cos(2*pi*z).*sin(2*pi*x));
                    p = [-1.298 3.260 -2.198 0.02743 -2.73 1.47];
                case "Primitive"
                    UnitCell.u = @(x,y,z) (cos(2*pi*x)+cos(2*pi*y)+cos(2*pi*z));
                    p = [-61.24 153.6 -146.2 65.4 -17.13 2.806];
                case "IWP"
                    UnitCell.u = @(x,y,z) 2*(cos(2*pi*x).*cos(2*pi*y)+cos(2*pi*y).*cos(2*pi*z)+...
                        cos(2*pi*z).*cos(2*pi*x))...
                        -(cos(2*x)+ cos(2*y)+ cos(2*z));
                    p = [-91.5 195.6 -153.6 50.62 -9.08 4.715];
                case "Neovius"
                    UnitCell.u = @(x,y,z) (3*(cos(2*pi*x)+cos(2*pi*y)+cos(2*pi*z))+4*cos(2*pi*x).*cos(2*pi*y).*cos(2*pi*z));
                    p = [-370.2 925.3 897.7 421.6 -102.1 11.59];
                case "FRD"
                    UnitCell.u = @(x,y,z) 4*cos(2*pi*x).*cos(2*pi*y).*cos(2*pi*z)-(cos(2*x).*cos(2*y)...
                        +cos(2*y).*cos(2*z)+cos(2*z).*cos(2*x));
                    p = [-93.97 230.6 -222.1 104.6 -26.95 5.805];
                case "Lidinoid"
                    UnitCell.u = @(x,y,z) 0.5*(sin(4*pi*x).*cos(2*pi*y).*sin(2*pi*z)+sin(4*pi*y).*cos(2*pi*z).*sin(2*pi*x)...
                        +sin(4*pi*z).*cos(2*pi*x).*sin(2*pi*y)-cos(4*pi*x).*cos(4*pi*y)-cos(4*pi*y).*cos(4*pi*z)-cos(4*pi*z).*cos(4*pi*x))+0.15;
                    p = [-12.98 41.77 51.33 29.07 -8.839 1.217];
                case "Sinusoidal"
                    UnitCell.u = @(x,y,z) sin(2*pi*x)+...
                        sin(2*pi*y)-(z-pi);
                case "Sphere"
                    UnitCell.u = @(x,y,z)(x-pi).^2+(y-pi).^2+(z-pi).^2-2;
                case "P-normCube"
                    UnitCell.u = @(x,y,z) (x-pi).^10+(y-pi).^10+(z-pi).^10;
                case "Taurus"
                    R = 1; r = 0.1;
                    UnitCell.u = @(x,y,z) (sqrt((x-pi).^2+(y-pi).^2)-R).^2+(z-pi).^2-r.^2;
                case "BCC"
                    [UnitCell.u.nodes,UnitCell.u.struts] = readLattice(fullfile(dataPath,'lattices','BCC.txt'));
                case "BCCXYZ"
                    [UnitCell.u.nodes,UnitCell.u.struts] = readLattice(fullfile(dataPath,'lattices','BCCXYZ.txt'));
                case "Cubic"
                    [UnitCell.u.nodes,UnitCell.u.struts] = readLattice(fullfile(dataPath,'lattices','Cubic.txt'));
                case "FCCXYZ"
                    [UnitCell.u.nodes,UnitCell.u.struts] = readLattice(fullfile(dataPath,'lattices','FCCXYZ.txt'));
                case "Octet"
                    [UnitCell.u.nodes,UnitCell.u.struts] = readLattice(fullfile(dataPath,'lattices','Octet.txt'));
                case "OctetXYZ"
                    [UnitCell.u.nodes,UnitCell.u.struts] = readLattice(fullfile(dataPath,'lattices','OctetXYZ.txt'));
                case "tesseract"
                    [UnitCell.u.nodes,UnitCell.u.struts] = readLattice(fullfile(dataPath,'lattices','tesseract.txt'));
                case "vintiles"
                    [UnitCell.u.nodes,UnitCell.u.struts] = readLattice(fullfile(dataPath,'lattices','vintiles.txt'));
                case "x_cross_grid"
                    [UnitCell.u.nodes,UnitCell.u.struts] = readLattice(fullfile(dataPath,'lattices','x_cross_grid.txt'));
                otherwise
                    if ischar(UnitCell.equation)
                        if endsWith(UnitCell.equation,'.txt') % Custom Lattice
                            [nodes,struts] = readLattice(UnitCell.equation);
                            UnitCell.u.nodes = nodes;
                            UnitCell.u.struts = struts;
                        else % Custom Function @(x,y,z) 
                            UnitCell.u = str2func(UnitCell.equation);
                        end
                    else
                        UnitCell.u = UnitCell.equation;
                    end
            end

            
            switch UnitCell.type
                case "network"
                    UnitCell.v1 = polyval(p,UnitCell.v1);
                case "surface"
                    temp = polyval(p,0.5-UnitCell.v2-UnitCell.v1/2);
                    UnitCell.v2 = polyval(p,0.5-UnitCell.v2+UnitCell.v1/2);
                    UnitCell.v1 = temp;
            end
        end
        
        function out = export(UnitCell)
            %Flatten structure to exportable values
            % Inputs:
            %   Unit Cell - (UnitCell) Self-referenced object
            % Outputs:
            %   out - Struct with flattened (numerical) outputs
            out = UnitCell.M.export;
            out.equation = UnitCell.equation;
            out.type = UnitCell.type;
            out.v1 = UnitCell.v1;
            out.v2 = UnitCell.v2;
            out.voxelSize = UnitCell.voxelSize;
            if isMATLABReleaseOlderThan('R2022b') % Compatability
                out.Lx = UnitCell.tform.T(1,1);
                out.Ly = UnitCell.tform.T(1,2);
                out.Lz = UnitCell.tform.T(1,3);
            else
                out.Lx = UnitCell.tform.A(1,1);
                out.Ly = UnitCell.tform.A(2,2);
                out.Lz = UnitCell.tform.A(3,3);
            end
        end
        
        function h = plot(UnitCell,plottype,property1,property2,opts,ax)
            %Handles plotting returning a handle to the created figure
            % Inputs:
            %   Unit Cell - (UnitCell) Self-referenced object 
            %   plottype - (String) The type of plot Valid inputs include
            %       'SurfMesh' (defualt), 'voxel',
            %       'orthoslice', 'slice', 'histogram', 'histogram2',
            %       'polemap', 'tensor', 'lattice'
            %   property1 - (String) Name of the primary property being
            %       visualised. Defaults to 'inclination'
            %   property2 - (String) Name of the secondary property being
            %       visualised. Defaults to 'azimuth'. This is other used
            %       for vectormapping on a SurfMesh and histogram2 plots
            %   opts - Options, additional parameter based on plot type
            %       opts.fancy (boolean): use fancy graphics styling (default=1), 
            %       opts.caps (int): 0=dont plot, 1=plot without color, 2=plot with color  
            %       opts.s (int): select the slice height %
            %       (0-100) opts.n (int): set the number of bins for
            %           histogram/histogram2/polemap
            %   ax - graphics object to plot on
            % Outputs:
            %   h - Handle to the created graphical object
            arguments
                UnitCell;
                plottype string = "SurfMesh";
                property1 string = "inclination";
                property2 string = "azimuth";
                opts = [];
                ax = [];
            end
            

            switch plottype
                case "voxel"
                    h = UnitCell.F.plotField(property1,"voxel",opts,ax);
                case "orthoslice"
                    h = UnitCell.F.plotField(property1,"orthoslice",opts,ax);
                case "slice"
                    if isfield(opts,'slice')
                        s = opts.slice;
                    else
                        s = 50;
                    end
                    h= UnitCell.F.plotField(property1,s,ax);
                case "histogram"
                    h = plotHistogram(UnitCell,property1,opts,ax);
                case "histogram2"
                    h = plotHistogram2(UnitCell.FV,property1,property2,opts,ax);
                case "polemap"
                    if isfield(opts,'n')
                        n = opts.n;
                    else
                        n = 3;
                    end
                    h = plotPoleFig(UnitCell.FV,n,opts,ax);
                case "tensor"
                    h = plotTensor(UnitCell.F.CH,ax);
                case "lattice"
                    h = plotLattice(UnitCell.u.nodes,UnitCell.u.struts,ax);
                otherwise
                    h = UnitCell.FV.plotMesh(property1,property2,0.8,[],ax);
            end
        end
        
        
        function UnitCell = compute(UnitCell,computeCurvature,computeMechanical,computeMesh)
            %Function to generate the unit cell and compute various
            % properties Inputs:
            %   Unit Cell - (UnitCell) Self-referenced object
            %   computeCurvature - (String) The method for curvature
            %       including 'trimesh2', 'meyer2003', 'implicit', 'none'
            %       see SurfMesh.calculateProperties() for more info.
            %   computeMechanical - (logical) (default = 1) 
            %   computeMesh - (logical) (default = 1)
            % Outputs:
            %   Unit Cell - (UnitCell) Self-referenced object with
            %       calcualted properties
            arguments
                UnitCell;
                computeCurvature = 'none';
                computeMechanical = 0;
                computeMesh = 1;
            end

            % Start the timer
            tic; 

            
            % Compute SDF and properties
            if isempty(UnitCell.F)
                if strcmp(UnitCell.type,'lattice') %Handle Lattices
                    UnitCell.u.rstrut = UnitCell.v1;
                    UnitCell.u.rnode = UnitCell.v2;
                    UnitCell.F = v3Field('lattice',UnitCell.u,UnitCell.voxelSize,UnitCell.B,UnitCell.tform);
                else
                    UnitCell.F = v3Field("TPMS",UnitCell,UnitCell.voxelSize,UnitCell.B,UnitCell.tform);  % Move to discretized space centred at origin
                end
            end

            % Calculate derived properties
            UnitCell.F = UnitCell.F.calculateProperties(computeCurvature,UnitCell);

            % Generate the SurfMesh
            if computeMesh&&isempty(UnitCell.FV) 
                UnitCell.FV = SurfMesh('TPMS',UnitCell);
                UnitCell.FV = UnitCell.FV.calculateProperties(computeCurvature,UnitCell);
                UnitCell.M = UnitCell.M.fvMetrics(UnitCell.FV);                
                temp = diag(UnitCell.tform.A)';
                UnitCell.M.relativeArea = UnitCell.M.surfaceArea./...
                    (2*(temp(1)*temp(2)+temp(2)*temp(3)+temp(3)*temp(1)));
            end

            % Run Homogenisation
            if computeMechanical  
                UnitCell.F = UnitCell.F.homogenise();
            end

            %Volume Metrics
            UnitCell.M = UnitCell.M.mechanicalMetrics(UnitCell.F); 

            %Calculate the total computational time
            UnitCell.M.CPUtime = toc; 
        end
    end
end
