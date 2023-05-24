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

@IsTest
private with sharing class VOL_CTRL_VolunteersFind_TEST {
    //------------------------------------------------------------------------------------------
    // Test Code
    //------------------------------------------------------------------------------------------
    @IsTest
    private static void testVolunteersFind() {
        // create test data
        List<Contact> listCon = new List<Contact>();
        for (Integer i = 0; i < 10; i++) {
            listCon.add(new Contact(firstname = 'test' + i, lastname = 'test' + i));
            if (i == 1 || i == 3 || i == 5) {
                listCon[i].Volunteer_Status__c = 'Active';
            }
            if (i == 3) {
                listCon[i].Volunteer_Availability__c = 'Morning';
            }
        }
        insert listCon;

        Campaign cmp = new Campaign(
            recordtypeid = VOL_SharedCode.recordtypeIdVolunteersCampaign,
            name = 'Job Test Campaign',
            IsActive = true
        );
        insert cmp;
        Volunteer_Job__c job = new Volunteer_Job__c(name = 'Job1', campaign__c = cmp.Id);
        insert job;
        Volunteer_Shift__c shift = new Volunteer_Shift__c(
            Volunteer_Job__c = job.Id,
            Duration__c = 1,
            Start_Date_Time__c = System.today().adddays(1)
        );
        insert shift;

        //instantiate the controller
        VOL_CTRL_VolunteersFind ctrl = new VOL_CTRL_VolunteersFind();
        SoqlListView slv = new SoqlListView();
        slv.pageController = ctrl;

        System.assertNotEquals(null, ctrl);
        System.assertNotEquals(null, ctrl.GetStrSoql());
        System.assertNotEquals(null, ctrl.strFields);
        System.assertNotEquals(null, ctrl.strNameField);
        System.assertNotEquals(null, ctrl.strObjectType);
        System.assertNotEquals(null, ctrl.listSOCampaigns);
        System.assertEquals(null, ctrl.NewItem());
        System.assertEquals(null, ctrl.EditItem(null));
        System.assertNotEquals(null, ctrl.listStrFields);
        System.assertEquals(false, ctrl.hasFilterCriteria);

        ctrl.campaignId = cmp.Id;
        ctrl.ChangeCampaign();
        System.assertEquals(2, ctrl.listSOCampaigns.size());
        ctrl.volunteerJobId = job.Id;
        ctrl.ChangeVolunteerJob();
        System.assertEquals(2, ctrl.listSOVolunteerJobs.size());
        System.assertEquals(2, ctrl.listSOVolunteerShifts.size());

        ctrl.conFilter.Volunteer_Status__c = 'Active';
        ctrl.ctrlSoqlListView.strAlphaFilter = 't';
        ctrl.Find();
        System.assertEquals(3, ctrl.ctrlSoqlListView.NumberOfItems);
        ctrl.conFilter.Volunteer_Availability__c = 'Morning';
        ctrl.Find();
        System.assertEquals(1, ctrl.ctrlSoqlListView.NumberOfItems);
        System.assertEquals(1, ctrl.ctrlSoqlListView.NumberOfPages);
        System.assertEquals(1, ctrl.ctrlSoqlListView.listSLVObj.size());
        System.assertEquals(10, ctrl.ctrlSoqlListView.cRecordsPerPage);
        ctrl.ctrlSoqlListView.showMoreRecordsPerPage();
        System.assertEquals(20, ctrl.ctrlSoqlListView.cRecordsPerPage);
        System.assertEquals(null, ctrl.ctrlSoqlListView.AlphaFilter());
        System.assertEquals(26, ctrl.ctrlSoqlListView.listAlphaFilters.size());
        ctrl.ctrlSoqlListView.idDeleteItem = null;
        System.assertEquals(null, ctrl.ctrlSoqlListView.DeleteItem());
        ctrl.ctrlSoqlListView.idEditItem = null;
        System.assertEquals(null, ctrl.ctrlSoqlListView.EditItem());
        System.assertEquals(null, ctrl.ctrlSoqlListView.SortItem());

        // test Assign error handling
        ctrl.volunteerJobId = null;
        ctrl.volunteerShiftId = null;
        ctrl.Assign();

        // assign 1 volunteer to the job shift
        ctrl.vhAssign.Status__c = 'Confirmed';
        ctrl.vhAssign.Hours_Worked__c = 1;
        ctrl.ctrlSoqlListView.listSLVObjCurrent[0].checked = true;
        ctrl.volunteerJobId = job.Id;
        ctrl.volunteerShiftId = shift.Id;
        ctrl.Assign();
        List<Volunteer_Hours__c> listVH = [
            SELECT Id, Contact__c
            FROM Volunteer_Hours__c
            WHERE Volunteer_Job__c = :job.Id
        ];
        System.assertEquals(1, listVH.size());
        System.assertEquals(listCon[3].Id, listVH[0].Contact__c);

        // reassign the same volunteer and make sure another volunteer hours record does NOT get created.
        ctrl.ctrlSoqlListView.listSLVObjCurrent[0].checked = true;
        ctrl.Assign();
        listVH = [SELECT Id, Contact__c FROM Volunteer_Hours__c WHERE Volunteer_Job__c = :job.Id];
        System.assertEquals(1, listVH.size());
        System.assertEquals(listCon[3].Id, listVH[0].Contact__c);
    }
}