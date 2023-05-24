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

public with sharing class VOL_CTRL_VolunteersFind extends PageControllerBase {
    // constructor
    public VOL_CTRL_VolunteersFind() {
        // setup properties SoqlListView needs
        strFields = listStrFields;
        strNameField = 'Name';
        strObjectType = 'Contact';

        // setup the Assign panel
        volSharedCode = new VOL_SharedCode();
        listSOCampaigns = volSharedCode.listSOCampaignsWithJobs;

        // handle optional parameters (must use String, not Id, to handle null)
        String strId = ApexPages.currentPage().getParameters().get('campaignId');
        if (strId != null && strId != '') {
            campaignId = strId;
        }
        strId = ApexPages.currentPage().getParameters().get('volunteerJobId');
        if (strId != null && strId != '') {
            volunteerJobId = strId;
        }
        strId = ApexPages.currentPage().getParameters().get('volunteerShiftId');
        if (strId != null && strId != '') {
            volunteerShiftId = strId;
        }
    }

    // the SoqlListView component calls this method to get the query string.
    public override String getStrSoql() {
        // let's see if we can find any matching Contacts.
        // we need to use dynamic soql, since we allow the user to modify the FieldSet of fields to edit.
        String strSoql = 'SELECT ';
        String strComma = '';
        for (String strF : listStrFields) {
            strSoql += strComma + strF;
            strComma = ', ';
        }
        strSoql += ' FROM Contact WHERE ';

        // only load contacts once we have some criteria
        // force empty result set.
        if (!hasFilterCriteria) {
            strSoql += ' Id = null ';
            return strSoql;
        }

        // criteria section driven by a fieldset
        Boolean fAndNeeded = false;
        for (Schema.FieldSetMember f : SObjectType.Contact.FieldSets.VolunteersFindCriteriaFS.getFields()) {
            String strVal = String.valueOf(conFilter.get(f.getFieldPath()));
            if (strVal != null && strVal != '') {
                if (f.getType() == Schema.DisplayType.multipicklist) {
                    if (fAndNeeded) {
                        strSoql += ' and ';
                    }
                    strSoql += f.getFieldPath() + ' includes (';
                    for (String str : strVal.split(';')) {
                        strSoql += '\'' + str + '\',';
                    }
                    strSoql = strSoql.removeEnd(',');
                    strSoql += ') ';
                    fAndNeeded = true;
                } else if (f.getType() == Schema.DisplayType.Boolean) {
                    if (strVal == 'true') {
                        if (fAndNeeded) {
                            strSoql += ' and ';
                        }
                        strSoql += f.getFieldPath() + ' = true ';
                        fAndNeeded = true;
                    }
                } else {
                    if (fAndNeeded) {
                        strSoql += ' and ';
                    }
                    strSoql += f.getFieldPath() + ' = \'' + strVal + '\' ';
                    fAndNeeded = true;
                }
            }
        }

        if (ctrlSoqlListView.strAlphaFilter != null) {
            if (fAndNeeded) {
                strSoql += ' and ';
            }
            strSoql += ' Name like \'' + ctrlSoqlListView.strAlphaFilter + '%\'';
        }

        // sorting handled by SoqlListView;
        //ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, strSoql));
        //System.debug('strSoql is: ' + strSoql);

        return strSoql;
    }

    public override PageReference newItem() {
        return null;
    }

    public override PageReference editItem(Id idItem) {
        return null;
    }

    // the list of fieldnames on the Contact to load
    public List<String> listStrFields {
        get {
            if (listStrFields == null) {
                listStrFields = new List<String>();
                for (Schema.FieldSetMember f : SObjectType.Contact.FieldSets.VolunteersFindFS.getFields()) {
                    listStrFields.add(f.getFieldPath());
                }
            }
            return listStrFields;
        }
        set;
    }

    // a temporary contact to use for filtering on contact fields.
    public Contact conFilter {
        get {
            if (conFilter == null) {
                conFilter = new Contact();
            }
            return conFilter;
        }
        set;
    }

    // force a requery of the contacts
    public PageReference find() {
        ctrlSoqlListView.setCon = null;
        ctrlSoqlListView.listSLVObj = null;
        return null;
    }

    // helper to test whether filter criteria have been specified
    public Boolean hasFilterCriteria {
        get {
            for (Schema.FieldSetMember f : SObjectType.Contact.FieldSets.VolunteersFindCriteriaFS.getFields()) {
                String strVal = String.valueOf(conFilter.get(f.getFieldPath()));
                if (strVal != null && strVal != '') {
                    if (f.getType() != Schema.DisplayType.Boolean || strVal == 'true') {
                        return true;
                    }
                }
            }
            return false;
        }
    }

    //------------------------------------------------------------------------------------------
    // the following code is to support the Assign section of the page.
    //------------------------------------------------------------------------------------------

    private VOL_SharedCode volSharedCode;

    // holds the currently selected Campaign in the Campaign dropdown
    public Id campaignId { get; set; }

    // the list of Campaigns to put in the Campaign dropdown
    public List<SelectOption> listSOCampaigns { get; set; }

    // the user has changed the Campaign dropdown
    public PageReference changeCampaign() {
        // clear out all state that is specific to the campaign
        listSOVolunteerJobs = null;
        volunteerJobId = null;
        ChangeVolunteerJob();
        return null;
    }

    // holds the currently select Job in the Job dropdown
    public Id volunteerJobId { get; set; }

    // the list of Volunteer Jobs to put in the dropdown
    public List<SelectOption> listSOVolunteerJobs {
        get {
            if (listSOVolunteerJobs == null && campaignId != null) {
                listSOVolunteerJobs = volSharedCode.listSOVolunteerJobsOfCampaignId(campaignId);
            }
            return listSOVolunteerJobs;
        }
        set;
    }

    // the user has changed the Volunteer Job dropdown
    public PageReference changeVolunteerJob() {
        // clear out all state that is specific to the Job
        listSOVolunteerShifts = null;
        volunteerShiftId = null;
        return null;
    }

    // holds the currently select Job Shift in the Job Shift dropdown
    public Id volunteerShiftId { get; set; }

    // the list of Volunteer Shifts to put in the dropdown
    public List<SelectOption> listSOVolunteerShifts {
        get {
            if (listSOVolunteerShifts == null && volunteerJobId != null) {
                listSOVolunteerShifts = volSharedCode.listSOVolunteerShiftsOfVolunteerJobId(
                    volunteerJobId,
                    System.today(),
                    System.today().addyears(2),
                    false,
                    true
                );
            }
            return listSOVolunteerShifts;
        }
        set;
    }

    // temp hours to hold Status field picklist & Hours Worked field
    public Volunteer_Hours__c vhAssign {
        get {
            if (vhAssign == null) {
                vhAssign = new Volunteer_Hours__c();
            }
            return vhAssign;
        }
        set;
    }

    // actionmethod to Assign the checked volunteers to the current Job/Shift
    public PageReference assign() {
        try {
            // because we need to use actionSupport immediate=false to support the combo's,
            // we couldn't actually use visualforce's required=true property on fields.
            // so we must manually enforce the fields we want required ourselves.
            Boolean hasErrors = false;

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

            if (vhAssign.Status__c == null) {
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.Severity.FATAL,
                        String.Format(
                            System.Label.labelVolunteerReportHoursErrorRequiredField,
                            new List<String>{ Schema.sObjectType.Volunteer_Hours__c.fields.Status__c.getLabel() }
                        )
                    )
                );
                hasErrors = true;
            }

            // now bail out if any required fields are missing.
            if (hasErrors) {
                return null;
            }

            // if shift specified, get its start date
            Date dtStart = System.today();
            if (volunteerShiftId != null) {
                // Ensure the user has access to the object and fields before querying
                UTIL_Describe.checkReadAccess(
                    UTIL_Describe.StrTokenNSPrefix('Volunteer_Shift__c'),
                    new Set<String>{ 'Id', UTIL_Describe.StrTokenNSPrefix('Start_Date_Time__c') }
                );
                // Using a dynamic describe access check in the method called above.
                /* sfge-disable-next-line ApexFlsViolationRule */
                Volunteer_Shift__c vs = [
                    SELECT Start_Date_Time__c
                    FROM Volunteer_Shift__c
                    WHERE Id = :volunteerShiftId
                ];
                dtStart = date.valueOf(vs.Start_Date_Time__c);
            }

            // find out which contacts are already assigned to the job/shift
            List<Volunteer_Hours__c> listVHExisting;
            if (volunteerShiftId == null) {
                // Ensure the user has access to the object and fields before querying
                UTIL_Describe.checkReadAccess(
                    UTIL_Describe.StrTokenNSPrefix('Volunteer_Hours__c'),
                    new Set<String>{
                        UTIL_Describe.StrTokenNSPrefix('Contact__c'),
                        UTIL_Describe.StrTokenNSPrefix('Volunteer_Job__c')
                    }
                );
                // Using a dynamic describe access check in the method called above.
                /* sfge-disable-next-line ApexFlsViolationRule */
                listVHExisting = [SELECT Contact__c FROM Volunteer_Hours__c WHERE Volunteer_Job__c = :volunteerJobId];
            } else {
                // Ensure the user has access to the object and fields before querying
                UTIL_Describe.checkReadAccess(
                    UTIL_Describe.StrTokenNSPrefix('Volunteer_Hours__c'),
                    new Set<String>{
                        UTIL_Describe.StrTokenNSPrefix('Contact__c'),
                        UTIL_Describe.StrTokenNSPrefix('Volunteer_Shift__c')
                    }
                );
                // Using a dynamic describe access check in the method called above.
                /* sfge-disable-next-line ApexFlsViolationRule */
                listVHExisting = [
                    SELECT Contact__c
                    FROM Volunteer_Hours__c
                    WHERE Volunteer_Shift__c = :volunteerShiftId
                ];
            }
            Set<Id> setContactId = new Set<Id>();
            for (Volunteer_Hours__c vh : listVHExisting) {
                setContactId.add(vh.Contact__c);
            }
            Integer cContactAlreadyAssigned = 0;

            List<Volunteer_Hours__c> listHours = new List<Volunteer_Hours__c>();
            for (SoqlListView.SLVObj obj : ctrlSoqlListView.listSLVObjCurrent) {
                if (obj.checked) {
                    // avoid contacts already assigned to this job/shift
                    if (setContactId.contains(obj.sobj.Id)) {
                        cContactAlreadyAssigned++;
                        continue;
                    }

                    Volunteer_Hours__c vh = new Volunteer_Hours__c();
                    vh.Contact__c = obj.sobj.Id;
                    vh.Volunteer_Job__c = volunteerJobId;
                    vh.Volunteer_Shift__c = volunteerShiftId;
                    vh.Start_Date__c = dtStart;
                    vh.Status__c = vhAssign.Status__c;
                    vh.Hours_Worked__c = vhAssign.Hours_Worked__c;
                    vh.Number_of_Volunteers__c = 1;
                    listHours.add(vh);
                }
            }

            // Ensure the user has access to the object and fields before querying
            UTIL_Describe.checkCreateAccess(
                UTIL_Describe.StrTokenNSPrefix('Volunteer_Hours__c'),
                new Set<String>{
                    UTIL_Describe.StrTokenNSPrefix('Contact__c'),
                    UTIL_Describe.StrTokenNSPrefix('Volunteer_Job__c'),
                    UTIL_Describe.StrTokenNSPrefix('Volunteer_Shift__c'),
                    UTIL_Describe.StrTokenNSPrefix('Start_Date__c'),
                    UTIL_Describe.StrTokenNSPrefix('Status__c'),
                    UTIL_Describe.StrTokenNSPrefix('Hours_Worked__c'),
                    UTIL_Describe.StrTokenNSPrefix('Number_of_Volunteers__c')
                }
            );
            // Using a dynamic describe access check in the method called above.
            /* sfge-disable-next-line ApexFlsViolationRule */
            insert listHours;

            // if shift was specified, force its picklist to update with new numbers
            if (volunteerShiftId != null) {
                listSOVolunteerShifts = null;
            }

            String str = String.Format(
                System.Label.labelFindVolunteersNewlyAssigned,
                new List<String>{ String.valueOf(listHours.size()) }
            );
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, str));
            if (cContactAlreadyAssigned > 0) {
                str = String.Format(
                    System.Label.labelFindVolunteersAlreadyAssigned,
                    new List<String>{ String.valueOf(cContactAlreadyAssigned) }
                );
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, str));
            }
        } catch (exception ex) {
            String str = ex.getMessage();
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.FATAL, str));
        }
        return null;
    }
}