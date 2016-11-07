% <strong>ParforProgMon</strong> - CLASS Progress monitor for `parfor` loops
%
% <strong>Usage</strong>
% Begin by creating a parallel pool.
%
% Then construct a <a href="matlab:help ParforProgMon">ParforProgMon</a> object:
% ppm = <a href="matlab:help ParforProgMon">ParforProgMon</a>(strWindowTitle, nNumIterations <, nProgressStepSize, nWidth, nHeight>);
%
% 'strWindowTitle' is a string containing the title of the progress bar
% window. 'nNumIterations' is an integer with the total number of
% iterations in the loop.
%
% <strong>Optional arguments</strong>
% 'nProgressStepSize' specifies to update the progress bar every time this
% number of steps passes. 'nWidth' and 'nHeight' specify the size of the
% progress window.
%
% <strong>Within the parfor loop</strong>
% parfor (nIndex = 1:nNumIterations)
%    ppm.increment();
% end
%
% Modified from <a href="https://www.mathworks.com/matlabcentral/fileexchange/31673-parfor-progress-monitor-v2">ParforProgMonv2</a>.

classdef ParforProgMon < handle
   
   properties ( GetAccess = private, SetAccess = private )
      Port
      HostName
      strAttachedFilesFolder
   end
   
   properties (Transient, GetAccess = private, SetAccess = private)
      JavaBit
   end
   
   methods ( Static )
      function o = loadobj( X )
         % loadobj - METHOD REconstruct a ParforProgMon object
         
         % Once we've been loaded, we need to reconstruct ourselves correctly as a
         % worker-side object.
         % fprintf('Worker: Starting with {%s, %f, %s}\n', X.HostName, X.Port, X.strAttachedFilesFolder);
         o = ParforProgMon( {X.HostName, X.Port, X.strAttachedFilesFolder} );
      end
   end
   
   methods
      function o = ParforProgMon(strWindowTitle, nNumIterations, nProgressStepSize, nWidth, nHeight)
         % ParforProgMon - CONSTRUCTOR Create a ParforProgMon object
         % 
         % Usage: ppm = ParforProgMon(strWindowTitle, nNumIterations <, nProgressStepSize, nWidth, nHeight>)
         % 
         % 'strWindowTitle' is a string containing the title of the
         % progress bar window. 'nNumIterations' is an integer with the
         % total number of iterations in the loop. 'nProgressStepSize'
         % indicates after how many iterations progress is shown. 'nWidth'
         % indicates the width of the progress window. 'nHeight' indicates
         % the width of the progress window.
         
         % - Are we a worker or a server?
         if ((nargin == 1) && iscell(strWindowTitle))
            % - Worker constructor
            % Get attached files
            o.strAttachedFilesFolder = getAttachedFilesFolder(strWindowTitle{3});
            % fprintf('Worker: Attached files folder on worker is [%s]\n', o.strAttachedFilesFolder);
                        
            % Add to java path
            javaaddpath(o.strAttachedFilesFolder);
            
            % "Private" constructor used on the workers
            o.JavaBit   = ParforProgressMonitor.createWorker(strWindowTitle{1}, strWindowTitle{2});
            o.Port      = [];
            
         elseif (nargin > 1)
            % - Server constructor
            % Check arguments
            if (~exist('nProgressStepSize', 'var'))
               nProgressStepSize = 1;
            end
            
            if (~exist('nWidth', 'var'))
               nWidth = 300;
               nHeight = 80;
            end
            
            % Check for an existing pool
            pPool = gcp('nocreate');
            if (isempty(pPool))
               error('ParforProgMon:NeedPool', ...
                     '*** ParforProgMon: You must construct a pool before creating a ParforProgMon object.');
            end
            
            % Amend java path
            strPath = fileparts(which('ParforProgMon'));
            o.strAttachedFilesFolder = fullfile(strPath, 'java');
            % fprintf('Server: JAVA class folder is [%s]\n', o.strAttachedFilesFolder);
            javaaddpath(o.strAttachedFilesFolder);
            
            % Distribute class to pool            
            pPool.addAttachedFiles(o.strAttachedFilesFolder);
            
            % Normal construction
            o.JavaBit   = ParforProgressMonitor.createServer( strWindowTitle, nNumIterations, nProgressStepSize, nWidth, nHeight );
            o.Port      = double( o.JavaBit.getPort() );
            % Get the client host name from pctconfig
            cfg         = pctconfig;
            o.HostName  = cfg.hostname;
         end
      end
      
      function X = saveobj( o )
         % saveobj - METHOD Save a ParforProgMon object for serialisations
         
         % Only keep the Port, HostName and strAttachedFilesFolder
         X.Port     = o.Port;
         X.HostName = o.HostName;
         X.strAttachedFilesFolder = o.strAttachedFilesFolder;
      end
      
      function increment( o )
         % increment - METHOD Indicate that a single loop execution has finished
         
         % Update the UI
         if (~isempty(o.JavaBit))
            o.JavaBit.increment();
         end
      end
      
      function delete( o )
         % delete - METHOD Delete a ParforProgMon object
         
         % Close the UI
         if (~isempty(o.JavaBit))
            o.JavaBit.done();
         end
      end
   end
end
