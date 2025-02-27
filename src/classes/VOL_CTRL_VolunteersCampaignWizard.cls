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
 * @date 11/17/2011
 * @description Page Controller class for the Volunteers Wizard visualforce page.
 ********************************************************************************************************/
public with sharing class VOL_CTRL_VolunteersCampaignWizard {
    private static final String LAST_VIEWED_DATE = 'LastViewedDate';
    private static final String LAST_REFERENCED_DATE = 'LastReferencedDate';

    // the new campaign we will create
    public Campaign cmpVols {
        get {
            if (cmpVols == null) {
                cmpVols = new Campaign(RecordTypeId = VOL_SharedCode.recordtypeIdVolunteersCampaign);
            }
            return cmpVols;
        }
        set;
    }

    // a temporary campaign to use for *locale* date fields on the visualforce page.
    public Campaign cmpShiftDates {
        get {
            if (cmpShiftDates == null) {
                cmpShiftDates = new Campaign();
            }
            return cmpShiftDates;
        }
        set;
    }

    // a temporary Volunteer Hours to use for status field on the visualforce page.
    public Volunteer_Hours__c hoursStatus {
        get {
            if (hoursStatus == null) {
                hoursStatus = new Volunteer_Hours__c();
            }
            return hoursStatus;
        }
        set;
    }

    public Id campaignIdClone { get; set; }
    public Integer cSampleJobs { get; set; }
    public Integer cSampleShifts { get; set; }
    public Boolean fCopyVolunteers { get; set; }

    private VOL_SharedCode volSharedCode;

    // the list of Campaigns to put in the clone existing campaign dropdown
    public List<SelectOption> listSOVolunteersCampaigns { get; set; }

    // constructor
    public VOL_CTRL_VolunteersCampaignWizard() {
        volSharedCode = new VOL_SharedCode();
        listSOVolunteersCampaigns = volSharedCode.listSOCampaignsWithJobs;
        fCopyVolunteers = false;
    }

    /*******************************************************************************************************
     * @description Action Method to Save changes in the Volunteers Wizard.  This will cause it to create
     * a new campaign, and either populate it with sample jobs and shifts, or clone jobs, shifts, and
     * volunteers from an existing Volunteers campaign.
     * @return PageReference campaign's page if success, null if errors
     ********************************************************************************************************/
    public PageReference save() {
        // validation
        if (campaignIdClone != null && (cSampleJobs > 0 || cSampleShifts > 0)) {
            ApexPages.addMessage(
                new ApexPages.Message(ApexPages.Severity.ERROR, Label.labelVolunteersWizardErrorExistingOrSample)
            );
            return null;
        }

        // more validation
        if (campaignIdClone == null && cSampleShifts > 0 && cSampleJobs == 0) {
            ApexPages.addMessage(
                new ApexPages.Message(ApexPages.Severity.ERROR, Label.labelVolunteersWizardErrorNoJobsWithShifts)
            );
            return null;
        }

        Savepoint sp = Database.setSavepoint();

        try {
            // Ensure the user can create the object
            UTIL_Describe.checkObjectCreateAccess('Campaign');
            SObjectAccessDecision campaignAccessDecision = Security.stripInaccessible(
                AccessType.CREATABLE,
                new List<Campaign>{ cmpVols }
            );
            cmpVols = (Campaign) campaignAccessDecision.getRecords()[0];
            // Using strip inaccessible in the method called above.
            /* sfge-disable-next-line ApexFlsViolationRule */
            insert cmpVols;

            if (campaignIdClone != null) {
                CloneExistingJobsAndShifts();
            } else if (cSampleJobs > 0) {
                CreateSampleJobsAndShifts();
            }

            // go to the campaign's detail page
            PageReference p = new PageReference('/' + cmpVols.Id);
            p.setRedirect(true);
            return p;
        } catch (Exception e) {
            Database.rollback(sp);
            ApexPages.addMessages(e);
            return null;
        }
    }

    /*******************************************************************************************************
     * @description method to create sample jobs and shifts on the new Volunteers campaign.
     ********************************************************************************************************/
    private void createSampleJobsAndShifts() {
        List<Volunteer_Job__c> listJobs = new List<Volunteer_Job__c>();
        List<Volunteer_Shift__c> listShifts = new List<Volunteer_Shift__c>();

        // create the sample jobs
        for (Integer iJob = 0; iJob < cSampleJobs; iJob++) {
            Volunteer_Job__c job = new Volunteer_Job__c();
            job.Campaign__c = cmpVols.Id;
            job.Name = Label.labelVolunteersWizardSampleJobName + (iJob + 1);
            listJobs.add(job);
        }

        // Ensure the user has access to create the object and fields
        UTIL_Describe.checkCreateAccess(
            UTIL_Describe.StrTokenNSPrefix('Volunteer_Job__c'),
            new Set<String>{ 'Name', UTIL_Describe.StrTokenNSPrefix('Campaign__c') }
        );
        // Using a dynamic describe access check in the method called above.
        /* sfge-disable-next-line ApexFlsViolationRule */
        insert listJobs;

        UTIL_Describe.checkCreateAccess(
            UTIL_Describe.StrTokenNSPrefix('Volunteer_Shift__c'),
            new Set<String>{
                UTIL_Describe.StrTokenNSPrefix('Volunteer_Job__c'),
                UTIL_Describe.StrTokenNSPrefix('Start_Date_Time__c'),
                UTIL_Describe.StrTokenNSPrefix('Duration__c'),
                UTIL_Describe.StrTokenNSPrefix('Description__c')
            }
        );
        // create the sample shifts
        for (Integer iJob = 0; iJob < cSampleJobs; iJob++) {
            for (Integer iShift = 0; iShift < cSampleShifts; iShift++) {
                Volunteer_Shift__c shift = new Volunteer_Shift__c();
                shift.Volunteer_Job__c = listJobs[iJob].Id;
                if (cmpVols.StartDate == null) {
                    cmpVols.StartDate = System.today();
                }
                shift.Start_Date_Time__c = DateTime.newInstance(
                    cmpVols.StartDate.year(),
                    cmpVols.StartDate.month(),
                    cmpVols.StartDate.day(),
                    iShift + 8,
                    0,
                    0
                );
                shift.Duration__c = 1;
                shift.Description__c = Label.labelVolunteersWizardSampleShiftName + (iShift + 1);
                listShifts.add(shift);
            }
        }
        // Using a dynamic describe access check in the method called above.
        /* sfge-disable-next-line ApexFlsViolationRule */
        insert listShifts;
    }

    /*******************************************************************************************************
     * @description method to clone existing jobs, shifts, and optionally Volunteer Hours onto
     * the new Volunteers campaign.
     ********************************************************************************************************/
    private void cloneExistingJobsAndShifts() {
        List<Volunteer_Job__c> listJobsExisting = getExistingJobs(campaignIdClone);
        List<Volunteer_Shift__c> listShiftsExisting = getExistingShifts(listJobsExisting);
        List<Volunteer_Job__c> listJobs = cloneJobs(listJobsExisting);

        // create a map of existing JobId to new JobId
        Map<Id, Id> mapJobId = new Map<Id, Id>();
        for (Integer i = 0; i < listJobsExisting.size(); i++) {
            mapJobId.put(listJobsExisting[i].Id, listJobs[i].Id);
        }

        // figure out our base date to use.
        Date dt = cmpShiftDates.EndDate;
        if (dt == null) {
            dt = cmpVols.StartDate;
        }
        if (dt == null) {
            dt = System.Now().date();
        }
        // figure out date offset
        Integer cDays;
        if (cmpShiftDates.StartDate == null) {
            cDays = -1; // don't offset, use fixed dt.
        } else {
            cDays = cmpShiftDates.StartDate.daysBetween(dt);
        }

        // clone the Shifts
        List<Volunteer_Shift__c> listShifts = cloneShifts(
            mapJobId,
            listJobsExisting,
            listJobs,
            listShiftsExisting,
            dt,
            cDays
        );

        if (fCopyVolunteers) {
            List<Volunteer_Hours__c> listHours = cloneHours(mapJobId, listJobsExisting, listShiftsExisting, listShifts);
        }
    }

    /*******************************************************************************************************
     * @description holds all the Fields on Volunteer Job
     ********************************************************************************************************/
    private List<String> listStrFieldsJob {
        get {
            if (listStrFieldsJob == null) {
                listStrFieldsJob = new List<String>();
                Map<String, Schema.SObjectField> mapS = Schema.SObjectType.Volunteer_Job__c.fields.getMap();
                listStrFieldsJob.addAll(mapS.keySet());
            }
            return listStrFieldsJob;
        }
        set;
    }

    /*******************************************************************************************************
     * @description holds all the Fields on Volunteer Shift
     ********************************************************************************************************/
    private List<String> listStrFieldsShift {
        get {
            if (listStrFieldsShift == null) {
                listStrFieldsShift = new List<String>();
                Map<String, Schema.SObjectField> mapS = Schema.SObjectType.Volunteer_Shift__c.fields.getMap();
                Set<String> fieldNames = removeTabSpecificFields(mapS.keySet());
                listStrFieldsShift.addAll(fieldNames);
            }
            return listStrFieldsShift;
        }
        set;
    }

    /*******************************************************************************************************
     * @description holds all the Fields on Volunteer Hours
     ********************************************************************************************************/
    private List<String> listStrFieldsHours {
        get {
            if (listStrFieldsHours == null) {
                listStrFieldsHours = new List<String>();
                Map<String, Schema.SObjectField> mapS = Schema.SObjectType.Volunteer_Hours__c.fields.getMap();
                Set<String> fieldNames = removeTabSpecificFields(mapS.keySet());
                listStrFieldsHours.addAll(fieldNames);
            }
            return listStrFieldsHours;
        }
        set;
    }

    /*******************************************************************************************************
     * @description removes fields that only exist when a tab for the object has been created
     * https://help.salesforce.com/s/articleView?id=000315500&type=1
     * @param Set<String> Set of fields that might contain the fields to be returned.
     */
    private Set<String> removeTabSpecificFields(Set<String> fieldNames) {
        fieldNames.removeAll(new Set<String>{ LAST_REFERENCED_DATE.toLowerCase(), LAST_VIEWED_DATE.toLowerCase() });
        return fieldNames;
    }

    /*******************************************************************************************************
     * @description queries for all of the Volunteer Jobs for the specified Campaign
     * @param campaignId the Id of the Campaign
     * @return List<Volunteer_Job__c> the list of Jobs for the campaign
     ********************************************************************************************************/
    private List<Volunteer_Job__c> getExistingJobs(Id campaignId) {
        // Ensure the user has access to the object and fields before querying
        UTIL_Describe.checkReadAccess(
            UTIL_Describe.StrTokenNSPrefix('Volunteer_Job__c'),
            new Set<String>(listStrFieldsJob)
        );

        // find the existing jobs
        // we need to use dynamic soql to pick up all custom fields we don't know about
        String strSoql = 'SELECT ';
        String strComma = '';
        for (String strF : listStrFieldsJob) {
            strSoql += strComma + strF;
            strComma = ', ';
        }
        strSoql += ' from Volunteer_Job__c where Campaign__c = :campaignId order by CreatedDate';
        return Database.query(strSoql);
    }

    /*******************************************************************************************************
     * @description queries for all of the Volunteer Shifts for the specified Jobs
     * @param listJobsExisting the list of Jobs to get Shifts for
     * @return List<Volunteer_Shift__c> the list of Shifts
     ********************************************************************************************************/
    private List<Volunteer_Shift__c> getExistingShifts(List<Volunteer_Job__c> listJobsExisting) {
        // Ensure the user has access to the object and fields before querying
        UTIL_Describe.checkReadAccess(
            UTIL_Describe.StrTokenNSPrefix('Volunteer_Shift__c'),
            new Set<String>(listStrFieldsShift)
        );

        // find the existing shifts for those jobs
        // we need to use dynamic soql to pick up all custom fields we don't know about
        String strSoql = 'SELECT ';
        String strComma = '';
        for (String strF : listStrFieldsShift) {
            strSoql += strComma + strF;
            strComma = ', ';
        }
        strSoql += ' from Volunteer_Shift__c where Volunteer_Job__c in :listJobsExisting order by Start_Date_Time__c';
        return Database.query(strSoql);
    }

    /*******************************************************************************************************
     * @description queries for all of the Volunteer Hours for the specified Jobs and Shifts
     * @param listJobsExisting the list of Jobs
     * @param listShiftsExisting the list of Shifts
     * @return List<Volunteer_Hours__c> the list of Hours for these Jobs and Shifts
     ********************************************************************************************************/
    private List<Volunteer_Hours__c> getExistingHours(
        List<Volunteer_Job__c> listJobsExisting,
        List<Volunteer_Shift__c> listShiftsExisting
    ) {
        // Ensure the user has access to the object and fields before querying
        UTIL_Describe.checkReadAccess(
            UTIL_Describe.StrTokenNSPrefix('Volunteer_Hours__c'),
            new Set<String>(listStrFieldsHours)
        );

        // find the existing hours for those jobs and shifts
        // we need to use dynamic soql to pick up all custom fields we don't know about
        String strSoql = 'SELECT ';
        String strComma = '';
        for (String strF : listStrFieldsHours) {
            strSoql += strComma + strF;
            strComma = ', ';
        }
        strSoql += ' from Volunteer_Hours__c where Volunteer_Job__c in :listJobsExisting ';
        strSoql += ' or Volunteer_Shift__c in :listShiftsExisting ';
        return Database.query(strSoql);
    }

    /*******************************************************************************************************
     * @description copies the provided Jobs to a new list of Jobs and inserts them into the db
     * @param listJobsExisting the list of Jobs to clone
     * @return List<Volunteer_Job__c> the new list of Jobs
     ********************************************************************************************************/
    private List<Volunteer_Job__c> cloneJobs(List<Volunteer_Job__c> listJobsExisting) {
        List<Volunteer_Job__c> listJobs = new List<Volunteer_Job__c>();
        // clone the jobs
        for (Volunteer_Job__c job : listJobsExisting) {
            Volunteer_Job__c jobNew = new Volunteer_Job__c();

            //  now copy over all the non-null fields
            for (String strF : listStrFieldsJob) {
                if (strF != 'Id' && job.get(strF) != null) {
                    try {
                        jobNew.put(strF, job.get(strF));
                    } catch (exception ex) {
                        // catch errors from readonly fields, and continue.
                    }
                }
            }
            jobNew.Campaign__c = cmpVols.Id;
            listJobs.add(jobNew);
        }
        // Ensure the user has access to the object and fields before saving
        UTIL_Describe.checkObjectCreateAccess(UTIL_Describe.StrTokenNSPrefix('Volunteer_Job__c'));
        SObjectAccessDecision jobsAccessDecision = Security.stripInaccessible(AccessType.CREATABLE, listJobs);
        listJobs = (List<Volunteer_Job__c>) jobsAccessDecision.getRecords();
        insert listJobs;
        return listJobs;
    }

    /*******************************************************************************************************
     * @description copies the provided Shifts to a new list of Shifts and inserts them into the db
     * @param mapJobId a map of Existing Job Id to new Job Id
     * @param listJobExisting the list of Jobs to clone
     * @param listJobs the new list of Jobs
     * @param listShiftsExisting the list of Shifts to clone
     * @param dt the date to start the first Shift on
     * @param cDaysOffset the number of days to offset it by
     * @return List<Volunteer_Shift__c> the new list of Shifts
     ********************************************************************************************************/
    private List<Volunteer_Shift__c> cloneShifts( //NOPMD
        Map<Id, Id> mapJobId,
        List<Volunteer_Job__c> listJobsExisting,
        List<Volunteer_Job__c> listJobs,
        List<Volunteer_Shift__c> listShiftsExisting,
        Date dt,
        Integer cDaysOffset
    ) {
        List<Volunteer_Shift__c> listShifts = new List<Volunteer_Shift__c>();

        // clone the shifts
        for (Volunteer_Shift__c shift : listShiftsExisting) {
            Volunteer_Shift__c shiftNew = new Volunteer_Shift__c();

            //  now copy over all the non-null fields
            for (String strF : listStrFieldsShift) {
                if (strF != 'Id' && shift.get(strF) != null) {
                    try {
                        shiftNew.put(strF, shift.get(strF));
                    } catch (exception ex) {
                        // catch errors from readonly fields, and continue.
                    }
                }
            }

            shiftNew.Volunteer_Job__c = mapJobId.get(shift.Volunteer_Job__c);

            // just use the time, not the date, from the existing shift.
            Time tm = shift.Start_Date_Time__c.time();

            if (cDaysOffset > -1) {
                dt = shift.Start_Date_Time__c.addDays(cDaysOffset).date();
            }
            shiftNew.Start_Date_Time__c = DateTime.newInstance(dt, tm);

            // clear the volunteer count
            shiftNew.Total_Volunteers__c = 0;

            listShifts.add(shiftNew);
        }

        // Ensure the user has access to the object and fields before saving
        UTIL_Describe.checkObjectCreateAccess(UTIL_Describe.StrTokenNSPrefix('Volunteer_Shift__c'));
        SObjectAccessDecision shiftsAccessDecision = Security.stripInaccessible(AccessType.CREATABLE, listShifts);
        listShifts = (List<Volunteer_Shift__c>) shiftsAccessDecision.getRecords();
        insert listShifts;
        return listShifts;
    }

    /*******************************************************************************************************
     * @description copies the provided Hours to a new list of Hours and inserts them into the db
     * @param mapJobId a map of Existing Job Id to new Job Id
     * @param listJobExisting the list of Jobs to clone
     * @param listShiftsExisting the list of Shifts to clone
     * @param listShifts the new list of Shifts
     * @return List<Volunteer_Hours__c> the new list of Hours
     ********************************************************************************************************/
    private List<Volunteer_Hours__c> cloneHours( //NOPMD
        Map<Id, Id> mapJobId,
        List<Volunteer_Job__c> listJobsExisting,
        List<Volunteer_Shift__c> listShiftsExisting,
        List<Volunteer_Shift__c> listShifts
    ) {
        List<Volunteer_Hours__c> listHoursExisting = getExistingHours(listJobsExisting, listShiftsExisting);

        // create a map of existing ShiftId to new ShiftId
        Map<Id, Id> mapShiftId = new Map<Id, Id>();
        for (Integer i = 0; i < listShiftsExisting.size(); i++) {
            mapShiftId.put(listShiftsExisting[i].Id, listShifts[i].Id);
        }

        // create a map of new ShiftId to new Shift (so we can get dates)
        Map<Id, Volunteer_Shift__c> mapIdToShift = new Map<Id, Volunteer_Shift__c>();
        for (Volunteer_Shift__c shift : listShifts) {
            mapIdToShift.put(shift.Id, shift);
        }

        List<Volunteer_Hours__c> listHours = new List<Volunteer_Hours__c>();

        // clone the hours
        for (Volunteer_Hours__c hours : listHoursExisting) {
            Volunteer_Hours__c hoursNew = new Volunteer_Hours__c();

            //  now copy over all the non-null fields
            for (String strF : listStrFieldsHours) {
                if (strF != 'Id' && hours.get(strF) != null) {
                    try {
                        hoursNew.put(strF, hours.get(strF));
                    } catch (exception ex) {
                        // catch errors from readonly fields, and continue.
                    }
                }
            }

            hoursNew.Volunteer_Job__c = mapJobId.get(hours.Volunteer_Job__c);
            hoursNew.Volunteer_Shift__c = mapShiftId.get(hours.Volunteer_Shift__c);

            // override hours status
            if (hoursStatus.Status__c != null) {
                hoursNew.Status__c = hoursStatus.Status__c;
            }

            // override start date and end date
            if (hoursNew.Volunteer_Shift__c != null) {
                Date dtNew = mapIdToShift.get(hoursNew.Volunteer_Shift__c).Start_Date_Time__c.date();
                hoursNew.Start_Date__c = dtNew;
                hoursNew.End_Date__c = dtNew;
                // fixup Planned_Start_Date_Time__c
                if (hours.Planned_Start_Date_Time__c != null) {
                    Time tm = hours.Planned_Start_Date_Time__c.time();
                    hoursNew.Planned_Start_Date_Time__c = DateTime.newInstance(dtNew, tm);
                }
            } else {
                hoursNew.Start_Date__c = cmpVols.StartDate;
                hoursNew.End_Date__c = null;
            }

            listHours.add(hoursNew);
        }

        // Ensure the user has access to the object and fields before saving
        UTIL_Describe.checkObjectCreateAccess(UTIL_Describe.StrTokenNSPrefix('Volunteer_Hours__c'));
        SObjectAccessDecision hoursAccessDecision = Security.stripInaccessible(AccessType.CREATABLE, listHours);
        listHours = (List<Volunteer_Hours__c>) hoursAccessDecision.getRecords();
        insert listHours;
        return listHours;
    }

    /*******************************************************************************************************
     * @description action method called whenever the existing campaign dropdown changes.  Queries the
     * campaign to find its earliest job shift.
     * @return PageReference always null, so the page redisplays
     ********************************************************************************************************/
    public PageReference changeCampaign() {
        try {
            cSampleJobs = 0;
            cSampleShifts = 0;

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
            List<Volunteer_Job__c> listJobs = [
                SELECT Id, First_Shift__c
                FROM Volunteer_Job__c
                WHERE Campaign__c = :campaignIdClone
                ORDER BY First_Shift__c
            ];

            cmpShiftDates.StartDate = null;

            // find the earliest shift (if there is one)
            for (Volunteer_Job__c job : listJobs) {
                if (job.First_Shift__c != null) {
                    // will give date in locale time zone of current SF user.
                    cmpShiftDates.StartDate = job.First_Shift__c.date();
                    return null;
                }
            }
            return null;
        } catch (Exception e) {
            ApexPages.addMessages(e);
            return null;
        }
    }
}