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

@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class VOL_CTRL_PersonalSiteContactInfo {
    @TestVisible
    private static VOL_Access access = VOL_Access.getInstance();

    global VOL_CTRL_PersonalSiteContactInfo() {
        // set default property values
        cRowsCompleted = 10;
        cRowsUpcoming = 10;
        strDateFormat = 'E M/d/yy';
        strChartDateFormat = 'MMM yyyy';
        strTimeFormat = 'h:mm tt';
        strLanguage = 'en-us';
        isEditing = false;

        Map<String, String> params = ApexPages.currentPage().getParameters();
        String p = params.get('Language');
        if (p != null && p != '') {
            strLanguage = p;
        }
        p = params.get('DateFormat');
        if (p != null && p != '') {
            strDateFormat = p;
        }
        p = params.get('ChartDateFormat');
        if (p != null && p != '') {
            strChartDateFormat = p;
        }
        p = params.get('TimeFormat');
        if (p != null && p != '') {
            strTimeFormat = p;
        }
        p = params.get('contactId');
        if (p != null && p != '') {
            try {
                contactId = p;
            } catch (Exception ex) {
                contactId = null;
            }

            // now get new email parameter for extra validation
            // note that the validation routine only uses it if the setting for this extra validation is set
            if (!VOL_SharedCode.isValidContactIdAndEmail(contactId, params.get('Email'))) {
                contactId = null;
            }
            // cache the contactId for all pages to use.
            Cookie cId = new cookie('contactIdPersonalSite', contactId, null, -1, false);
            ApexPages.currentPage().setCookies(new List<Cookie>{ cId });
        } else {
            // check for cached Id
            Cookie cId = ApexPages.currentPage().getCookies().get('contactIdPersonalSite');
            if (cId != null) {
                contactId = cId.getValue();
            }
        }

        // if we still don't know who we are editing, need to bail out.
        if (contactId == null) {
            ApexPages.addMessage(
                new ApexPages.Message(
                    ApexPages.Severity.FATAL,
                    'Please pass in a valid contactId and Email with the URL.'
                )
            );
            return;
        }

        List<String> listStrFieldsPanel1FS = VOL_SharedCode.listStrFieldsFromFieldSet(
            Schema.SObjectType.Contact.FieldSets.PersonalSiteContactInfoPanel1FS
        );
        List<String> listStrFieldsPanel2FS = VOL_SharedCode.listStrFieldsFromFieldSet(
            Schema.SObjectType.Contact.FieldSets.PersonalSiteContactInfoPanel2FS
        );
        List<String> listStrFieldsExtraFS = VOL_SharedCode.listStrFieldsFromFieldSet(
            Schema.SObjectType.Contact.FieldSets.PersonalSiteContactInfoExtraFS
        );

        Set<String> setStrFields = new Set<String>();
        setStrFields.addAll(listStrFieldsPanel1FS);
        setStrFields.addAll(listStrFieldsPanel2FS);
        setStrFields.addAll(listStrFieldsExtraFS);
        setStrFields.add('Firstname');
        setStrFields.add('Lastname');
        contactReadOnly = (Contact) VOL_SharedCode.LoadAndCopyObject(
            contactId,
            contactEdit,
            new List<String>(setStrFields)
        );

        // output error page messages for any field that doesn't have visibility correctly set.
        VOL_SharedCode.testObjectFieldVisibility('Contact', listStrFieldsPanel1FS);
        VOL_SharedCode.testObjectFieldVisibility('Contact', listStrFieldsPanel2FS);
        VOL_SharedCode.testObjectFieldVisibility('Contact', listStrFieldsExtraFS);
        VOL_SharedCode.testObjectFieldVisibility(
            VOL_SharedCode.StrTokenNSPrefix('Volunteer_Hours__c'),
            VOL_SharedCode.listStrFieldsFromFieldSet(
                Schema.SObjectType.Volunteer_Hours__c.FieldSets.PersonalSiteContactInfoUpcomingShifts
            )
        );
        VOL_SharedCode.testObjectFieldVisibility(
            VOL_SharedCode.StrTokenNSPrefix('Volunteer_Hours__c'),
            VOL_SharedCode.listStrFieldsFromFieldSet(
                Schema.SObjectType.Volunteer_Hours__c.FieldSets.PersonalSiteContactInfoHistory
            )
        );
    }

    global Contact contactEdit {
        get {
            if (contactEdit == null) {
                contactEdit = new Contact();
            }
            return contactEdit;
        }
        set;
    }

    global Contact contactReadOnly {
        get {
            return contactReadOnly;
        }
        set;
    }

    global Id contactId { get; set; }
    global Boolean isEditing { get; set; }
    global Id hoursId { get; set; } // to hold the Id of the hours record an action is being performed on.
    global Integer cRowsCompleted { get; set; }
    global Integer cRowsUpcoming { get; set; }
    global String strDateFormat { get; set; }
    global String strChartDateFormat { get; set; }
    global String strTimeFormat { get; set; }
    global String strLanguage { get; set; }

    public List<String> listStrContactFields {
        get {
            if (listStrContactFields == null) {
                List<String> listStrFields1 = VOL_SharedCode.listStrFieldsFromContactFieldSet(
                    Schema.SObjectType.Contact.fieldSets.PersonalSiteContactInfoPanel1FS
                );
                List<String> listStrFields2 = VOL_SharedCode.listStrFieldsFromContactFieldSet(
                    Schema.SObjectType.Contact.fieldSets.PersonalSiteContactInfoPanel2FS
                );
                // because we used to get all Contact fields, we need a way for people extending the page to tell us additional fields to query for.
                List<String> listStrFields3 = VOL_SharedCode.listStrFieldsFromContactFieldSet(
                    Schema.SObjectType.Contact.fieldSets.PersonalSiteContactInfoExtraFS
                );

                Set<String> setStrFields = new Set<String>();
                setStrFields.addAll(listStrFields1);
                setStrFields.addAll(listStrFields2);
                setStrFields.addAll(listStrFields3);
                setStrFields.add('Firstname');
                setStrFields.add('Lastname');
                listStrContactFields = new List<String>();
                listStrContactFields.addAll(setStrFields);
            }
            return listStrContactFields;
        }
        set;
    }

    public List<String> listStrHoursFields {
        get {
            if (listStrHoursFields == null) {
                Map<String, Schema.SObjectField> mapS = Schema.SObjectType.Volunteer_Hours__c.fields.getMap();
                listStrHoursFields = new List<String>();
                listStrHoursFields.addAll(mapS.keySet());
            }
            return listStrHoursFields;
        }
        set;
    }

    // The list of Completed Volunteer Hours.
    global List<Volunteer_Hours__c> listCompletedVolunteerHours {
        get {
            if (listCompletedVolunteerHours == null) {
                String strSoql =
                    'SELECT Volunteer_Job__r.Name, Volunteer_Job__r.Volunteer_Website_Time_Zone__c, ' +
                    ' Volunteer_Job__r.Campaign__r.Volunteer_Website_Time_Zone__c, Volunteer_Shift__r.Duration__c, ';
                String strComma = '';
                for (String strF : listStrHoursFields) {
                    strSoql += strComma + strF;
                    strComma = ', ';
                }
                strSoql += ' from Volunteer_Hours__c where Contact__c = :contactId ';
                strSoql += ' and Status__c = \'Completed\' ';
                strSoql += ' order by Start_Date__c DESC ';
                strSoql += ' limit ' + cRowsCompleted;
                SObjectAccessDecision accessDecision = Security.stripInaccessible(
                    AccessType.READABLE,
                    Database.query(strSoql)
                );
                listCompletedVolunteerHours = (List<Volunteer_Hours__c>) accessDecision.getRecords();

                // store friendly datetime string in system field for display only
                dateTimeFixup(listCompletedVolunteerHours);
            }
            return listCompletedVolunteerHours;
        }
        set;
    }

    // does this Volunteer have any completed hours?
    global Boolean hasCompletedHours {
        get {
            return listCompletedVolunteerHours.size() > 0;
        }
    }

    // The list of Upcoming Volunteer Hours.
    global List<Volunteer_Hours__c> listUpcomingVolunteerHours {
        get {
            try {
                // Ensure the user has access to the object and fields before querying
                UTIL_Describe.checkReadAccess(
                    UTIL_Describe.StrTokenNSPrefix('Volunteer_Hours__c'),
                    new Set<String>{
                        UTIL_Describe.StrTokenNSPrefix('Status__c'),
                        UTIL_Describe.StrTokenNSPrefix('Shift_Start_Date_Time__c'),
                        UTIL_Describe.StrTokenNSPrefix('Contact__c')
                    }
                );
                UTIL_Describe.checkReadAccess(
                    UTIL_Describe.StrTokenNSPrefix('Volunteer_Job__c'),
                    new Set<String>{ 'Name', UTIL_Describe.StrTokenNSPrefix('Volunteer_Website_Time_Zone__c') }
                );
                UTIL_Describe.checkReadAccess(
                    'Campaign',
                    new Set<String>{ UTIL_Describe.StrTokenNSPrefix('Volunteer_Website_Time_Zone__c') }
                );
                UTIL_Describe.checkReadAccess(
                    UTIL_Describe.StrTokenNSPrefix('Volunteer_Shift__c'),
                    new Set<String>{ UTIL_Describe.StrTokenNSPrefix('Duration__c') }
                );

                if (listUpcomingVolunteerHours == null) {
                    String strSoql =
                        'SELECT Volunteer_Job__r.Name, Volunteer_Job__r.Volunteer_Website_Time_Zone__c, ' +
                        ' Volunteer_Job__r.Campaign__r.Volunteer_Website_Time_Zone__c, Volunteer_Shift__r.Duration__c, ';
                    String strComma = '';
                    for (String strF : listStrHoursFields) {
                        strSoql += strComma + strF;
                        strComma = ', ';
                    }
                    DateTime dtToday = datetime.newInstance(System.today(), time.newInstance(0, 0, 0, 0));
                    strSoql += ' from Volunteer_Hours__c where Contact__c = :contactId ';
                    strSoql += ' and Status__c <> \'Canceled\' and Status__c <>  \'Completed\' ';
                    strSoql += ' and Shift_Start_Date_Time__c >= :dtToday ';
                    strSoql += ' order by Shift_Start_Date_Time__c ASC ';
                    strSoql += ' limit ' + cRowsUpcoming;
                    // Using a dynamic describe access check in the method called above.
                    /* sfge-disable-next-line ApexFlsViolationRule */
                    listUpcomingVolunteerHours = Database.query(strSoql);
                    // store friendly datetime string in system field for display only
                    dateTimeFixup(listUpcomingVolunteerHours);
                }
                return listUpcomingVolunteerHours;
            } catch (Exception e) {
                ApexPages.addMessages(e);
                return null;
            }
        }
        set;
    }

    // routine to go through all the hours, and create the display string
    // for the shifts start time - end date & time, using the appropriate
    // time zone that might be specified on the Job, Campaign, or Site Guest User.
    // Note that it stores the formatted Time in the Hours' System_Note__c field (in memory only).
    // Note that it stores the formatted Date in the Hours' Comment field (in memory only).
    private void dateTimeFixup(List<Volunteer_Hours__c> listHours) {
        // get default time zone for site guest user
        User u = [SELECT TimeZoneSidKey FROM User WHERE Id = :Userinfo.getUserId()];

        // javascript formatting used 'tt' for am/pm, whereas apex formatting uses 'a'.
        String strFormat = strDateFormat + ' ' + strTimeFormat.replace('tt', 'a');
        String strFormatEndTime = strTimeFormat.replace('tt', 'a');

        for (Volunteer_Hours__c hr : listHours) {
            String strTimeZone = hr.Volunteer_Job__r.Volunteer_Website_Time_Zone__c;
            if (strTimeZone == null) {
                strTimeZone = hr.Volunteer_Job__r.Campaign__r.Volunteer_Website_Time_Zone__c;
            }
            if (strTimeZone == null) {
                strTimeZone = u.TimeZoneSidKey;
            }

            DateTime dtStart = hr.Planned_Start_Date_Time__c == null
                ? hr.Shift_Start_Date_Time__c
                : hr.Planned_Start_Date_Time__c;
            if (dtStart == null) {
                // if we don't have a start time, then format by GMT, to avoid timezones moving the date!
                dtStart = hr.Start_Date__c;
                hr.Comments__c = dtStart.formatGmt(strDateFormat);
            } else {
                double duration = hr.Hours_Worked__c == null ? hr.Volunteer_Shift__r.Duration__c : hr.Hours_Worked__c;
                DateTime dtEnd = dtStart.addMinutes(Integer.valueOf(duration * 60));
                String strStart = dtStart.format(strFormat, strTimeZone);

                // see if start and end are on the same day
                if (dtStart.format('d', strTimeZone) == dtEnd.format('d', strTimeZone)) {
                    hr.System_Note__c =
                        dtStart.format(strFormatEndTime, strTimeZone) +
                        ' - ' +
                        dtEnd.format(strFormatEndTime, strTimeZone);
                } else {
                    hr.System_Note__c =
                        dtStart.format(strFormatEndTime, strTimeZone) +
                        ' - ' +
                        dtEnd.format(strFormat, strTimeZone);
                }

                // also save user formated Start Date in Comments field
                hr.Comments__c = dtStart.format(strDateFormat, strTimeZone);
            }
        }
    }

    global PageReference edit() {
        isEditing = true;
        return null;
    }

    global PageReference save() {
        try {
            if (contactReadOnly != null) {
                Set<String> contactFieldsToUpdate = new Set<String>();

                //  now copy over all the non-null fields from the form's contact to the existing contact.
                for (String strF : listStrContactFields) {
                    if (contactEdit.get(strF) != null) {
                        try {
                            contactReadOnly.put(strF, contactEdit.get(strF));
                            contactFieldsToUpdate.add(strF);
                        } catch (exception ex) {
                            // we need this catch because some of the fields in listStrContactFields
                            // are readonly formula fields.  We can't use describes for isCreatable,
                            // because we won't know the difference between a formula field vs. one
                            // they don't have permissions to (which we will check below).
                            System.debug('');
                        }
                    }
                }
                VOL_SharedCode.checkUpdateAccessSites('Contact', contactFieldsToUpdate);
                access.updateRecords(new List<Contact>{ contactReadOnly });
            }
            isEditing = false;
        } catch (Exception ex) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.FATAL, ex.getMessage()));
        }
        return null;
    }

    global PageReference cancel() {
        isEditing = false;
        return null;
    }

    global PageReference cancelShift() {
        try {
            if (hoursId != null) {
                // We are dynamically check update access below, the query result is not being returned to the user.
                /* sfge-disable-next-line ApexFlsViolationRule */
                Volunteer_Hours__c hr = [
                    SELECT Id, Status__c, Hours_Worked__c
                    FROM Volunteer_Hours__c
                    WHERE Id = :hoursId
                ];
                hr.Status__c = 'Canceled';
                hr.Hours_Worked__c = 0;
                access.checkUpdateAccess(
                    UTIL_Describe.StrTokenNSPrefix('Volunteer_Hours__c'),
                    new Set<String>{
                        UTIL_Describe.StrTokenNSPrefix('Status__c'),
                        UTIL_Describe.StrTokenNSPrefix('Hours_Worked__c')
                    }
                );
                // We are dynamically check update access above.
                /* sfge-disable-next-line ApexFlsViolationRule */
                access.updateRecords(new List<Volunteer_Hours__c>{ hr });

                hoursId = null;
                listUpcomingVolunteerHours = null; // to force it to be refreshed.
            }
            return null;
        } catch (Exception e) {
            ApexPages.addMessages(e);
            return null;
        }
    }

    global PageReference showMoreRowsCompleted() {
        cRowsCompleted += 10;
        listCompletedVolunteerHours = null;
        return null;
    }

    global PageReference showMoreRowsUpcoming() {
        cRowsUpcoming += 10;
        listUpcomingVolunteerHours = null;
        return null;
    }

    // global method to get the list of ChartData items to run the visualforce chart off of.
    global List<ChartData> getChartData() {
        Integer cMonths = 12;
        Date dtStart = date.today().addMonths(-cMonths + 1).toStartOfMonth();
        List<ChartData> listCD = new List<ChartData>();

        if (
            Volunteer_Hours__c.SObjectType.getDescribe().isAccessible() &&
            Volunteer_Hours__c.Start_Date__c.getDescribe().isAccessible() &&
            Volunteer_Hours__c.Hours_Worked__c.getDescribe().isAccessible() &&
            Volunteer_Hours__c.Contact__c.getDescribe().isAccessible() &&
            Volunteer_Hours__c.Status__c.getDescribe().isAccessible()
        ) {
            List<AggregateResult> listAG = [
                SELECT
                    CALENDAR_YEAR(Start_Date__c) theYear,
                    CALENDAR_MONTH(Start_Date__c) theMonth,
                    SUM(Hours_Worked__c) sumHours
                FROM Volunteer_Hours__c
                WHERE Contact__c = :contactId AND Status__c = 'Completed' AND Start_Date__c >= :dtStart
                GROUP BY CALENDAR_YEAR(Start_Date__c), CALENDAR_MONTH(Start_Date__c)
                ORDER BY CALENDAR_YEAR(Start_Date__c), CALENDAR_MONTH(Start_Date__c)
            ];

            Date dtNext = dtStart;
            Time timeT = Time.newInstance(1, 0, 0, 0);
            for (AggregateResult ag : listAG) {
                Date dt = date.newInstance(Integer.valueOf(ag.get('theYear')), Integer.valueOf(ag.get('theMonth')), 1);

                // handle months with no data
                while (dtNext < dt) {
                    listCD.add(new ChartData(datetime.newInstance(dtNext, timeT).format(strChartDateFormat), 0));
                    dtNext = dtNext.addMonths(1);
                }

                listCD.add(
                    new ChartData(
                        datetime.newInstance(dt, timeT).format(strChartDateFormat),
                        Integer.valueOf(ag.get('sumHours'))
                    )
                );
                dtNext = dt.addMonths(1);
            }
        } // Allow the page to load without the chart data.

        return listCD;
    }

    // our wrapper class to hold chart data for each of the last N months
    global class ChartData {
        public String strDateLabel { get; set; }
        public Integer sumHours { get; set; }
        public ChartData(String strDateLabel, Integer sumHours) {
            this.strDateLabel = strDateLabel;
            this.sumHours = sumHours;
        }
    }

    global String strRank {
        get {
            if (strRank == null) {
                try {
                    strRank = strRankLast12Months();
                } catch (exception ex) {
                    strRank = strRankLifetime();
                }
            }
            return strRank;
        }
        private set;
    }

    private String strRankLast12Months() {
        Integer cMonths = 12;
        Date dtStart = date.today().addMonths(-cMonths + 1).toStartOfMonth();
        Integer iVol = 0;
        Integer iCurrent = 0;

        UTIL_Describe.checkReadAccess(
            UTIL_Describe.StrTokenNSPrefix('Volunteer_Hours__c'),
            new Set<String>{
                'Id',
                UTIL_Describe.StrTokenNSPrefix('Start_Date__c'),
                UTIL_Describe.StrTokenNSPrefix('Hours_Worked__c'),
                UTIL_Describe.StrTokenNSPrefix('Contact__c'),
                UTIL_Describe.StrTokenNSPrefix('Status__c')
            }
        );

        for (List<AggregateResult> listAG : [
            SELECT Contact__c cId, SUM(Hours_Worked__c) sumHours
            FROM Volunteer_Hours__c
            WHERE Status__c = 'Completed' AND Start_Date__c >= :dtStart
            GROUP BY Contact__c
            HAVING SUM(Hours_Worked__c) > 0
            ORDER BY SUM(Hours_Worked__c) DESC
        ]) {
            for (AggregateResult ag : listAG) {
                if (ag.get('cId') == contactId) {
                    iCurrent = iVol;
                }
                iVol++;
            }
        }
        if (iVol > 2) {
            Integer irank = Integer.valueOf(100 * (decimal.valueOf(iCurrent) / decimal.valueOf(iVol - 1)));
            if (irank == 0) {
                irank = 1;
            }
            return String.format(Label.labelContactInfoRankText12Months, new List<String>{ irank + '%' });
        } else {
            return '';
        }
    }

    @TestVisible
    private String strRankLifetime() {
        try {
            UTIL_Describe.checkReadAccess(
                'Contact',
                new Set<String>{ 'Id', UTIL_Describe.StrTokenNSPrefix('Volunteer_Hours__c') }
            );
            // Using a dynamic describe access check in the method called above.
            /* sfge-disable-next-line ApexFlsViolationRule */
            Decimal contactTotalHours = [SELECT Id, Volunteer_Hours__c FROM Contact WHERE Id = :contactId LIMIT 1]
            .Volunteer_Hours__c;

            if (contactTotalHours == null || contactTotalHours == 0) {
                return '';
            }

            String hoursField = String.valueOf(Contact.Volunteer_Hours__c);
            String totalVolunteersQuery = 'SELECT count() FROM Contact WHERE ' + hoursField + ' > 0';
            String totalVolunteersWithMoreHoursQuery =
                totalVolunteersQuery +
                ' AND ' +
                hoursField +
                ' > ' +
                contactTotalHours;
            // Using a dynamic describe access check in the method called above.
            /* sfge-disable-next-line ApexFlsViolationRule */
            Integer totalVolunteers = Database.countQuery(totalVolunteersQuery);

            if (totalVolunteers <= 2) {
                return '';
            }
            // Using a dynamic describe access check in the method called above.
            /* sfge-disable-next-line ApexFlsViolationRule */
            Integer totalVolunteersWithMoreHours = Database.countQuery(totalVolunteersWithMoreHoursQuery);

            Integer rank = Integer.valueOf(
                100 * (Decimal.valueOf(totalVolunteersWithMoreHours) / Decimal.valueOf(totalVolunteers - 1))
            );

            if (rank == 0) {
                rank = 1;
            }

            return String.format(Label.labelContactInfoRankTextLifetime, new List<String>{ rank + '%' });
        } catch (Exception ex) {
            return ''; // allow the page to load without the ranking
        }
    }
}