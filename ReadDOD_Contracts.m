%% V0 - Pull DOD Contract Information
%
% This script will pull in all new contracts and recommend ones outside of
% average distributions to purchase and then give certain informaiton on
% how well the stock did on average when a contract comes through that
% company.
%

clear;clc;

%% Variables + Explination to variables
%
% All these variables appropriately add and subtract functionality to the
% parsing and analysis of the datasets pulled in
%
% ** Indicates a future functionality
%

urlHEAD = 'https://www.defense.gov/News/Contracts/';

getPastData = true; % This will enable getting x amount of data from the websites to analyze & post process for future reference.
pastWeeks = 200; % How many weeks worth of data we want to see
ignoreDates = {}; % input of dates to igore. This can be of form 11-22-63, mo-day-year
saveData = true; % Tells program to save or not save the data
OldDataSel = 'largestdataset'; % we can do 'oldestversion','newestversion','largestdataset','smallestdataset'
CompareToPlots = false; % Pull in the most recent week of data and compare it to the past data we have, or newly pulled in data we have
% ** future genPPT = true; % The past data will be plopped in a ppt with graphs and it will be happy :)

% Cd to current path for getting the version savepath
filePath = matlab.desktop.editor.getActiveFilename;
z = length(filePath);
while ~strcmpi(filePath(z),'\')
    z = z - 1;
end
pathway = filePath(1:z);
cd(pathway);
% Make folders for data
if ~isfolder('rawData')
    mkdir('rawData');
end

%**************************************************************************
%**************************************************************************
%**************************************************************************

%% Main Function
%
% This is the main function of the script that will run other functions in
% order to get the data correctly pulled in
%
try
    %********** We need to make a new dataset, or load in an old one to
    %           compare to todays contracts
    %
    dateRun = datetime('today'); % Get todays date, mostly for updating the file to log when this run was done + the .mat file to point to for that data point
    if getPastData
        dateDiff = dateRun - (pastWeeks*7); % Get todays date - total number of weeks we're collection data for
        % Get the URL's and Dates for the contract article links
        [URLcell,URLdates] = getURLs(urlHEAD,pastWeeks); % This function will get all the URL's for data
        [Branch,Cash,Company,Date] = getHistory(URLcell,URLdates); % This function will parse each contract into the proper branch, the amount of $, the company name, & date of the contract
        DataTable = table(Branch,Cash,Company,Date); % Generate a table worth looking at by someone trying to analyze the data themself
        [perBranch,perComp,perYear] = ReOrg_Data(Branch,Cash,Company,Date); % This function will just reorganize the data into different cell structures to plot the data differently
        
        % Save the data
        if saveData
            % We want to save the following: dateRun, perBranch, perComp, perYear, Cash
            savename = strrep(sprintf('%srawData\\Data_%s_to_%s',pathway,dateDiff,dateRun),'-','_');
            initSavename = savename; z = 0;
            while isfile([pathway,savename,'.mat'])
                savename = [initSavename,'_',num2str(z)];
                z = z+1;
            end
            save([savename,'.mat'],'dateRun', 'perBranch', 'perComp', 'perYear', 'Cash', 'Date'); % Save the data
            logReadback = logUpdate(savename,pathway,dateRun); % Write to the log telling what data we just created.
            
        end
        % Re-write file to update to latest date of data run
        %         DefineLatestData(Date); % Update the file defining the newest data (Maybe a future function)
    else
        [loadName,ValidData] = PullOldData(OldDataSel,pathway); % this function will load in the oldest data
        if ValidData
            load(loadName);
        else
            warning('no old data found');
        end
    end
    
    if CompareToPlots == true
        % If we are comparing, then I want to pull in the last weeks worth
        % of data to plot against the past data.
        [URLcell_1wk,URLdates_1wk] = getURLs(urlHEAD,1); % This function will get all the URL's for data
        [Branch_1wk,Cash_1wk,Company_1wk,Date_1wk] = getHistory(URLcell_1wk,URLdates_1wk); % This function will parse each contract into the proper branch, the amount of $, the company name, & date of the contract
        DataTable_1wk = table(Branch_1wk,Cash_1wk,Company_1wk,Date_1wk); % Generate a table worth looking at by someone trying to analyze the data themself
        [perBranch_1wk,perComp_1wk,perYear_1wk] = ReOrg_Data(Branch_1wk,Cash_1wk,Company_1wk,Date_1wk); % This function will just reorganize the data into different cell structures to plot the data differently
        plotData(pathway,perBranch,perComp,perYear,Cash,PastDates,CompareToPlots,perBranch_1wk,perComp_1wk,perYear_1wk,Cash_1wk,[char(dateRun-7),'_to_',char(dateRun)]);
    else % We'll just plot the loaded in data
        %         PastDates =
        plotData(pathway,perBranch,perComp,perYear,Cash,PastDates,CompareToPlots,[],[],[],[],[]);
    end
    
catch ME
    debugstop = true;
end

%**************************************************************************
%**************************************************************************
%**************************************************************************

%% function [urlCELL,dateOut] = getURLs(overheadURL,earliestDate)
%
% This function will get the URL's for the contracts for each specific
% date.
%
% Inputs:
%       - overheadURL = the url for the main page containing the links
%       - earliestDate = the amount of weeks prior to today will be the
%                        earlierst URL dataset that we can get
%
% Outputs:
%       - urlCell = a cell array of the url links for each of the contracts
%                   articles.
%       - dateOut = a cell array of the dates for each of the contract
%                   articles.
%

% for the sake of debugging
% overheadURL = urlHEAD;
% earliestDate = 2;%PastDataTime;

function [urlCell,dateOut] = getURLs(overheadURL,earliestDate)
try
    % just pre-allocate to return something with an error
    urlCell = {};
    dateOut = {};
    index = 1; % The master Index for incrementing urlCell and dataOut variables when building the strings
    
    dateToday = datetime('today'); % Determine todays date, for finding the last date we care for
    lastDate = dateToday - (earliestDate*7); % We multiply by 7 because the number given is in weeks
    hitMaxDate = false; % pre-allocate that we will eventually get a max date & wanna escape
    
    % The first url we'll be working from is the one given. Eventually we'll work down further pages to add in data.
    currURL = overheadURL;
    esc = false;
    Page = 1; % for changing pages as we increase getting url data
    while esc == false
        
        % Load the URL, occassionally a timeout can occur, so some 
        Try = 0;
        maxTry = 3;
        while Try < maxTry
            try
                url_str = webread(currURL);
            catch
                Try = Try + 1;
            end
            break;
        end
        if Try>=maxTry
            warning('Could not open URL... Timeout occured.')
            break;
        end
        
        %***** Get the contract section of strings so we can identify links + dates
        ContractLineStrt = strfind(url_str,'<listing-titles-only');
        ContractLineFin = strfind(url_str,'</listing-titles-only>');
        
        if length(ContractLineStrt) == length(ContractLineFin)
            for n = 1:1:length(ContractLineStrt)
                ContractString{n} = url_str(ContractLineStrt(n):ContractLineFin(n));
            end
        else
            warning('was unable to identify the contract article characters');
            debugME = true;
            return
        end
        %**********************************************************************
        %***** get Date information for each of these contract reporting periods
        compStr = 'publish-date-ap=';
        compStrLen = length(compStr);
        for n = 1:1:length(ContractString)
            dateStrStrt = strfind(ContractString{n},compStr)+compStrLen;
            notfound = true; % mostly for debugging purposes, strictly to find out if there are spaces between 'publish-date-ap=' and thew first '"'
            while notfound == true
                if strcmpi(ContractString{n}(dateStrStrt),'"')
                    % Build the date string here.
                    currIndx = dateStrStrt+1;
                    q = 1;
                    while ~strcmpi(ContractString{n}(currIndx),'"')
                        dateStr{n}(q) = ContractString{n}(currIndx);
                        currIndx = currIndx + 1;
                        q = q + 1;
                    end
                    notfound = false;
                else
                    dateStrStrt = dateStrStrt + 1; % Index to try and find the first '"'
                    if dateStrStrt >= length(ContractString{n}) % If we never find the first '"', then we need to escape.
                        warning('Could not get a date from a contract');
                        debugME = true;
                        return
                    end
                end
            end
        end
        %**********************************************************************
        %***** get URL information for each of these contract reporting periods
        compStr = 'article-url=';
        compStrLen = length(compStr);
        for n = 1:1:length(ContractString)
            urlStrStrt = strfind(ContractString{n},compStr)+compStrLen;
            notfound = true; % mostly for debugging purposes, strictly to find out if there are spaces between 'publish-date-ap=' and thew first '"'
            while notfound == true
                if strcmpi(ContractString{n}(urlStrStrt),'"')
                    % Build the date string here.
                    currIndx = urlStrStrt+1;
                    q = 1;
                    while ~strcmpi(ContractString{n}(currIndx),'"')
                        urlStr{n}(q) = ContractString{n}(currIndx);
                        currIndx = currIndx + 1;
                        q = q + 1;
                    end
                    notfound = false;
                else
                    urlStrStrt = urlStrStrt + 1; % Index to try and find the first '"'
                    if urlStrStrt >= length(ContractString{n}) % If we never find the first '"', then we need to escape.
                        warning('Could not get a url from a contract');
                        debugME = true;
                        return
                    end
                end
            end
        end
        %**********************************************************************
        %***** reformat the date to a form that can be compared in MATLAB
        DefinedMonths = {'Jan.','Feb.','March','April','May','June','July','Aug.','Sept.','Oct.','Nov.','Dec.'}; % These are the strings identified by URL reads on the DOD'd page
        MonthReplace = {'jan','feb','mar','apr','may','june','july','aug','sep','oct','nov','dec'}; % How MATLAB wants to see it
        
        for n = 1:1:length(ContractString)
            
            % get month
            for q = 1:1:length(DefinedMonths)
                if ~isempty(strfind(dateStr{n},DefinedMonths{q}))
                    month = MonthReplace{q};
                    break;
                end
            end
            
            % get day
            dayIndex = length(DefinedMonths{q})+2;
            day = '';
            while ~strcmpi(dateStr{n}(dayIndex),',')
                day = [day,dateStr{n}(dayIndex)];
                dayIndex = dayIndex + 1;
            end
            
            % get year
            yearIndex = strfind(dateStr{n},',')+2;
            year = '';
            for z = yearIndex:1:yearIndex+3
                year = [year,dateStr{n}(z)];
            end
            
            % Now, reformat
            dateStrFixed{n} = sprintf('%s-%s-%s',day,month,year);
        end
        
        %**********************************************************************
        %***** compare dates to see if we hit our max, yet
        for n = 1:1:length(ContractString)
            if dateStrFixed{n} <= lastDate
                hitMaxDate = true;
            else
                urlCell{index,1} = urlStr{n};
                dateOut{index,1} = dateStrFixed{n};
                index = index + 1;
            end
        end
        
        if hitMaxDate % lastDate >= '26-dec-2014'
            esc = true;
        else
            Page = Page + 1;
            currURL = [overheadURL,'?Page=',num2str(Page)];
        end
    end
catch ME
    warning('Error observed in getURLs()')
    DEBUG = true;
end
end

%% function [ContractBranch,ContractCash,ContractCompany,ContractDates] = getHistory(ArticleURL,ArticleDate)
%
% This function will parse the articles and get contract figures and
% company names in order to analyze the market pre-post the contract.
%
% Inputs:
%       - ArticleURL = the url for each of the articles we want to parse
%                      data from
%       - ArticleDate = the date which each of the contracts we look at are
%       in
%
% Outputs:
%       - ContractBranch = The military *branch* which the contract is for
%       - ContractCash = The *dollar* amount the contract is for
%       - ContractCompany = The *company* which the contract is for
%       - ContractDates = The *date* which the contract was established
%

% for the sake of debugging
% ArticleURL = URLcell;
% a = 1;

function [ContractBranch,ContractCash,ContractCompany,ContractDates] = getHistory(ArticleURL,ArticleDate)
try
    % Some pre-allocation
    ContractBranch = [];
    ContractCash = [];
    ContractCompany = {};
    ContractDates = {};
    % Pre-allocate un-corrected variables
    ContractBranch_nonCorr_all = {};
    ContractCash_nonCorr_all = [];
    CompanyName_nonCorr_all = {};
    ArticleDate_nonCorr_all = {};
    
    corr_index = 1;
    for a = 1:1:length(ArticleURL)
        url_str = webread(ArticleURL{a});
        % need to add a check that assures URL's are properly loading
        
        % Pre-allocate & clear out the variables reused
        ContractBranch_nonCorr = {};
        ContractCash_nonCorr = [];
        CompanyName_nonCorr = {};
        ArticleDate_nonCorr = {};
        ContractBranchName = {};
        contractString = {};
        CompanyName = {};
        ContractChar = [];
        ContractCash_str = {};
        ContractId = [];
        BranchId = [];
        ContractIdEnd = [];
        
        %***** Get the location of the lines for each contract and their respective branches
        % V01
        % There seems to be old ways of showing the contract. This should
        % cover all of the locations that have been observed. Adding more
        % may be necessary :)
        branchCompare = {'<p style="text-align: center;"','<p align="center"','<div style="text-align: center;"'};
        BranchId = [];
        z = 1;
        while isempty(BranchId)
            BranchId = strfind(url_str,branchCompare{z});%This string begins which branch the contract goes into
            z = z + 1;
            if z > length(branchCompare) && isempty(BranchId)
                warning('Error observed in getHistory()')
                DEBUG = true;
                break;
            end
        end
                
        ContractIdStrtStr = {'<p>','<br />'};
        ContractIdFinStr = {'</p>','<br'};
        q = 1;
        while length(ContractId)<3
            ContractId = strfind(url_str(BranchId(1):end),ContractIdStrtStr{q})+BranchId(1)+2; % This is the first letter of the company names
            ContractIdEnd_init = strfind(url_str(BranchId(1):end),ContractIdFinStr{q})+BranchId(1)-2; % This is the first letter of the company names
            q = q + 1;
            if q > length(branchCompare) && length(ContractId)<3
                warning('Error observed in getHistory()')
                DEBUG = true;
                break;
            end
        end
        
        endCol = find(ContractIdEnd_init>ContractId(1),1);
        ContractIdEnd = ContractIdEnd_init(endCol:end);
        offset = 0; % This character is to adjust the ContractIdEnd variable.... it could essentially be off by a few since not all '</p>'s have a '<p>' to start
        for n = 1:1:length(ContractId)-3 % we subtract 3 because we know the last 3 '</p>'s are for the endpage information
            if ContractIdEnd(n+offset)<ContractId(n)
                offset = offset + 1;
            end
            contractString{n,1} = url_str(ContractId(n):ContractIdEnd(n+offset));
        end
        % V00 - There is a pretty big failure rate at pulling properly. I've
        % attempted fixes to the bugs without much success. The V01 should be a
        % better algorithm for finding the proper lines for each contract.
        %         BranchId = strfind(url_str,'<p style="text-align: center;"');%This string begins which branch the contract goes into
        %
        %         % We need to reference all after the first branch is introduced. There
        %         % is a bug that below this line, there is a few '<p>' in the character
        %         % array that we can get rid of parsing by only looking at the char from
        %         % BrnachId(1):end
        %         ContractId = strfind(url_str(BranchId(1):end),'<p>')+BranchId(1)+2; % This is the first letter of the company names
        %         ContractIdEnd = strfind(url_str(BranchId(1):end),'<p><br />')+BranchId(1); % This is the first letter of the company names
        %         %         ContractIdEnd = strfind(url_str(BranchId(1):end),'<p><br />')+BranchId(1); % This is the first letter of the company names (*BUG: not all files have <p><b
        %         if isempty(ContractIdEnd)
        %             ContractIdEnd = strfind(url_str(BranchId(1):end),'<br />')+BranchId(1);
        %             if isempty(ContractIdEnd)
        %                 ContractIdEnd = strfind(url_str(BranchId(1):end),'</p>')+BranchId(1);
        %                 ContractIdEnd = ContractIdEnd(end);
        %             end
        %         end
        
        %***** Get the company name
        for n = 1:1:length(contractString)
            z = 1;
            while ~strcmpi(contractString{n}(z),',') && z<length(contractString{n})
                CompanyName{n,1}(z) = contractString{n}(z);
                z = z + 1;
            end
        end
        
        % Run some common corrections to the company names
        fixCompName = regexp(CompanyName,'\W');
        CompanyName_nonCorr = CompanyName;
        for n = 1:1:length(fixCompName)
            % here we are replacing all of the special characters with
            % underscores. Underscore corrections can be found below
            for k = 1:1:length(fixCompName{n})
                CompanyName_nonCorr{n}(fixCompName{n}(k)) = '_';
            end
            % Here we want to get rid of any underscores at the end of the
            % string
            while strcmpi(CompanyName_nonCorr{n}(end),'_')
                CompanyName_nonCorr{n} = CompanyName_nonCorr{n}(1:end-1);
            end
            % Here we want to get rid of any double underscores
            if contains(CompanyName_nonCorr{n},'__')
                while 1==1
                    doubleUnder = strfind(CompanyName_nonCorr{n},'__');
                    if isempty(doubleUnder)
                        break
                    else
                        CompanyName_nonCorr{n}(doubleUnder(1)) = '';
                    end
                end
            end
            % Here we want to see if any of the company names start with a
            % number, which is not allowed by MATLAB to be a fieldname/variable name
            if regexp(CompanyName_nonCorr{n}(1),'\d')
                CompanyName_nonCorr{n} = ['a',CompanyName_nonCorr{n}];
            end
            % Here we want to eliminate any accented characteres
            accentedChars = {'à','è','ì','ò','ù','À','È','Ì','Ò','Ù','á','é','í','ó','ú','ý',...
                'Á','É','Í','Ó','Ú','Ý','â','ê','î','ô','û',...
                'Â','Ê','Î','Ô','Û','ã','ñ','õ','Ã','Ñ','Õ',...
                'ä','ë','ï','ö','ü','ÿ',...
                'Ä','Ë','Ï','Ö','Ü','Ÿ',...
                'å','Å','ç','Ç','ẻ'};
            accentedCharsFix = {'a','e','i','o','u','A','E','I','O','U','a','e','i','o','u','y',...
                'A','E','I','O','U','Y','a','e','i','o','u',...
                'A','E','I','O','U','a','n','o','A','N','O',...
                'a','e','i','o','u','y',...
                'A','E','I','O','U','Y',...
                'a','A','c','C','e'};
            if contains(CompanyName_nonCorr{n},accentedChars)
                for k = 1:1:length(CompanyName_nonCorr{n})
                    for q = 1:1:length(accentedChars)
                        if strcmpi(accentedChars{q},CompanyName_nonCorr{n}(k))
                            CompanyName_nonCorr{n}(k) = accentedCharsFix{q};
                        end
                    end
                end
            end
            
            % Here we want to limit the length, for fieldnames
            if length(CompanyName_nonCorr{n}) >= 63
                CompanyName_nonCorr{n} = CompanyName_nonCorr{n}(1:63);
            end
        end
        CompanyName_nonCorr_all = [CompanyName_nonCorr_all;CompanyName_nonCorr];
        %***** Get the cash value of the contract
        % Now that we have each line for each contract, get the dollar amount
        for n = 1:1:length(contractString) % use company name becaus ethat is how many line items we have
            CashStrt = strfind(contractString{n},'$');
            
            correction(corr_index) = false;
            if isempty(CashStrt) || contains(contractString{n},{'CORRECTION','UPDATE'}) % Bug when there is a correction. This should fix it
                ContractCash_str{n} ='0';
                correction(corr_index) = true;
            else
                z = 1;
                while ~strcmpi(contractString{n}(CashStrt(1)+z),' ')
                    ContractCash_str{n}(z) = contractString{n}(CashStrt(1)+z);
                    z = z + 1;
                end
            end
            corr_index = corr_index+1;
        end
        
        % Grab only the digits. Also, check for any hidden/special
        % characters that might be lying around.
        for n = 1:1:length(ContractCash_str)
            propStr = isstrprop(ContractCash_str{n},'digit');
            stringRemake = '';
            for m = 1:1:length(propStr)
                if propStr(m)
                    stringRemake = [stringRemake,ContractCash_str{n}(m)];
                end
            end
            ContractCash_nonCorr(n,1) = str2double(stringRemake);
        end
        
        ContractCash_nonCorr_all = [ContractCash_nonCorr_all;ContractCash_nonCorr];
        %***** Get the date of the contract
        for k = 1:1:length(contractString) % use company name becaus ethat is how many line items we have
            ArticleDate_nonCorr{k,1} =  ArticleDate{a};
        end
        ArticleDate_nonCorr_all = [ArticleDate_nonCorr_all;ArticleDate_nonCorr];
        
        %***** Get the branch for the contract given
        % Get the different branch names
        for n = 1:1:length(BranchId)
            %             if a == 257 && n == 5
            %                 debug = true;
            %             end
            
            q = 1;
            z = 0;
            % wait until the first '>' exists, then the name of the branch will
            % be the branch name
            breakafter1 = false;
            while 1 % This loop is due to occasionally getting a new line if the branch string is too long.
                for k = 1:2 % do this 2 times due to the fact that we will be getting a <strong> input due to bolding the name
                    while ~strcmpi(url_str(BranchId(n)+z),'>')
                        z = z + 1;
                    end
                    z = z + 1;
                    if breakafter1
                        break
                    end
                end
                if ~strcmpi(url_str(BranchId(n)+z-2:BranchId(n)+z-1),'/>')
                    break
                else
                    breakafter1 = true;
                end
            end
            %             while ~(strcmpi(url_str(BranchId(n)+z),'<') || strcmpi(url_str(BranchId(n)+z),'&'))
            while isstrprop(url_str(BranchId(n)+z),'alphanum') || strcmpi(url_str(BranchId(n)+z),' ') || strcmpi(url_str(BranchId(n)+z),'.')
                ContractBranchName{n,1}(q) = url_str(BranchId(n)+z);
                z = z + 1;
                q = q + 1;
            end
        end
        ContractBranchName = strrep(strrep(ContractBranchName,' ','_'),'.',''); % get rid of any spaces
        
        % DEBUGGING ('U.S' was not taking due to '.')
        %         for b = 1:1:length(ContractBranchName)
        %             if strcmpi(ContractBranchName{b},'U')
        %                 DEBUG = true;
        %             end
        %         end
        % Determine which contract goes with which branch
        for n = 1:1:length(CompanyName)
            ContractBranch_nonCorr{n,1} = ContractBranchName{length(find(ContractId(n)>BranchId,length(BranchId)))};
        end
        ContractBranch_nonCorr_all = [ContractBranch_nonCorr_all;ContractBranch_nonCorr];
        
        %***** Check the contracts are all same length
        len_ContractBranch = length(ContractBranch_nonCorr);
        len_ContractCash = length(ContractCash_nonCorr);
        len_ContractCompany = length(CompanyName_nonCorr);
        len_ContractDates = length(ArticleDate_nonCorr);
        if ~(len_ContractBranch == len_ContractCash && len_ContractBranch == len_ContractCompany && len_ContractBranch == len_ContractDates...
                && len_ContractCash == len_ContractCompany && len_ContractCash == len_ContractDates...
                && len_ContractCompany == len_ContractDates)
            warning('length of contract data inconsistent');
            return
        end
    end
    
    %***** Get rid of any corrections, they will end up skewing the data
    q = 1;
    for z = 1:1:(corr_index-1)
        if ~correction(z)
            ContractBranch{q,1} = ContractBranch_nonCorr_all{z};
            ContractCash(q,1) = ContractCash_nonCorr_all(z);
            ContractCompany{q,1} = CompanyName_nonCorr_all{z};
            ContractDates{q,1} = ArticleDate_nonCorr_all{z};
            q = q + 1;
        end
    end
catch ME
    warning('Error observed in getHistory()')
    DEBUG = true;
end
end

%% function [perBranch,perComp,perYear] = ReOrg_Data(Branch,Cash,Company,Date);
%
% This function is simply to just re-organize data by different methods.
% i.e. we want to organize cash by branch, company, and year.
%
% Inputs:
%       - BranchCell = The cell containing which branch the contract is
%                      under
%       - CashCell = The cell containing cash value the contract is worth
%       - CompanyCell = The cell containing which company the contract is
%                      under
%       - DateCell = The cell containing which year/date the contract is
%                      under
%
% Outputs:
%       - Branch = The military *branch* array that contrains cash value
%       - Company = The *company* array that contrains cash value
%       - Year = The *year* array that contrains cash value
%

function [Branch,Company,Year] = ReOrg_Data(BranchCell,CashCell,CompanyCell,DateCell)
try
    % Pre-allocate variables
    Branch = [];
    Company = [];
    Year = [];
    
    BranchIndex = 1;
    CompanyIndex = 1;
    YearIndex = 1;
    
    % Sweep the entirety of the data
    for n = 1:1:length(BranchCell)
        
        %***** Organize by branch
        % Check to see if the structure exists, if not, make it
        if ~isfield(Branch,BranchCell{n})
            Branch.(BranchCell{n}) = [];
        end
        % log the cash value of this contract, per Branch. The cash values will
        % stack to have all the branch contract cash values into 1 variable
        Branch.(BranchCell{n}) = [Branch.(BranchCell{n});CashCell(n)];
        
        %***** Organize by Company
        % Check to see if the structure exists, if not, make it
        if ~isfield(Company,CompanyCell{n})
            Company.(CompanyCell{n}) = [];
        end
        % log the cash value of this contract, per Company. The cash values will
        % stack to have all the branch contract cash values into 1 variable
        Company.(CompanyCell{n}) = [Company.(CompanyCell{n});CashCell(n)];
        
        %***** Organize by Year
        % Get the year value of the contract
        YearVal = ['a',DateCell{n}(end-3:end)];
        % Check to see if the structure exists, if not, make it
        if ~isfield(Year,YearVal)
            Year.(YearVal) = [];
        end
        % log the cash value of this contract, per Year. The cash values will
        % stack to have all the branch contract cash values into 1 variable
        Year.(YearVal) = [Year.(YearVal);CashCell(n)];
    end
catch ME
    warning('Error observed in ReOrg_Data()')
    DEBUG = true;
end
end


%% function [readback] = logUpdate(savetxt,logPathway,currentDate,varargin)
%
% This function is simply to just re-organize data by different methods.
% i.e. we want to organize cash by branch, company, and year.
%
% Inputs:
%       - savetxt = the savename of the matlab .mat name
%       - logPathway = the location of the log.txt file
%       - currentDate = the current date of running this data
%       - varargin = optional inputs:
%                   1. 'readonly'
% Outputs:
%       - Readback = the final file read once all has occured

% for the sake of debugging
% savetxt = '22_nov_2021_to_1_dec_2022';
% logPathway = pathway;
% n = 1;
% currentDate = datetime('today')

function [readback] = logUpdate(savetxt,logPathway,currentDate,varargin)
try
    %***** pre-allocate & assign variables
    readback = [];
    currVers = '';
    fName = 'log.txt';
    newline = '\n';
    doWrite = true;
    currentDateOverwrite = strrep(char(currentDate),'-','_');
    pattern = 'V' + digitsPattern(8); % This is the pattern we're looking for to validate the version number
    
    % Get just the .mat file name
    if ~isempty(savetxt)
        k = length(savetxt);
        while ~strcmpi(savetxt(k),'\')
            k = k - 1;
        end
        saveFileName = [savetxt(k+1:end),'.mat'];
    end
    %***** Check varargin variables
    for k = 1:1:length(varargin)
        if strcmpi(varargin{k},'readonly')
            doWrite = false;
        end
    end
    
    %**** Read from the log.txt file
    fileID = fopen([logPathway,fName],'r'); % open read-only to get the entirety of the file
    
    if fileID ~= -1 % This checks to see if the file even exists. If not... make the file, else, read from the log.txt file
        fileRead = fscanf(fileID,'%c'); % Read the file as a char (which includes white space)
        fclose(fileID); % Close the read-only file
    else % if the file doe snot exist, make it
        fileID0 = fopen([logPathway,fName],'w'); % make a new document
        fprintf(fileID0,'');
        fileRead = fscanf(fileID0,'%c'); % Read the file as a char (which includes white space)
        fclose(fileID0); % Close the read-only file
    end
    
    if doWrite
        %***** Determine the version and increment to newest version, then re-write the file
        versionCheck = extract(fileRead,pattern); % Find all the versions written in the file
        if ~isempty(versionCheck)
            for n = 1:1:length(versionCheck)
                charLoc = strfind(fileRead,versionCheck{n});
                verNum(n,1) = str2double(fileRead(charLoc+1:charLoc+8));
            end
            % Determine the next version number
            currVers = num2str(max(verNum) + 1,'%08.0f');
        else
            % Define version number as 0, we have no history
            currVers = num2str(0,'%08.0f');
            newline = '';
        end
        %***** Get the size of the .mat file (unverified)
        matObj = dir(sprintf('%s',[logPathway,'rawData\']));
        MatlabFileNames = {matObj.name};
        byteNum = {matObj.bytes};
        for n = 1:1:length(MatlabFileNames)
            if strcmpi(MatlabFileNames{n},saveFileName)
                break
            end
        end
        file_size = byteNum{n};
        
        %***** Write the version + details into the log file.
        lineWrite = sprintf('V%s,%s,%1.0fbytes,%s%s;',currVers,currentDateOverwrite,file_size,[logPathway,'rawData\'],saveFileName);
        fileWrite = [strrep(fileRead,'\','\\'),newline,strrep(lineWrite,'\','\\')];
        
        fileID1 = fopen([logPathway,fName],'w'); % open write to get the entirety of the file
        fprintf(fileID1,fileWrite); % write the information to the file
        fclose(fileID1); % Close the read-only file
        
        %***** Readback the file again to verify writing
        fileID2 = fopen([logPathway,fName],'r'); % open read-only to get the entirety of the file
        fileRead2 = fscanf(fileID2,'%c'); % Read the file as a char (which includes white space)
        fclose(fileID2); % Close the read-only file
        readback = fileRead2;
    else
        readback = fileRead;
    end
catch ME
    warning('Error observed in logUpdate()')
    DEBUG = true;
end
end


%% function [loadName,dateDelta,ValidData] = PullOldData(OldDataSel,dateRun,pathway)
%
% This function is to get the file name + load pathway for the data we want
% to pull in for characterization. The specific needs (i.e. largest data
% set, oldest data set, etc) is defined with an input. Nominal is "Newest"
% data set. Just makes sense
%
% Inputs:
%       - OldDataSel = which dataset we want to pull in, defined by a
%                      string. The optional inputs are:'smallestdataset'
%                           1. 'largestdataset' - the dataset with the
%                                                 largest file size
%                           2. 'oldestversion' - the V0 files
%                           3. 'newestversion' - the Vx version the is the
%                                                max of all V's.
%                           4. 'smallestdataset' - the dataset with the
%                                                  smallest file size
%                           5.
%       - logPathway = the location of the log.txt file
% Outputs:
%       - loadString = the final file read once all has occured
%       - DataExists = A variable to tell if we were able to get the load
%                      file or not. Imagine a case where log.txt is empty.

% for the sake of debugging
% savetxt = '22_nov_2021_to_1_dec_2022';
% logPathway = pathway;
% n = 1;
% currentDate = datetime('today')


function [loadString,DataExists] = PullOldData(OldDataSel,logPathway)
try
    % pre-allocate
    loadString = '';
    DataExists = false;
    pattern = 'V' + digitsPattern(8); % This is the pattern we're looking for to validate the version number
    
    %***** Read in the file, make sure it is not empty
    fRead = logUpdate([],logPathway,datetime('today'),'readonly');
    if isempty(fRead)
        return;
    end
    
    %***** parse out the file
    %********** get the Version Numbers
    Versions = extract(fRead,pattern); % Get the total number of versions within the log.txt file
    VerLines = zeros(1,length(Versions)); %pre-allocate the length of lines
    for n = 1:1:length(Versions)
        VerLines(n) = strfind(fRead,Versions{n});
        VersionNum(n) = str2double(fRead(VerLines(n)+1:VerLines(n)+8));
    end
    
    
    for n = 1:1:length(Versions)
        index(n) = VerLines(n)+10; % first index will be after the versions string
        %********** get the Date Generated Numbers
        WriteDate{n,1} = '';
        while ~strcmpi(fRead(index(n)),',')
            WriteDate{n} = [WriteDate{n},fRead(index(n))];
            index(n) = index(n) + 1;
        end
        index(n) = index(n) + 1;
        %********** get the data size
        SizeStr{n,1} = '';
        while ~strcmpi(fRead(index(n)),',')
            SizeStr{n,1} = [SizeStr{n},fRead(index(n))];
            index(n) = index(n) + 1;
        end
        Size(n,1) = str2double(SizeStr{n}(1:end-5));
        index(n) = index(n) + 1;
        %********** link
        LinkStr{n,1} = '';
        while ~strcmpi(fRead(index(n)),';')
            LinkStr{n,1} = [LinkStr{n},fRead(index(n))];
            index(n) = index(n) + 1;
        end
    end
    
    %***** determine which file we want to select
    OldDataSel = lower(OldDataSel);
    while 1 == 1 % only incase OldDataSel is empty
        switch OldDataSel
            case 'largestdataset'
                [~,row] = find(max(Size)==Size);
                loadString = LinkStr{row};
                break;
            case 'oldestversion'
                [~,row] = find(min(VersionNum)==VersionNum);
                loadString = LinkStr{row};
                break;
            case 'newestversion'
                [~,row] = find(max(VersionNum)==VersionNum);
                loadString = LinkStr{row};
                break;
            case 'smallestdataset'
                [~,row] = find(min(Size)==Size);
                loadString = LinkStr{row};
                break;
            otherwise
                OldDataSel = 'newestversion';
        end
    end
    
    % Tell user we're getting a correct output
    if ~isempty(loadString)
        DataExists = true;
    end
catch ME
    warning('Error observed in PullOldData()')
    DEBUG = true;
end
end

%% function [] = plotData(savepath,branch,company,year,cash,doComparison,perBranch_1wk,perComp_1wk,perYear_1wk,Cash_1wk)
%
% This function is to plot the input data. The big thing is that it will
% plot the old past data against the newest data if you tell it to do so.
%
% Inputs:
%       - savepath = the location of the current folder working in. The
%                    plots folder will be generated within this function
%                    if not already existant
%       - branch = The past data correlating to branch names
%       - company = The past data correlating to company names
%       - year = The past data correlating to year
%       - cash = The past data correlating to cash per contract
%       - doComparison = A logical input that tells the function to compare
%                        data or not
%       - perBranch_1wk = The past data correlating to branch names
%       - perComp_1wk = The past data correlating to branch names
%       - perYear_1wk = The past data correlating to branch names
%       - Cash_1wk = The past data correlating to branch names
% Outputs:
%       -

% for the sake of debugging
%
%

function [] = plotData(savepath,branch,company,year,cash,DateString,doComparison,branch1wk,company1wk,year1wk,cash1wk,DateString_1wk)
try
    
    color = 'b'; % Plot color of the past data
    compcolor = 'r'; % plot color of the newest data to compare to past data
    
    % Make the necessary folders for keeping the plots and data together
    if doComparison
        savepath = [savepath,'PastDataPlots\'];
        if ~isfolder(savepath)
            mkdir('PastDataPlots');
        end
    else
        savepath = [savepath,'ComparisonPlots\'];
        if ~isfolder(savepath)
            mkdir('ComparisonPlots');
        end
    end
    
    %***** Let's start histogramming :)
    %********** Histograms of cash $$$$
    cash_fig = figure('visible','on','outerposition',get(0,'screensize'));
    if doComparison
        histogram(cash,length(cash),...
            'EdgeColor',color,'FaceColor',color,...
            'EdgeAlpha',1,'FaceAlpha',0.6);
        hold on
        histogram(cash1wk,length(cash1wk),...
            'EdgeColor',compcolor,'FaceColor',compcolor,...
            'EdgeAlpha',1,'FaceAlpha',0.6);
        grid on
        title(sprintf('Total Contract Cash\nCompare Old Data to This Week''s Data'));
        ylabel('Distribution');
        xlabel('Cash Value');
        xlim([0,max(cash)+10e6]);
        set(gca,'FontSize',16);
        cash_fig = tightfig(cash_fig);
        plotSaveName = sprintf()
    else
        histogram(cash,length(cash),...
            'EdgeColor',color,'FaceColor',color,...
            'EdgeAlpha',1,'FaceAlpha',0.6);
        grid on
        title('Total Contract Cash');
        ylabel('Distribution');
        xlabel('Cash Value');
        xlim([0,max(cash)+10e6]);
        set(gca,'FontSize',16);
        cash_fig = tightfig(cash_fig);
    end
    
    
    %********** Histograms of cash $$$$
    
catch ME
    warning('Error observed in plotData()')
    DEBUG = true;
end
end


%% function hfig = tightfig(hfig)
%
% Passing in the figure handle you want to tighten up the plot for and the
% function will make it look pretty and fit in the working space of the
% handle. Passing out the handle number.
%
% Using this *may* decrease processing time. Up to user.
%
%----------------------------

function hfig = tightfig(hfig)
% tightfig: Alters a figure so that it has the minimum size necessary to
% enclose all axes in the figure without excess space around them.
%
% Note that tightfig will expand the figure to completely encompass all
% axes if necessary. If any 3D axes are present which have been zoomed,
% tightfig will produce an error, as these cannot easily be dealt with.
%
% Input
%
% hfig - handle to figure, if not supplied, the current figure will be used
%   instead.
%
%
if nargin == 0
    hfig = gcf;
end
% There can be an issue with tightfig when the user has been modifying
% the contnts manually, the code below is an attempt to resolve this,
% but it has not yet been satisfactorily fixed
%     origwindowstyle = get(hfig, 'WindowStyle');
set(hfig, 'WindowStyle', 'normal');

% 1 point is 0.3528 mm for future use
% get all the axes handles note this will also fetch legends and
% colorbars as well
hax = findall(hfig, 'type', 'axes');
% TODO: fix for modern matlab, colorbars and legends are no longer axes
hcbar = findall(hfig, 'type', 'colorbar');
hleg = findall(hfig, 'type', 'legend');

% get the original axes units, so we can change and reset these again
% later
origaxunits = get(hax, 'Units');

% change the axes units to cm
set(hax, 'Units', 'centimeters');

pos = [];
ti = [];

% get various position parameters of the axes
if numel(hax) > 1
    %         fsize = cell2mat(get(hax, 'FontSize'));
    ti = cell2mat(get(hax,'TightInset'));
    pos = [pos; cell2mat(get(hax, 'Position')) ];
else
    %         fsize = get(hax, 'FontSize');
    ti = get(hax,'TightInset');
    pos = [pos; get(hax, 'Position') ];
end

if ~isempty (hcbar)
    
    set(hcbar, 'Units', 'centimeters');
    
    % colorbars do not have tightinset property
    for cbind = 1:numel(hcbar)
        %         fsize = cell2mat(get(hax, 'FontSize'));
        [cbarpos, cbarti] = colorbarpos (hcbar);
        pos = [pos; cbarpos];
        ti = [ti; cbarti];
    end
end

if ~isempty (hleg)
    
    set(hleg, 'Units', 'centimeters');
    
    % legends do not have tightinset property
    if numel(hleg) > 1
        %         fsize = cell2mat(get(hax, 'FontSize'));
        pos = [pos; cell2mat(get(hleg, 'Position')) ];
    else
        %         fsize = get(hax, 'FontSize');
        pos = [pos; get(hleg, 'Position') ];
    end
    ti = [ti; repmat([0,0,0,0], numel(hleg), 1); ];
end

% ensure very tiny border so outer box always appears
ti(ti < 0.1) = 0.15;

% we will check if any 3d axes are zoomed, to do this we will check if
% they are not being viewed in any of the 2d directions
views2d = [0,90; 0,0; 90,0];

for i = 1:numel(hax)
    
    set(hax(i), 'LooseInset', ti(i,:));
    %         set(hax(i), 'LooseInset', [0,0,0,0]);
    
    % get the current viewing angle of the axes
    [az,el] = view(hax(i));
    
    % determine if the axes are zoomed
    iszoomed = strcmp(get(hax(i), 'CameraViewAngleMode'), 'manual');
    
    % test if we are viewing in 2d mode or a 3d view
    is2d = all(bsxfun(@eq, [az,el], views2d), 2);
    
    if iszoomed && ~any(is2d)
        error('TIGHTFIG:haszoomed3d', 'Cannot make figures containing zoomed 3D axes tight.')
    end
    
end

% we will move all the axes down and to the left by the amount
% necessary to just show the bottom and leftmost axes and labels etc.
moveleft = min(pos(:,1) - ti(:,1));

movedown = min(pos(:,2) - ti(:,2));

% we will also alter the height and width of the figure to just
% encompass the topmost and rightmost axes and lables
figwidth = max(pos(:,1) + pos(:,3) + ti(:,3) - moveleft);

figheight = max(pos(:,2) + pos(:,4) + ti(:,4) - movedown);

% move all the axes
for i = 1:numel(hax)
    
    set(hax(i), 'Position', [pos(i,1:2) - [moveleft,movedown], pos(i,3:4)]);
    
end

for i = 1:numel(hcbar)
    
    set(hcbar(i), 'Position', [pos(i+numel(hax),1:2) - [moveleft,movedown], pos(i+numel(hax),3:4)]);
    
end

for i = 1:numel(hleg)
    
    set(hleg(i), 'Position', [pos(i+numel(hax)+numel(hcbar),1:2) - [moveleft,movedown], pos(i+numel(hax)+numel(hcbar),3:4)]);
    
end

origfigunits = get(hfig, 'Units');

set(hfig, 'Units', 'centimeters');

% change the size of the figure
figpos = get(hfig, 'Position');

set(hfig, 'Position', [figpos(1), figpos(2), figwidth, figheight]);

% change the size of the paper
set(hfig, 'PaperUnits','centimeters');
set(hfig, 'PaperSize', [figwidth, figheight]);
set(hfig, 'PaperPositionMode', 'manual');
set(hfig, 'PaperPosition',[0 0 figwidth figheight]);

% reset to original units for axes and figure
if ~iscell(origaxunits)
    origaxunits = {origaxunits};
end
for i = 1:numel(hax)
    set(hax(i), 'Units', origaxunits{i});
end
set(hfig, 'Units', origfigunits);

%      set(hfig, 'WindowStyle', origwindowstyle);

end
function [pos, ti] = colorbarpos (hcbar)
% 1 point is 0.3528 mm

pos = hcbar.Position;
ti = [0,0,0,0];

if ~isempty (strfind (hcbar.Location, 'outside'))
    if strcmp (hcbar.AxisLocation, 'out')
        
        tlabels = hcbar.TickLabels;
        
        fsize = hcbar.FontSize;
        
        switch hcbar.Location
            
            case 'northoutside'
                
                % make exta space a little more than the font size/height
                ticklablespace_cm = 1.1 * (0.3528/10) * fsize;
                
                ti(4) = ti(4) + ticklablespace_cm;
                
            case 'eastoutside'
                
                maxlabellen = max ( cellfun (@numel, tlabels, 'UniformOutput', true) );
                
                % 0.62 factor is arbitrary and added because we don't
                % know the width of every character in the label, the
                % fsize refers to the height of the font
                ticklablespace_cm = (0.3528/10) * fsize * maxlabellen * 0.62;
                ti(3) = ti(3) + ticklablespace_cm;
                
            case 'southoutside'
                
                % make exta space a little more than the font size/height
                ticklablespace_cm = 1.1 * (0.3528/10) * fsize;
                ti(2) = ti(2) + ticklablespace_cm;
                
            case 'westoutside'
                
                maxlabellen = max ( cellfun (@numel, tlabels, 'UniformOutput', true) );
                
                % 0.62 factor is arbitrary and added because we don't
                % know the width of every character in the label, the
                % fsize refers to the height of the font
                ticklablespace_cm = (0.3528/10) * fsize * maxlabellen * 0.62;
                ti(1) = ti(1) + ticklablespace_cm;
                
        end
        
    end
    
end
end


% Scrible notes:
%
% -seems like not all documents will have <p><br /> as an ending
% statement... may need to fix that bug. The current work around is finding
% just <br /> for those specific documents, but not sure what to do it we
% have a document without <br />, either.
%
% - as of 12/7/22 I've been able to parse data, log it, and load it back
% in. I've been able to generate all the needed log.txt and folders needed
% from a fresh run of the script.
%
% - Should I add capability to check to see if there is no log.txt file, I
% automatically start pulling data instead of having the author write? I
% will never be able to pull in data if it doesn't exist, and it is
% currently what the author defines, not what I'm defining.
%
% -
%
%
%
%