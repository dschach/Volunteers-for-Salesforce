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
 * @description Page Controller class for the Job Calendar visualforce page.  Provides Javascript remoting
 * method for getting Job Shift data.
 ********************************************************************************************************/

@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class VOL_CTRL_JobCalendar {
    @TestVisible
    private UTIL_JavaScriptSanitizer sanitizer = new UTIL_JavaScriptSanitizer();

    // constructor
    global VOL_CTRL_JobCalendar() {
        try {
            namespacePrefix = VOL_SharedCode.getNamespace();
            // handle optional parameters (must use String, not Id, to handle null)

            // if Campaign passed in, set current state
            Map<String, String> params = ApexPages.currentPage().getParameters();
            String p = params.get('campaignId');
            if (p != null && p != '') {
                // Ensure the user has access to the object and fields before querying
                UTIL_Describe.checkReadAccess('Campaign', new Set<String>{ 'Id', 'StartDate' });
                // Using a dynamic describe access check in the method called above.
                /* sfge-disable-next-line ApexFlsViolationRule */
                List<Campaign> listCampaign = [SELECT Id, StartDate FROM Campaign WHERE Id = :p];
                if (listCampaign.size() > 0) {
                    initialDate = Date.valueOf(listCampaign[0].StartDate);
                    if (initialDate < Date.today()) {
                        initialDate = Date.today();
                    } // because this is a GMT time, we should add some padding, so we'll stick
                    // with the same day, even if the locale time zone is up to 12 hours before GMT.
                    if (initialDate != null) {
                        initialDate = initialDate.addHours(12);
                    }
                    campaignId = p;
                }
            }

            // if Job passed in, set current state
            p = params.get('volunteerJobId');
            if (p != null && p != '') {
                // Ensure the user has access to the object and fields before querying
                UTIL_Describe.checkReadAccess(
                    UTIL_Describe.StrTokenNSPrefix('Volunteer_Job__c'),
                    new Set<String>{
                        'Id',
                        UTIL_Describe.StrTokenNSPrefix('First_Shift__c'),
                        UTIL_Describe.StrTokenNSPrefix('Campaign__c')
                    }
                );
                // Using a dynamic describe access check in the method called above.
                /* sfge-disable-next-line ApexFlsViolationRule */
                List<Volunteer_Job__c> listJob = [
                    SELECT Id, First_Shift__c, Campaign__c
                    FROM Volunteer_Job__c
                    WHERE Id = :p
                ];
                if (listJob.size() > 0) {
                    initialDate = Date.valueOf(listJob[0].First_Shift__c);
                    if (initialDate < Date.today()) {
                        initialDate = Date.today();
                    }
                    volunteerJobId = p;
                    // let caller control whether to filter by campaign or not.
                    //campaignId = listJob[0].Campaign__c;
                }
            }

            // if shift passed in, set current state
            p = params.get('volunteerShiftId');
            if (p != null && p != '') {
                // Ensure the user has access to the object and fields before querying
                UTIL_Describe.checkReadAccess(
                    UTIL_Describe.StrTokenNSPrefix('Volunteer_Shift__c'),
                    new Set<String>{
                        'Id',
                        UTIL_Describe.StrTokenNSPrefix('Start_Date_Time__c'),
                        UTIL_Describe.StrTokenNSPrefix('Volunteer_Job__c')
                    }
                );
                UTIL_Describe.checkReadAccess(
                    UTIL_Describe.StrTokenNSPrefix('Volunteer_Job__c'),
                    new Set<String>{ UTIL_Describe.StrTokenNSPrefix('Campaign__c') }
                );
                // Using a dynamic describe access check in the method called above.
                /* sfge-disable-next-line ApexFlsViolationRule */
                List<Volunteer_Shift__c> listShift = [
                    SELECT Id, Start_Date_Time__c, Volunteer_Job__c, Volunteer_Job__r.Campaign__c
                    FROM Volunteer_Shift__c
                    WHERE Id = :p
                ];
                if (listShift.size() > 0) {
                    initialDate = Date.valueOf(listShift[0].Start_Date_Time__c);
                    // let caller control whether to filter by campaign & job or not.
                    //volunteerJobId = listShift[0].Volunteer_Job__c;
                    //campaignId = listShift[0].Volunteer_Job__r.Campaign__c;
                }
            }

            fPrint = false;
            String p = params.get('Print');
            if (p == '1') {
                fPrint = true;
            }
            // we can derive whether we are within the Personal Site or not, so no need for parameter.
            fPersonalSite = ApexPages.currentPage().getUrl().contains('PersonalSite');

            // we can derive whether we are within Sites or not, so no need for parameter.
            fWeb = false;
            fWeb = (Site.getName() != null);

            strLanguage = fWeb ? 'en-us' : null; // don't set language if viewing in SF.  Let SF decide.
            String p = params.get('Language');
            if (p != null && p != '') {
                strLanguage = p;
            }
            p = params.get('initialDate');
            if (p != null && p != '') {
                initialDate = Date.valueOf(p);
            }
            strCalendarView = 'month';
            Set<String> validViews = new Set<String>{ 'month', 'agendaWeek', 'agendaDay', 'basicWeek', 'basicDay' };
            p = params.get('CalendarView');
            if (p != null && p != '' && validViews.contains(p)) {
                strCalendarView = p;
            }
            fShowCampaignHierarchy = false;
            p = params.get('ShowCampaignHierarchy');
            if (p == '1') {
                fShowCampaignHierarchy = true;
            }
            fShowNumberAvailable = false;
            p = params.get('ShowNumberAvailable');
            if (p == '1') {
                fShowNumberAvailable = true;
            }
            // finally, keep all parameters for passing to VolunteersJobListingFS
            // (but remove the params that the page will explicitly add to the url)
            params.remove('Calendar');
            params.remove('volunteerShiftId');
            params.remove('jobId');
            params.remove('dtMonthFilter');
            strParams = '';
            String strAmp = '';
            for (String str : params.keySet()) {
                strParams += strAmp + str + '=' + params.get(str);
                strAmp = '&';
            }
        } catch (Exception e) {
            ApexPages.addMessages(e);
        }
    }

    global String strURLtoCSSFile {
        get {
            if (fPersonalSite) {
                return null; // just use whatever CSS the Site Template includes.
            }
            // only specify the css file if in the web page scenario.
            if (strURLtoCSSFile == null && fWeb) {
                // System query to find the css doc if the admin has added it for custom css
                /* sfge-disable-next-line ApexFlsViolationRule */
                List<Document> listDocs = [SELECT Name, Id FROM Document WHERE Name = 'JobCalendarCSS.css' LIMIT 1];
                if (listDocs.size() > 0) {
                    Document doc = listDocs[0];
                    String imageid = doc.id;
                    imageid = imageid.substring(0, 15);
                    strURLToCSSFile = '/servlet/servlet.FileDownload?file=' + imageid;
                }
            }
            return strURLtoCSSFile;
        }
        set;
    }

    private VOL_SharedCode volSharedCode;

    // global properties
    global String strLanguage { get; set; }
    global Boolean fPrint { get; set; }
    global Boolean fWeb { get; set; }
    global String strCalendarView { get; set; }
    global String strParams { get; set; }
    global Boolean fPersonalSite { get; set; }
    global Boolean fShowCampaignHierarchy { get; set; }
    global Boolean fShowNumberAvailable { get; set; }
    /** @description what is the namespace (null if unmanaged, or GW_Volunteers if managed) */
    global String namespacePrefix { get; set; }

    // holds the currently selected Campaign in the Campaign dropdown
    global Id campaignId { get; set; }

    // the list of active Volunteer Campaigns
    global List<SelectOption> listSOCampaigns {
        get {
            List<SelectOption> listSO = new List<SelectOption>();
            listSO.add(new SelectOption('', System.Label.labelChoiceAllActiveCampaigns));
            if (
                Campaign.SObjectType.getDescribe().isAccessible() &&
                Campaign.Name.getDescribe().isAccessible() &&
                Campaign.IsActive.getDescribe().isAccessible() &&
                Campaign.StartDate.getDescribe().isAccessible() &&
                Campaign.RecordTypeId.getDescribe().isAccessible()
            ) {
                for (Campaign c : [
                    SELECT Name, Id, StartDate
                    FROM Campaign
                    WHERE RecordTypeId = :VOL_SharedCode.recordtypeIdVolunteersCampaign AND IsActive = TRUE
                    ORDER BY Name ASC
                    LIMIT 999
                ]) {
                    listSO.add(new SelectOption(c.id, c.name));
                }
            }

            // Allow the page to load without options.
            return listSO;
        }
        set;
    }

    // the user has changed the Campaign dropdown
    global virtual PageReference changeCampaign() {
        // clear out all state that is specific to the campaign
        listSOVolunteerJobs = null;
        volunteerJobId = null;
        ChangeVolunteerJob();
        return null;
    }

    // holds the currently select Job in the Job dropdown
    global Id volunteerJobId { get; set; }

    // hold the initial date for the calendar
    global DateTime initialDate { get; set; }

    // the list of Volunteer Jobs for the specified Campaign
    global List<SelectOption> listSOVolunteerJobs {
        get {
            List<SelectOption> listSO = new List<SelectOption>();
            listSO.add(new SelectOption('', System.Label.labelChoiceAllJobs));
            if (
                Volunteer_Job__c.SObjectType.getDescribe().isAccessible() &&
                Volunteer_Job__c.Campaign__c.getDescribe().isAccessible() &&
                Campaign.SObjectType.getDescribe().isAccessible() &&
                Campaign.IsActive.getDescribe().isAccessible()
            ) {
                if (campaignId == null) {
                    // Using a dynamic describe access check in the method called above.
                    /* sfge-disable-next-line ApexFlsViolationRule */
                    for (Volunteer_Job__c vj : [
                        SELECT Name, Id
                        FROM Volunteer_Job__c
                        WHERE Campaign__r.IsActive = TRUE
                        ORDER BY name
                        LIMIT 999
                    ]) {
                        listSO.add(new SelectOption(vj.id, vj.name));
                    }
                } else {
                    // Using a dynamic describe access check in the method called above.
                    /* sfge-disable-next-line ApexFlsViolationRule */
                    for (Volunteer_Job__c vj : [
                        SELECT Name, Id
                        FROM Volunteer_Job__c
                        WHERE Campaign__c = :campaignId
                        ORDER BY name
                        LIMIT 999
                    ]) {
                        listSO.add(new SelectOption(vj.id, vj.name));
                    }
                }
            } // Allow the page to load without options

            return listSO;
        }
        set;
    }

    // the user has changed the Volunteer Job dropdown
    global virtual PageReference changeVolunteerJob() {
        // clear out all state that is specific to the Job
        return null;
    }

    /*******************************************************************************************************
     * @description Sanitizes Label.labelCalendarButtonText for use in JavaScript evaluation
     * @return  sanitized to use in JavaScript
     */
    public String getCalendarButtonText() {
        return sanitizer.buildSerializedObject(Label.labelCalendarButtonText);
    }

    /*******************************************************************************************************
     * @description Sanitizes Label.labelCalendarTitleFormat for use in JavaScript evaluation
     * @return  sanitized to use in JavaScript
     */
    public String getCalendarTitleFormat() {
        return sanitizer.buildSerializedObject(Label.labelCalendarTitleFormat);
    }

    /*******************************************************************************************************
     * @description Sanitizes Label.labelCalendarTimeFormat for use in JavaScript evaluation
     * @return  sanitized to use in JavaScript
     */
    public String getCalendarTimeFormat() {
        return sanitizer.buildSerializedObject(Label.labelCalendarTimeFormat);
    }

    /*******************************************************************************************************
     * @description Sanitizes Label.labelCalendarColumnFormat for use in JavaScript evaluation
     * @return  sanitized to use in JavaScript
     */
    public String getCalendarColumnFormat() {
        return sanitizer.buildSerializedObject(Label.labelCalendarColumnFormat);
    }

    /*******************************************************************************************************
     * @description Sanitizes Label.labelCalendarMonthNames for use in JavaScript evaluation
     * @return  sanitized to use in JavaScript
     */
    public String getCalendarMonthNames() {
        return sanitizer.buildSerializedList(Label.labelCalendarMonthNames);
    }

    /*******************************************************************************************************
     * @description Sanitizes Label.labelCalendarMonthNamesShort for use in JavaScript evaluation
     * @return  sanitized to use in JavaScript
     */
    public String getCalendarMonthNamesShort() {
        return sanitizer.buildSerializedList(Label.labelCalendarMonthNamesShort);
    }

    /*******************************************************************************************************
     * @description Sanitizes Label.labelCalendarDayNames for use in JavaScript evaluation
     * @return  sanitized to use in JavaScript
     */
    public String getCalendarDayNames() {
        return sanitizer.buildSerializedList(Label.labelCalendarDayNames);
    }

    /*******************************************************************************************************
     * @description Sanitizes Label.labelCalendarDayNamesShort for use in JavaScript evaluation
     * @return  sanitized to use in JavaScript
     */
    public String getCalendarDayNamesShort() {
        return sanitizer.buildSerializedList(Label.labelCalendarDayNamesShort);
    }

    /*******************************************************************************************************
     * @description Sanitizes Label.labelColorValues for use in JavaScript evaluation
     * @return  sanitized to use in JavaScript
     */
    public String getColorValues() {
        return sanitizer.buildSerializedList(Label.labelColorValues);
    }

    /********************************************************************************************************
     * @description Javascript Remoting method to return a list of Shifts, optionally filtered by strFilter.
     * @param strStartDateTime filter for Logs >= startDate
     * @param strEndDateTime filter for Logs <= endDate
     * @return List<Volunteer_Shift__c>, which will be turned into a Javascript collection.
     ********************************************************************************************************/
    @RemoteAction
    global static List<Volunteer_Shift__c> getListShifts( //NOPMD
        String strCampaignId,
        String strJobId,
        String strStartDateTime,
        String strEndDateTime
    ) {
        return getListShiftsWeb2(strCampaignId, strJobId, strStartDateTime, strEndDateTime, false, false);
    }

    /*******************************************************************************************************
     * @description Javascript Remoting method to return a list of Shifts, optionally filtered by strFilter.
     * @param strStartDateTime filter for Logs >= startDate
     * @param strEndDateTime filter for Logs <= endDate
     * @param fWeb whether to filter out job's who are not display on web.
     * @return List<Volunteer_Shift__c>, which will be turned into a Javascript collection.
     ********************************************************************************************************/
    @RemoteAction
    global static List<Volunteer_Shift__c> getListShiftsWeb( //NOPMD
        String strCampaignId,
        String strJobId,
        String strStartDateTime,
        String strEndDateTime,
        Boolean fWeb
    ) {
        return getListShiftsWeb2(strCampaignId, strJobId, strStartDateTime, strEndDateTime, fWeb, false);
    }

    /*******************************************************************************************************
     * @description Javascript Remoting method to return a list of Shifts, optionally filtered by strFilter.
     * @param strStartDateTime filter for Logs >= startDate
     * @param strEndDateTime filter for Logs <= endDate
     * @param fWeb whether to filter out job's who are not display on web.
     * @param fShowCampaignHierarchy whether do to include descendant campaigns of strCampaignId
     * @return List<Volunteer_Shift__c>, which will be turned into a Javascript collection.
     ********************************************************************************************************/
    @RemoteAction
    global static List<Volunteer_Shift__c> getListShiftsWeb2( //NOPMD
        String strCampaignId,
        String strJobId,
        String strStartDateTime,
        String strEndDateTime,
        Boolean fWeb,
        Boolean fShowCampaignHierarchy
    ) {
        DateTime dtStart = datetime.valueOf(strStartDateTime);
        DateTime dtEnd = datetime.valueOf(strEndDateTime);
        Boolean fAllCampaign = (strCampaignId == '*');
        Boolean fAllJob = (strJobId == '*');
        List<Volunteer_Shift__c> listShifts;

        // Ensure the user has access to the object and fields before querying
        UTIL_Describe.checkReadAccess(
            UTIL_Describe.StrTokenNSPrefix('Volunteer_Shift__c'),
            new Set<String>{
                'Id',
                'Name',
                UTIL_Describe.StrTokenNSPrefix('Volunteer_Job__c'),
                UTIL_Describe.StrTokenNSPrefix('Start_Date_Time__c'),
                UTIL_Describe.StrTokenNSPrefix('Duration__c'),
                UTIL_Describe.StrTokenNSPrefix('Total_Volunteers__c'),
                UTIL_Describe.StrTokenNSPrefix('Number_of_Volunteers_Still_Needed__c'),
                UTIL_Describe.StrTokenNSPrefix('Description__c')
            }
        );
        UTIL_Describe.checkReadAccess(
            UTIL_Describe.StrTokenNSPrefix('Volunteer_Job__c'),
            new Set<String>{
                'Name',
                UTIL_Describe.StrTokenNSPrefix('Campaign__c'),
                UTIL_Describe.StrTokenNSPrefix('Display_On_Website__c'),
                UTIL_Describe.StrTokenNSPrefix('Volunteer_Website_Time_Zone__c')
            }
        );
        UTIL_Describe.checkReadAccess(
            'Campaign',
            new Set<String>{ UTIL_Describe.StrTokenNSPrefix('Volunteer_Website_Time_Zone__c') }
        );

        if (!fAllJob) {
            listShifts = [
                SELECT
                    Id,
                    Name,
                    Volunteer_Job__c,
                    Volunteer_Job__r.Name,
                    Volunteer_Job__r.Volunteer_Website_Time_Zone__c,
                    Volunteer_Job__r.Campaign__r.Volunteer_Website_Time_Zone__c,
                    Volunteer_Job__r.Campaign__c,
                    Start_Date_Time__c,
                    Duration__c,
                    Total_Volunteers__c,
                    Number_of_Volunteers_Still_Needed__c,
                    Description__c
                FROM Volunteer_Shift__c
                WHERE
                    Start_Date_Time__c >= :dtStart
                    AND Start_Date_Time__c <= :dtEnd
                    AND Volunteer_Job__c = :strJobId
                    AND (Volunteer_Job__r.Display_On_Website__c = TRUE
                    OR Volunteer_Job__r.Display_On_Website__c = :fWeb)
                ORDER BY Start_Date_Time__c ASC
            ];
        } else if (fAllCampaign && fAllJob) {
            UTIL_Describe.checkReadAccess('Campaign', new Set<String>{ 'IsActive' });
            listShifts = [
                SELECT
                    Id,
                    Name,
                    Volunteer_Job__c,
                    Volunteer_Job__r.Name,
                    Volunteer_Job__r.Volunteer_Website_Time_Zone__c,
                    Volunteer_Job__r.Campaign__r.Volunteer_Website_Time_Zone__c,
                    Volunteer_Job__r.Campaign__c,
                    Start_Date_Time__c,
                    Duration__c,
                    Total_Volunteers__c,
                    Number_of_Volunteers_Still_Needed__c,
                    Description__c
                FROM Volunteer_Shift__c
                WHERE
                    Start_Date_Time__c >= :dtStart
                    AND Start_Date_Time__c <= :dtEnd
                    AND Volunteer_Job__r.Campaign__r.IsActive = TRUE
                    AND (Volunteer_Job__r.Display_On_Website__c = TRUE
                    OR Volunteer_Job__r.Display_On_Website__c = :fWeb)
                ORDER BY Start_Date_Time__c ASC
            ];
        } else if (!fAllCampaign && fAllJob) {
            List<Id> listCampaignIds = new List<Id>{ strCampaignId };
            if (fShowCampaignHierarchy) {
                listCampaignIds = VOL_SharedCode.listIdsCampaignsInHierarchy(strCampaignId);
            }
            listShifts = [
                SELECT
                    Id,
                    Name,
                    Volunteer_Job__c,
                    Volunteer_Job__r.Name,
                    Volunteer_Job__r.Volunteer_Website_Time_Zone__c,
                    Volunteer_Job__r.Campaign__r.Volunteer_Website_Time_Zone__c,
                    Volunteer_Job__r.Campaign__c,
                    Start_Date_Time__c,
                    Duration__c,
                    Total_Volunteers__c,
                    Number_of_Volunteers_Still_Needed__c,
                    Description__c
                FROM Volunteer_Shift__c
                WHERE
                    Start_Date_Time__c >= :dtStart
                    AND Start_Date_Time__c <= :dtEnd
                    AND Volunteer_Job__r.Campaign__c = :listCampaignIds
                    AND (Volunteer_Job__r.Display_On_Website__c = TRUE
                    OR Volunteer_Job__r.Display_On_Website__c = :fWeb)
                ORDER BY Start_Date_Time__c ASC
            ];
        }

        // to avoid FullCalendar from displaying shifts based on the user's machine time zone,
        // we translate it to the desired time zone, then say it is GMT.
        // get default time zone for site guest user
        User u = [SELECT TimeZoneSidKey FROM User WHERE Id = :Userinfo.getUserId()];

        for (Volunteer_Shift__c shift : listShifts) {
            String strTimeZone = shift.Volunteer_Job__r.Volunteer_Website_Time_Zone__c;
            if (strTimeZone == null) {
                strTimeZone = shift.Volunteer_Job__r.Campaign__r.Volunteer_Website_Time_Zone__c;
            }
            if (strTimeZone == null) {
                strTimeZone = u.TimeZoneSidKey;
            }
            shift.Start_Date_Time__c = DateTime.valueOfGmt(
                shift.Start_Date_Time__c.format('yyyy-MM-dd HH:mm:ss', strTimeZone)
            );
        }

        return listShifts;
    }

    // this was a testmethod which can't be compiled in this class under api 31.
    // but because it was marked global, it could not be completely removed.
    @SuppressWarnings('PMD.EmptyStatementBlock')
    global static void testJobCalendar() {
    }
}