classdef v3Field
    %v3Field is a class to deal with 3D volume data
    %   v3Fields can be created from an implicit function, SurfMesh, or
    %   lattice structure (defined by the nodes and struts).
    %
    %   The v3Field class comes with visualisation options to look at a
    %   particular slice, orthographic slice viewer, or voxelated object
    %
    %   v3Fields representing periodic unit cells (such as TPMS or lattices) may be assessed
    %   for mechanical properties using homogenisation with periodic boundary conditions
    %
    % TPMS Design Package - v3Field class
    % Created by Alistair Jones, RMIT University 2022.

    properties
        name
        lower
        upper
        voxelSize
        xq
        yq
        zq
        property
        zSlices
        CH
    end

    methods
        function F = v3Field(method,data,voxelSize,region,tform)
            %v3Field(method,data,res,region) construct an instance of this class
            %   optional inputs:
            %             method -> defines the method to be used
            %             data -> the data to generate the v3field
            %             res (3,1) double = [30; 30; 30];
            %             region - bulkSize object describing the design
            %               volume
            %
            %   returns: the v3Field object
            arguments
                method string = "sample";
                data = [];
                voxelSize (1,1) double = [1.0];
                region = [];
                tform = [];
            end

            % Determine the bounds
            if isempty(region)
                F.lower = [-10 -10 -10];
                F.upper = [10 10 10];
            else
                F.lower = region.bbox(1,:);
                F.upper = region.bbox(2,:);
            end
            F.voxelSize = voxelSize;

            % Settup The Meshgrid
            F.xq = F.lower(1):voxelSize:F.upper(1);
            F.yq = F.lower(2):voxelSize:F.upper(2);%linspace(F.lower(2),F.upper(2),res(2));
            F.zq = F.lower(3):voxelSize:F.upper(3);%linspace(F.lower(3),F.upper(3),res(3));
            [F.property.X,F.property.Y,F.property.Z] = meshgrid(F.xq,F.yq,F.zq);
            if ~isempty(tform)
                [Xt, Yt, Zt] = transformPointsInverse(tform,F.property.X,F.property.Y,F.property.Z);
            else
                Xt = F.property.X; Yt =F.property.Y; Zt = F.property.Z;
            end

            switch method
                case "FV"
                    temp.faces = data.faces;
                    res = round((F.upper-F.lower)/voxelSize);
                    temp.vertices = 1+(1-1./res).*((data.vertices-F.lower)./voxelSize);
                    F.property.surface = 1.0*voxelateMesh(temp,[res(2),res(1),res(3)],'wrap',true);
                    F.property.solid = imfill(1.0*F.property.surface);
                    F.property.U = voxelSize.*double(1.0.*(bwdist(F.property.solid)-bwdist(1.0-F.property.solid)));
                case "data"
                    F.property.U = data;
                    F.property.solid = 1.0*(F.property.U<=0);
                case "lattice"
                    if isstring(data)
                        filepath = strcat("data/lattices/",data,".txt");
                        [nodes,struts] = readStrut(filepath); % get the information of strut
                    elseif isfield(data,'nodes')
                        nodes = data.nodes;
                        struts = data.struts;
                    else
                        filepath = "data/lattices/BCC.txt";
                        [nodes,struts] = readStrut(filepath); % get the information of strut
                    end

                    if isfield(data,'rnode')
                        rnode = data.rnode;
                    else
                        rnode = 0.1;
                    end

                    if isfield(data,'rstrut')
                        rstrut = data.rstrut;
                    else
                        rstrut = 0.1;
                    end

                    sz = diag(tform.A)';
                    [F.property.solid, F.property.U] = voxelateLattice(F.property.X,F.property.Y,F.property.Z,sz(1:3),nodes,struts,rstrut,rnode);
                case "imagestack"
                    % Select a folder to import a stack of images from
                    if isstring(data)
                        F.property.U = readImageStack(data,Xt,Yt,Zt);
                    else
                    end

                case "TPMS"
                    % Resample v1
                    if size(data.v1,1)==1
                        data.v1(2,:,:) = data.v1(1,:,:);
                    end
                    if size(data.v1,2)==1
                        data.v1(:,2,:) = data.v1(:,1,:);
                    end
                    if size(data.v1,3)==1
                        data.v1(:,:,2) = data.v1(:,:,1);
                    end

                    % Resample v2
                    if size(data.v2,1)==1
                        data.v2(2,:,:) = data.v2(1,:,:);
                    end
                    if size(data.v2,2)==1
                        data.v2(:,2,:) = data.v2(:,1,:);
                    end
                    if size(data.v2,3)==1
                        data.v2(:,:,2) = data.v2(:,:,1);
                    end


                    F.property.V1 = voxelResize(data.v1,size(Xt));
                    F.property.V2 = voxelResize(data.v2,size(Xt));


                    % Initialise the Field for the TPMS using equation u.
                    switch data.type
                        case "surface"
                            F.property.U = (data.u(Xt,Yt,Zt)+F.property.V1).*(data.u(Xt,Yt,Zt)+F.property.V2);
                        case "double"
                            F.property.U = (data.u(Xt,Yt,Zt)+F.property.V1).*(data.u(Xt,Yt,Zt)+F.property.V2);
                        case "single"
                            F.property.U = data.u(Xt,Yt,Zt)+F.property.V1;
                        otherwise
                            F.property.U = data.u(Xt,Yt,Zt)+F.property.V1;
                    end

                    % Trim to non-cubic bounding box data
                    switch region.method
                        case "cylinder"
                            temp = (F.property.X/F.upper(1)).^2+(F.property.Y/F.upper(2)).^2-1;
                            F.property.U = max(F.property.U,temp);
                        case "FV"
                            temp.faces = region.FV.faces;
                            res = 1+(F.upper-F.lower)/voxelSize;
                            temp.vertices = 1+(1-1./res).*((region.FV.vertices-F.lower)./F.voxelSize);
                            surface = 1.0*voxelateMesh(temp,[res(2),res(1),res(3)],'wrap',true);
                            solid = imfill(1.0*surface);
                            tempU = double(1.0.*(bwdist(solid)-bwdist(1.0-solid)));
                            F.property.U = max(F.property.U,tempU);
                    end

                    F.property.solid = 1.0*(F.property.U<=0);
            end
        end

        function F = calculateProperties(F,method,TPMS)
            %Evaluate the values of the field
            %Inputs
            %   method - method for volumetric differentiation
            %   TPMS - the TPMS object for implicit differentiation (optional)
            arguments
                F;
                method string = [];
                TPMS = [];
            end
            p = F.property;



            if strcmp("implicit",method) % Use implicit differentiation to calculate proeprties
                % Computationally cheap properties
                [~,p.V3Azimuth,elevation] = imgradient3(imgaussfilt3(F.property.U, 0.5),'sobel');
                p.V3inclination = 90+elevation;
                [l, w, h] = size(F.property.X);
                points = [reshape(F.property.X,[l*w*h,1,1]) reshape(F.property.Y,[l*w*h,1,1]) reshape(F.property.Z,[l*w*h,1,1])];
                [GC, MC, k1, k2] = curvatureImplicit(TPMS.u,points,TPMS.tform);
                p.V3k1 = reshape(max(min(k1,10),-10),[l,w,h]);
                p.V3k2 = reshape(max(min(k2,10),-10),[l,w,h]);
                p.V3GC = reshape(max(min(GC,10),-10),[l,w,h]);
                p.V3MC = reshape(max(min(MC,10),-10),[l,w,h]);
            end


            % Manufacturability using elipsoidal weighting filter -> 1 = perfect, 0 = empty space
            n = floor(4/F.voxelSize)*2+1; nq = linspace(-1,1,n); [q1, q2, q3] = ndgrid(nq,nq,nq);
            c = 10; % Scaling function for shape of heat input
            H = (c/sqrt(2*pi).*exp(-(q1.^2/2)-(q2.^2/2)))+q3;
            H(:,:,ceil(n./2)) = 0.2.*H(:,:,ceil(n./2)); % Set current plane properties
            H(:,:,(ceil(n./2)+1):n) = zeros(n,n,floor(n./2)); % Ignore the top half of the volume
            H = H./sum(H,'all'); % Normalise distribution to account for variation in voxelsize

            temp = zeros(size(F.property.solid,1)+2*n,size(F.property.solid,2)+2*n,size(F.property.solid,3)+n); % "Air" Padding
            temp(:,:,1:n) = ones(size(F.property.solid,1)+2*n,size(F.property.solid,2)+2*n,n); % "Build Platten" Padding Below
            temp(n+1:n+size(F.property.solid,1),n+1:n+size(F.property.solid,2),n+1:n+size(F.property.solid,3)) = F.property.solid; % Placing the Part
            temp = min(1,imfilter(temp,H)); % Apply convolutional filter
            
            p.V3buildRisk = F.property.solid-temp(n+1:n+size(F.property.solid,1),n+1:n+size(F.property.solid,2),n+1:n+size(F.property.solid,3)).*F.property.solid;
            p.V3buildRisk(F.property.solid==0) = nan;
            F.property = p;

            [nx, ny, nz] = size(F.property.solid);
            for i = 1:nz
                % Pad to account for periodic boundary conditions
                temp = padarray(F.property.solid(:,:,i),[nx ny],'circular','both');
                temp = bwdist(1-temp);
                temp = temp(nx+1:(2*nx),ny+1:(2*ny));
                XY.maxthickness(i) = max(temp,[],'all')*F.voxelSize;
                XY.area(i) = sum(F.property.solid(:,:,i),'all')*F.voxelSize^2;
            end
            F.zSlices = XY;
        end

        function F = homogenise(F,E1,v1,E2,v2,method)
            %homogenise the unit cell using periodic boundary conditions
            arguments
                F;
                E1 (1,1) double = 1; % Elastic Modulus solid
                v1 (1,1) double = 0.33; % Poisson's Ratio solid
                E2 (1,1) double = 0; % Elastic Modulus secondary
                v2 (1,1) double = 0; % Poisson's Ratio secondary
                method string = 'pcg'; % Solver method
            end

            lambda1 = E1*v1/((1+v1)*(1-2*v1));
            mu1 = E1/(2+2*v1);
            lambda2 = E2*v2/((1+v2)*(1-2*v2));
            mu2 = E2/(2+2*v2);
            try
                F.CH = computeStiffness(F.upper(1),F.upper(2),F.upper(3),lambda1,mu1,lambda2,mu2,...
                    F.property.solid,method);
            catch % If homogenisation fails return NaN
                F.CH = NaN(6,6);
            end
        end

        function h = plotField(F,pName,zslice,opt,ax)
            %% Uses 'orthosliceviewer', 'slice' or a voxel represenation to visualise a V3Field
            % Inputs:
            %   F - (self)
            %   ax - Axis to plot field on
            %   pName - property to investigate
            %   zslice - z height as a percentage of the total height to slice (between 0 and 100),
            %           input [] to use the orthosliceviewer,
            %           input anything else to plot a voxelated representation
            % Outputs:
            %   h - handle to created object
            % Example:
            %   h = F.plotField('Nz',50)
            %   Credit: Alistair Jones, 2022, RMIT University
            arguments
                F;
                pName string = 'U';
                zslice = 50;
                opt = [];
                ax = [];
            end

            if isempty(ax)
                figure; ax = gca; 
                if ~isnumeric(zslice)
                    rotate3d(ax,'on'); view(ax,62,31); % Set 3D view as nessecary
                end
            end

            pID = convertStringsToChars(extractBefore(pName+" ", " "));
            if isfield(F.property,pID)
                cData = F.property.(pID);
            else
                cData = F.(pID);
            end

            if isnumeric(zslice)
                z = F.lower(3)+zslice/100*range(F.zq,'all');
                [Xq, Yq, Zq] = ndgrid(F.xq,F.yq,z);
                xyslice = interp3(F.xq,F.yq,F.zq,cData,Xq,Yq,Zq);
                h = surf(ax,Yq,Xq,Zq,xyslice,'LineStyle','none');
                colormap(ax,"jet"); view(ax,2);
            elseif strcmp(zslice,'orthoslice')
                cData(isnan(cData))=-1;
                h = orthosliceViewer(flip(permute(cData,[3,1,2]),1),'Parent',ax.Parent,'Colormap',[0 0 0; flipud(jet)]);
            else
                h = plotVoxel(F,pName,opt,ax);
            end
        end


        function exportINP(F,filename)
            % Prepare voxel data for writing to INP file
            res = size(F.property.solid);
            im = F.property.solid(1:(res-1),1:(res-1),1:(res-1));
            [rows, cols, sli]  = size(im);
            ele_ind_vector = find(im == 1);
            num_ele = size(ele_ind_vector, 1);
            ele_temp = zeros(num_ele, 10);

            for j = 1: num_ele
                % subscript of element in im
                [ row, col, sli ] = ind2sub( [rows, cols, sli], ele_ind_vector(j) );

                % get linear index of eight corner of voxel(row,col,sli) in
                % nodecoor_list
                Lind_8corner = [
                    (col-1)*(rows+1) + row + (rows+1)*(cols+1)*(sli-1), ...
                    col*(rows+1) + row + (rows+1)*(cols+1)*(sli-1), ...
                    col*(rows+1) + row + 1 + (rows+1)*(cols+1)*(sli-1), ...
                    (col-1)*(rows+1) + row + 1 + (rows+1)*(cols+1)*(sli-1), ...
                    (col-1)*(rows+1) + row + (rows+1)*(cols+1)*sli, ...
                    col*(rows+1) + row + (rows+1)*(cols+1)*sli, ...
                    col*(rows+1) + row + 1 + (rows+1)*(cols+1)*sli, ...
                    (col-1)*(rows+1) + row + 1 + (rows+1)*(cols+1)*sli
                    ];
                % put Lind_8corner into
                ele_temp( j, : ) = [ ele_ind_vector(j), 1, Lind_8corner ];
            end
            ele_cell{1} = ele_temp;

            elements.E_ind = ele_temp(:,1);
            elements.E = ele_temp(:,3:10);

            % Generate unique nodes list
            node_ind_cell = cellfun( @(A) unique(A(:,3:10)), ele_cell, 'UniformOutput', 0 );
            unique_node_ind_v = unique( cell2mat( node_ind_cell ) );    % column vector

            % generate x y z coordinate of all nodes
            % can be accessed by X( row, col, sli ), Y( row, col, sli ),
            % Z( row, col, sli )
            [ X, Y, Z ] = ndgrid(F.xq, F.yq, F.zq);

            % reshape into vector
            % can be accessed by X(i), Y(i), Z(i)
            X = X(:);
            Y = Y(:);
            Z = Z(:);

            % extract certain nodes
            X = X( unique_node_ind_v );
            Y = Y( unique_node_ind_v );
            Z = Z( unique_node_ind_v );

            num_node = length( unique_node_ind_v );
            % temporary list for parfor
            temp_list = zeros( num_node, 3 );

            for i = 1: num_node
                temp_list( i, : ) = [ X(i), Y(i), Z(i) ];
            end
            nodeStruct.N_ind = unique_node_ind_v;
            nodeStruct.N = temp_list;
            elements.E_type = '*ELEMENT, TYPE=C3D8R, ELSET=TPMSDesigner-Elements';

            % Perform writing using template format
            writeINP(elements,nodeStruct,filename);
        end
    end
end

