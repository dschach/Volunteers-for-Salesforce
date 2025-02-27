/**
    Copyright (c) 2016, Salesforce.org
    All rights reserved.
    
    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:
    
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Salesforce.org nor the names of
      its contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.
 
    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE 
    COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN 
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
    POSSIBILITY OF SUCH DAMAGE.
**/
/*******************************************************************************************************
 * @author David Habib
 * @date 7/1/2011
 * @description Page Controller class for the Open Report visualforce page.
 ********************************************************************************************************/
public with sharing class VOL_CTRL_OpenReport {
    //---------------------------------------------------------------------------------------------
    // Main routine that gets invoked as a page action to redirect to open the specified report.
    // note that it expects a DeveloperName, and it will append any Url parameters to the report,
    // so that you can filter the report.
    //---------------------------------------------------------------------------------------------
    public PageReference openReportDevName() {
        String strDevName = ApexPages.currentPage().getParameters().get('ReportDevName');
        if (strDevName == null || strDevName == '') {
            return null;
        }

        //redirect to newly created opp in edit mode
        Id reportId = reportIdFromDevName(strDevName.escapeHtml4());
        if (reportId != null) {
            String strParams = ApexPages.currentPage().getUrl();
            Integer iparams = strParams.indexOf('?');
            if (iparams >= 0) {
                strParams = strParams.substring(iparams);
            } else {
                strParams = '';
            }
            PageReference page;
            // see if we are in Lightning Experience vs Aloha/Salesforce Classic
            if (UserInfo.getUiThemeDisplayed() != 'Theme4d') {
                page = new PageReference('/' + reportId + strParams);
            } else {
                strParams = strParams.replace('pv', 'fv');
                page = new PageReference('/one/one.app#/sObject/' + reportId + '/view' + strParams);
            }
            page.setRedirect(true);
            return page;
        }

        return null;
    }

    /*******************************************************************************************************
     * @description Static method to lookup a reportId given its Developer Name.  This is useful when creating
     * custom links and buttons in Salesforce, that want to load a report, without having to know its specific
     * id in the given Salesforce instance.
     * @param strDevName DeveloperName of the report
     * @return reportId
     ********************************************************************************************************/
    public static Id reportIdFromDevName(String strDevName) {
        try {
            Id reportId = null;

            // Ensure the user has access to the object and fields before querying
            UTIL_Describe.checkReadAccess('Report', new Set<String>{ 'Id' });

            Report[] rpts = [SELECT Id FROM Report WHERE DeveloperName = :strDevName];
            if (!rpts.isEmpty()) {
                reportId = rpts[0].Id;
            }
            return reportId;
        } catch (Exception e) {
            ApexPages.addMessages(e);
            return null;
        }
    }
}