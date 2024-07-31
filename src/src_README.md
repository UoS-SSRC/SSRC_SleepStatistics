# SSRC_SleepStatistics - Documentation and Code for generating Sleep statistics used at the Surrey Sleep Research Centre

**Licence:**  
SSRC_SleepStatistics Copyright (C) 2024 Kiran K G Ravindran and contributors. Refer to the License.txt for more details.

## File list and overview : Total 2 files
1. "Example_code.m" 
    Allow the import of the example data (Hypnograms and Markers); Generate the sleep statistics for all files and export the data table as a spreadsheet
    #### Embedded Support functions
    * Get_Markers - Outputs the Marker Info given Marker file path. Marker file format has to match the format in the example data

    * Get_Hypnogram - Outputs the Hypnogram timevector and sleep stages given Hypnogram file path. Hypnogram file format has to match the format in the example data

    * Get_SM_row - Format the out put of the Get_SSRC_SleepStatistics function into a table row

2. "Get_SSRC_SleepStatistics.m"

    Type 0 - Standard function that generate all the statistics in the "Polysomnography Data Extraction and Analysis Specification" including the hourly estimates
    Type 1 - Reduced function - Does not generate hourly estimates - works for shorter Hypnograms
    
3. "RunLength" - Support function used for estimation run lengths of sleep stage segments. REF: Jan (2024). RunLength (https://www.mathworks.com/matlabcentral/fileexchange/41813-runlength), MATLAB Central File Exchange. Retrieved June 1, 2024.

## Citation
Refer the main page of the SSRC_SleepStatistics Repository

