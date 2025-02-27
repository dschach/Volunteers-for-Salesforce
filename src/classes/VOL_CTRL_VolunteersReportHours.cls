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
global virtual with sharing class VOL_CTRL_VolunteersReportHours {
    private VOL_SharedCode volSharedCode;

    @TestVisible
    private static VOL_Access access = VOL_Access.getInstance();

    // constructor
    global VOL_CTRL_VolunteersReportHours() {
        try {
            volSharedCode = new VOL_SharedCode();

            // initial values for potential parameters
            strLanguage = 'en-us';
            strDateFormat = 'EEEE M/d/yyyy';
            strTimeFormat = 'h:mm tt';

            // handle optional page parameters (must use String, not Id, to handle null)
            Map<String, String> params = ApexPages.currentPage().getParameters();
            String p = params.get('Language');
            if (p != null && p != '') {
                strLanguage = p;
            }
            p = params.get('DateFormat');
            if (p != null && p != '') {
                strDateFormat = p;
            }
            p = params.get('TimeFormat');
            if (p != null && p != '') {
                strTimeFormat = p;
            }
            // we now get the fields from the fieldset
            listStrFields = VOL_SharedCode.listStrFieldsFromContactFieldSet(
                Schema.SObjectType.Contact.fieldSets.VolunteersReportHoursFS
            );

            // output error page messages for any field that doesn't have visibility correctly set.
            VOL_SharedCode.testObjectFieldVisibility('Contact', listStrFields);

            // we can derive whether we are within the Personal Site or not, so no need for parameter.
            fPersonalSite = ApexPages.currentPage().getUrl().contains('PersonalSite');

            checkCreateAccess();
            checkUpdateAccess();
        } catch (Exception e) {
            ApexPages.addMessages(e);
        }
    }

    // holds the contact fields on the page
    global Contact contact {
        get {
            if (contact == null) {
                contact = new Contact();

                // when used within the Personal Site, we should use the appropriate Contact
                contactIdPersonalSite = null;
                Cookie cId = ApexPages.currentPage().getCookies().get('contactIdPersonalSite');
                if (cId != null) {
                    contactIdPersonalSite = cId.getValue();
                }
                if (contactIdPersonalSite != null && contactIdPersonalSite != '') {
                    VOL_SharedCode.LoadAndCopyObject(contactIdPersonalSite, contact, listStrFields);
                } else {
                    // if state & country picklists enabled, we want to copy in any defaults from state/country Code to
                    // the state & country fields, since the picklists cannot be included in the field set.
                    if (VOL_StateCountryPicklists.isStateCountryPicklistsEnabled) {
                        VOL_StateCountryPicklists.copyAddressStdSObj(contact, 'Mailing', contact, 'Mailing');
                        VOL_StateCountryPicklists.copyAddressStdSObj(contact, 'Other', contact, 'Other');
                    }
                }
            }
            return contact;
        }
        set;
    }

    private String contactIdPersonalSite { get; set; }

    // holds the dates and hours fields on the page
    global Volunteer_Hours__c vhours {
        get {
            if (vhours == null) {
                vhours = new Volunteer_Hours__c();
            }
            return vhours;
        }
        set;
    }

    // returns the correct URL for the CSS override file
    global String strURLtoCSSFile {
        get {
            if (fPersonalSite) {
                return null; // just use whatever CSS the Site Template includes.
            }

            if (strURLtoCSSFile == null) {
                List<Document> listDocs = [
                    SELECT Name, Id
                    FROM Document
                    WHERE Name = 'VolunteersReportHoursCSS.css'
                    LIMIT 1
                ];
                if (listDocs.size() > 0) {
                    Document doc = listDocs[0];
                    String imageid = doc.Id;
                    imageid = imageid.substring(0, 15);
                    strURLToCSSFile = '/servlet/servlet.FileDownload?file=' + imageid;
                }
            }
            return strURLtoCSSFile;
        }
        set;
    }

    // global properties
    global String strLanguage { get; set; }
    global String strDateFormat { get; set; }
    global String strTimeFormat { get; set; }
    global List<String> listStrFields { get; set; }
    global Boolean fPersonalSite { get; set; }

    // status  for reporting the results of saving.
    global String strSaveResult { get; set; }

    // holds the currently select Job in the Job dropdown
    global Id volunteerJobId { get; set; }

    // returns true when jobs are available for contact
    // we check the size against 1 (not 0) becasue of the first empty select option
    global Boolean hasVolunteerJobs {
        get {
            return 1 < listSOVolunteerJobs.size();
        }
        set;
    }

    // the list of Volunteer Jobs to put in the dropdown
    global List<SelectOption> listSOVolunteerJobs {
        get {
            if (listSOVolunteerJobs == null) {
                listSOVolunteerJobs = new List<SelectOption>();
                listSOVolunteerJobs.add(new SelectOption('', ''));

                // Ensure the user has access to the object before querying
                try {
                    UTIL_Describe.checkObjectReadAccess(String.valueOf(Volunteer_Job__c.SObjectType));
                } catch (Exception ex) {
                    // we will return an empty list vs throwing an error
                    return listSOVolunteerJobs;
                }

                Boolean filterByContact = VOL_SharedCode.VolunteersSettings.Personal_Site_Report_Hours_Filtered__c;
                List<Volunteer_Job__c> volunteerJobs = new List<Volunteer_Job__c>();
                if (filterByContact && contactIdPersonalSite != null) {
                    volunteerJobs = [
                        SELECT
                            Name,
                            Id,
                            (
                                SELECT Id, Contact__c
                                FROM Volunteer_Hours__r
                                WHERE Contact__c = :contactIdPersonalSite
                                LIMIT 1
                            )
                        FROM Volunteer_Job__c
                        WHERE Campaign__r.IsActive = TRUE AND Inactive__c = FALSE
                        ORDER BY name
                        LIMIT 999
                    ];
                } else {
                    volunteerJobs = [
                        SELECT Name, Id
                        FROM Volunteer_Job__c
                        WHERE Campaign__r.IsActive = TRUE AND Inactive__c = FALSE
                        ORDER BY name
                        LIMIT 999
                    ];
                }

                for (Volunteer_Job__c vj : volunteerJobs) {
                    if (filterByContact && contactIdPersonalSite != null) {
                        for (Volunteer_Hours__c volHour : vj.Volunteer_Hours__r) {
                            listSOVolunteerJobs.add(new SelectOption(vj.id, vj.name));
                        }
                    } else {
                        listSOVolunteerJobs.add(new SelectOption(vj.id, vj.name));
                    }
                }
            }
            return listSOVolunteerJobs;
        }
        set;
    }

    // the user has changed the Volunteer Job dropdown
    global virtual PageReference changeVolunteerJob() {
        // clear out all state that is specific to the Job
        strSaveResult = null;
        listSOVolunteerShifts = null;
        volunteerShiftId = null;
        ChangeVolunteerShift();
        return null;
    }

    // holds the currently select Job Shift in the Job Shift dropdown
    global Id volunteerShiftId { get; set; }

    // the list of Volunteer Shifts to put in the dropdown
    global List<SelectOption> listSOVolunteerShifts {
        get {
            if (listSOVolunteerShifts == null && volunteerJobId != null) {
                listSOVolunteerShifts = VOL_SharedCode.listSOVolunteerShiftsOfVolunteerJobIdFormat(
                    volunteerJobId,
                    System.today().addMonths(-2),
                    System.today().addMonths(1),
                    false,
                    false,
                    strDateFormat,
                    strTimeFormat
                );
            }
            return listSOVolunteerShifts;
        }
        set;
    }

    // specifies whether the currently selected Job has any Shifts.
    global Boolean hasShifts {
        get {
            return listSOVOlunteerShifts != null && listSOVolunteerShifts.size() > 1;
        }
        set;
    }

    // the user has changed the Volunteer Shift dropdown
    global virtual PageReference changeVolunteerShift() {
        // clear out info
        strSaveResult = null;
        vhours.Start_Date__c = null;
        vhours.End_Date__c = null;
        vhours.Hours_Worked__c = null;
        vhours.Volunteer_Job__c = volunteerJobId;
        vhours.Volunteer_Shift__c = volunteerShiftId;

        // set date and hours from shift
        if (volunteerShiftId != null) {
            UTIL_Describe.checkReadAccess(
                UTIL_Describe.StrTokenNSPrefix('Volunteer_Shift__c'),
                new Set<String>{
                    'Id',
                    UTIL_Describe.StrTokenNSPrefix('Start_Date_Time__c'),
                    UTIL_Describe.StrTokenNSPrefix('Duration__c')
                }
            );
            Volunteer_Shift__c shift = [
                SELECT Start_Date_Time__c, Duration__c
                FROM Volunteer_Shift__c
                WHERE Id = :volunteerShiftId
            ];
            vhours.Start_Date__c = shift.Start_Date_Time__c.Date();
            vhours.End_Date__c = vhours.Start_Date__c;
            vhours.Hours_Worked__c = shift.Duration__c;
        }
        return null;
    }

    private class MyException extends Exception {
    }

    // action method for saving the the volunteer's hours.
    global virtual PageReference save() {
        Savepoint sp = Database.setSavepoint();
        try {
            // because we need to use actionSupport immediate=false to support the combo's,
            // we couldn't actually use visualforce's required=true property on fields.
            // so we must manually enforce the fields we want required ourselves.
            Boolean hasErrors = false;

            // first deal with fields on the contact.
            for (Schema.FieldSetMember f : SObjectType.Contact.FieldSets.VolunteersReportHoursFS.getFields()) {
                if (contact.get(f.getFieldPath()) == null && (f.getDBRequired() || f.getRequired())) {
                    ApexPages.addMessage(
                        new ApexPages.Message(
                            ApexPages.Severity.FATAL,
                            String.Format(
                                System.Label.labelVolunteerReportHoursErrorRequiredField,
                                new List<String>{ f.getLabel() }
                            )
                        )
                    );
                    hasErrors = true;
                }
            }

            if (volunteerJobId == null) {
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.Severity.FATAL,
                        String.Format(
                            System.Label.labelVolunteerReportHoursErrorRequiredField,
                            new List<String>{ Schema.sObjectType.Volunteer_Hours__c.fields.Volunteer_Job__c.getLabel() }
                        )
                    )
                );
                hasErrors = true;
            }
            if (vhours.Start_Date__c == null) {
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.Severity.FATAL,
                        String.Format(
                            System.Label.labelVolunteerReportHoursErrorRequiredField,
                            new List<String>{ Schema.sObjectType.Volunteer_Hours__c.fields.Start_Date__c.getLabel() }
                        )
                    )
                );
                hasErrors = true;
            }
            if (vhours.End_Date__c == null) {
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.Severity.FATAL,
                        String.Format(
                            System.Label.labelVolunteerReportHoursErrorRequiredField,
                            new List<String>{ Schema.sObjectType.Volunteer_Hours__c.fields.End_Date__c.getLabel() }
                        )
                    )
                );
                hasErrors = true;
            }
            if (vhours.Hours_Worked__c == null) {
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.Severity.FATAL,
                        String.Format(
                            System.Label.labelVolunteerReportHoursErrorRequiredField,
                            new List<String>{ Schema.sObjectType.Volunteer_Hours__c.fields.Hours_Worked__c.getLabel() }
                        )
                    )
                );
                hasErrors = true;
            }

            // check additional fields on the vol hours
            for (
                Schema.FieldSetMember f : SObjectType.Volunteer_Hours__c.FieldSets.VolunteersReportHoursFS.getFields()
            ) {
                if (vhours.get(f.getFieldPath()) == null && (f.getDBRequired() || f.getRequired())) {
                    ApexPages.addMessage(
                        new ApexPages.Message(
                            ApexPages.Severity.FATAL,
                            String.Format(
                                System.Label.labelVolunteerReportHoursErrorRequiredField,
                                new List<String>{ f.getLabel() }
                            )
                        )
                    );
                    hasErrors = true;
                }
            }

            // now bail out if any required fields are missing.
            if (hasErrors) {
                strSaveResult = null;
                return null;
            }

            // save or update the contact
            Id contactId = VOL_SharedCode.CreateOrUpdateContactFS(
                contactIdPersonalSite,
                contact,
                contact.Volunteer_Organization__c,
                listStrFields,
                false
            );

            List<Volunteer_Hours__c> listHours = null;

            if (volunteerShiftId != null) {
                // search for an existing Hours record to update, if they specified a Shift
                listHours = [
                    SELECT Id
                    FROM Volunteer_Hours__c
                    WHERE Volunteer_Shift__c = :volunteerShiftId AND Contact__c = :contactId
                ];
            } else {
                // search for an existing Hours record to update for this job
                // match non-committed hours, or committed where the start date is the same.
                listHours = [
                    SELECT Id
                    FROM Volunteer_Hours__c
                    WHERE
                        Volunteer_Job__c = :volunteerJobId
                        AND Contact__c = :contactId
                        AND (Status__c != 'Completed'
                        OR Start_Date__c = :vhours.Start_Date__c)
                ];
            }

            // if we found a matching Hours, just update it
            if (listHours != null && listHours.size() > 0) {
                checkUpdateAccess();

                listHours[0].Status__c = 'Completed';
                listHours[0].Start_Date__c = vhours.Start_Date__c;
                listHours[0].End_Date__c = vhours.End_Date__c;
                listHours[0].Hours_Worked__c = vhours.Hours_Worked__c;

                // update the additional fields, if any
                for (
                    Schema.FieldSetMember f : SObjectType.Volunteer_Hours__c.FieldSets.VolunteersReportHoursFS.getFields()
                ) {
                    String fieldName = f.getFieldPath();
                    if (vhours.get(fieldName) != null) {
                        listHours[0].put(fieldName, vhours.get(fieldName));
                    }
                }

                access.updateRecords(new List<Volunteer_Hours__c>{ listHours[0] });
            } else {
                checkCreateAccess();

                // create new hours if needed
                vhours.Volunteer_Job__c = volunteerJobId;
                vhours.Volunteer_Shift__c = volunteerShiftId;
                vhours.Status__c = 'Completed';
                vhours.Contact__c = contactId;
                vhours.Number_of_Volunteers__c = 1;
                access.insertRecords(new List<Volunteer_Hours__c>{ vhours });
            }

            // clear current job & shift info
            volunteerJobId = null;
            ChangeVolunteerJob();
            vhours = null;

            strSaveResult = System.Label.labelVolunteerReportHoursThankYou;
        } catch (DMLException ex) {
            Database.rollback(sp);
            //Added check for FIELD_CUSTOM_VALIDATION_EXCEPTION to return user friendly error.
            strSaveResult = ex.getMessage();
            if (strSaveResult.contains('FIELD_CUSTOM_VALIDATION_EXCEPTION')) {
                strSaveResult = strSaveResult.substringBetween('FIELD_CUSTOM_VALIDATION_EXCEPTION, ', ': ');
            }
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.FATAL, strSaveResult));
            strSaveResult = null;
        } catch (exception ex) {
            Database.rollback(sp);
            strSaveResult = null;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.FATAL, ex.getMessage()));
        }
        return null;
    }

    /*******************************************************************************************************
     * @description check if the current user has a "Create" permission on the listed fields
     * @return void.
     ********************************************************************************************************/
    private void checkCreateAccess() {
        access.checkCreateAccess(
            UTIL_Describe.StrTokenNSPrefix('Volunteer_Hours__c'),
            new Set<String>{
                UTIL_Describe.StrTokenNSPrefix('Volunteer_Job__c'),
                UTIL_Describe.StrTokenNSPrefix('Volunteer_Shift__c'),
                UTIL_Describe.StrTokenNSPrefix('Status__c'),
                UTIL_Describe.StrTokenNSPrefix('Contact__c'),
                UTIL_Describe.StrTokenNSPrefix('Number_of_Volunteers__c')
            }
        );
    }

    /*******************************************************************************************************
     * @description check if the current user has a "Edit" permission on the listed fields.
     ********************************************************************************************************/
    private void checkUpdateAccess() {
        Set<String> flsCheckFields = new Set<String>{
            UTIL_Describe.StrTokenNSPrefix('End_Date__c'),
            UTIL_Describe.StrTokenNSPrefix('Hours_Worked__c'),
            UTIL_Describe.StrTokenNSPrefix('Start_Date__c'),
            UTIL_Describe.StrTokenNSPrefix('Status__c')
        };

        // Get the additional fields from the FieldSet
        for (Schema.FieldSetMember f : SObjectType.Volunteer_Hours__c.FieldSets.VolunteersReportHoursFS.getFields()) {
            if (vhours.get(f.getFieldPath()) != null) {
                flsCheckFields.add(f.getFieldPath());
            }
        }

        access.checkUpdateAccess(UTIL_Describe.StrTokenNSPrefix('Volunteer_Hours__c'), flsCheckFields);
    }

    // this was a testmethod which can't be compiled in this class under api 31.
    // but because it was marked global, it could not be completely removed.
    @SuppressWarnings('PMD.EmptyStatementBlock')
    global static void codeCoverageTests() {
    }
}