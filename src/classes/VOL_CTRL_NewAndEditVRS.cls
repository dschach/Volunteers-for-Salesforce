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
 * @date 12/1/2012
 * @description controller class for the New and Update Volunteer Recurrence Schedules visualforce page.
 ********************************************************************************************************/
public with sharing class VOL_CTRL_NewAndEditVRS {
    public Volunteer_Recurrence_Schedule__c vrs { get; set; }
    public Id jrsId { get; set; }

    //constructor
    public VOL_CTRL_NewAndEditVRS(ApexPages.StandardController controller) {
        //get record from standard controller
        vrs = (Volunteer_Recurrence_Schedule__c) controller.getRecord();
    }

    // the list of Job Recurrence Schedules for the current job
    public List<SelectOption> listSOJRS {
        get {
            if (listSOJRS == null) {
                List<SelectOption> listSO = new List<SelectOption>();
                listSO.add(new SelectOption('', ''));
                Id jobId = vrs.Volunteer_Job__c;

                for (Job_Recurrence_Schedule__c jrs : [
                    SELECT
                        Id,
                        Name,
                        Days_of_Week__c,
                        Duration__c,
                        Schedule_Start_Date_Time__c,
                        Schedule_End_Date__c,
                        Weekly_Occurrence__c
                    FROM Job_Recurrence_Schedule__c
                    WHERE Volunteer_Job__c = :jobId AND (Schedule_End_Date__c = NULL OR Schedule_End_Date__c >= TODAY)
                    LIMIT 999
                ]) {
                    SelectOption so = new SelectOption(
                        jrs.id,
                        jrs.Weekly_Occurrence__c +
                            ' ' +
                            jrs.Days_of_Week__c +
                            ' ' +
                            jrs.Schedule_Start_Date_Time__c.format() +
                            '&nbsp;&nbsp;&nbsp;&nbsp;(' +
                            jrs.name +
                            ')'
                    );
                    so.setEscapeItem(false);
                    listSO.add(so);
                }
                listSOJRS = listSO;
            }
            return listSOJRS;
        }
        set;
    }

    public String getVJFieldName() {
        return VOL_SharedCode.StrTokenNSPrefix('Volunteer_Job__c');
    }

    // action method called by the page when the Job has changed.
    // this allows us to refresh the lsit of JRS's for the new job.
    public PageReference refreshListSOJRS() {
        listSOJRS = null;
        return null;
    }

    // action method called by the page when the user chooses a JRS to copy from.
    public PageReference copyScheduleFromJRS() {
        try {
            if (jrsId != null) {
                // Ensure the user has access to the object and fields before querying
                UTIL_Describe.checkReadAccess(
                    UTIL_Describe.StrTokenNSPrefix('Job_Recurrence_Schedule__c'),
                    new Set<String>{
                        UTIL_Describe.StrTokenNSPrefix('Days_of_Week__c'),
                        UTIL_Describe.StrTokenNSPrefix('Duration__c'),
                        UTIL_Describe.StrTokenNSPrefix('Schedule_Start_Date_Time__c'),
                        UTIL_Describe.StrTokenNSPrefix('Schedule_End_Date__c'),
                        UTIL_Describe.StrTokenNSPrefix('Weekly_Occurrence__c')
                    }
                );

                Job_Recurrence_Schedule__c jrs = [
                    SELECT
                        Days_of_Week__c,
                        Duration__c,
                        Schedule_Start_Date_Time__c,
                        Schedule_End_Date__c,
                        Weekly_Occurrence__c
                    FROM Job_Recurrence_Schedule__c
                    WHERE Id = :jrsId
                ];

                // copy appropriate values
                vrs.Days_of_Week__c = jrs.Days_of_Week__c;
                vrs.Duration__c = jrs.Duration__c;
                DateTime dt = jrs.Schedule_Start_Date_Time__c;
                if (dt < System.now()) {
                    dt = datetime.newInstance(System.today(), jrs.Schedule_Start_Date_Time__c.time());
                }
                vrs.Schedule_Start_Date_Time__c = dt;
                vrs.Schedule_End_Date__c = jrs.Schedule_End_Date__c;
                vrs.Weekly_Occurrence__c = jrs.Weekly_Occurrence__c;
            }
            return null;
        } catch (Exception e) {
            ApexPages.addMessages(e);
            return null;
        }
    }
}