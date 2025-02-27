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
private class VOL_TEST_VolunteerHours_Trigger {
    private static VOL_Access_TEST.Stub accessMock = new VOL_Access_TEST.Stub();

    @IsTest
    private static void shouldUpdateShiftRecordsOnConfirmedHours() {
        VOL_SharedCode.access = (VOL_Access) Test.createStub(VOL_Access.class, accessMock);
        UTIL_UnitTest.generateDataWithShift();
        Id shiftId = UTIL_UnitTest.getId(Volunteer_Shift__c.SObjectType);

        Volunteer_Hours__c hours = UTIL_UnitTest.createHours(
            UTIL_UnitTest.getId(Contact.SObjectType),
            UTIL_UnitTest.getId(Volunteer_Job__c.SObjectType),
            shiftId
        );
        hours.Status__c = 'Confirmed';
        insert hours;

        accessMock.assertMethodCalled('updateRecords', Volunteer_Shift__c.SObjectType);
    }

    @IsTest
    private static void shouldNotUpdateShiftRecordsOnPendingHours() {
        VOL_SharedCode.access = (VOL_Access) Test.createStub(VOL_Access.class, accessMock);
        UTIL_UnitTest.generateDataWithShift();
        Id shiftId = UTIL_UnitTest.getId(Volunteer_Shift__c.SObjectType);

        Volunteer_Hours__c hours = UTIL_UnitTest.createHours(
            UTIL_UnitTest.getId(Contact.SObjectType),
            UTIL_UnitTest.getId(Volunteer_Job__c.SObjectType),
            shiftId
        );
        hours.Status__c = 'Pending';
        insert hours;

        accessMock.assertMethodCalled('updateRecords', null);
    }

    @IsTest
    private static void myUnitTest() {
        Account acc = new Account(name = 'Individual Test Account');
        insert acc;
        Contact con = new Contact(Lastname = 'Testy', AccountId = acc.Id, Volunteer_Status__c = 'inactive');
        insert con;
        Campaign cmp = new Campaign(
            recordtypeid = VOL_SharedCode.recordtypeIdVolunteersCampaign,
            name = 'Test Campaign',
            IsActive = true
        );
        insert cmp;
        Volunteer_Job__c job = new Volunteer_Job__c(name = 'Job1', campaign__c = cmp.Id);
        insert job;
        Volunteer_Shift__c shift = new Volunteer_Shift__c(
            Volunteer_Job__c = job.Id,
            Duration__c = 1,
            Start_Date_Time__c = System.now()
        );
        insert shift;

        // test inserting new hours
        List<Volunteer_Hours__c> listHours = new List<Volunteer_Hours__c>();
        for (Integer i = 0; i < 10; i++) {
            Volunteer_Hours__c hours = new Volunteer_Hours__c(
                Volunteer_Job__c = job.id,
                Volunteer_Shift__c = shift.Id,
                Contact__c = con.Id,
                Number_of_Volunteers__c = 3,
                Start_Date__c = System.today(),
                Status__c = 'Confirmed'
            );
            listHours.add(hours);
        }
        insert listHours;
        shift = [SELECT Id, Total_Volunteers__c FROM Volunteer_Shift__c WHERE Id = :shift.Id LIMIT 1];
        System.AssertEquals(30, shift.Total_Volunteers__c);

        // test updating existing hours
        for (Integer i = 0; i < 10; i++) {
            listHours.get(i).Number_of_Volunteers__c = 1;
        }
        update listHours;
        shift = [SELECT Id, Total_Volunteers__c FROM Volunteer_Shift__c WHERE Id = :shift.Id LIMIT 1];
        System.AssertEquals(10, shift.Total_Volunteers__c);

        // test deleting existing hours
        listHours.remove(1);
        listHours.remove(2);
        listHours.remove(3);
        delete listHours;
        shift = [SELECT Id, Total_Volunteers__c FROM Volunteer_Shift__c WHERE Id = :shift.Id LIMIT 1];
        System.AssertEquals(3, shift.Total_Volunteers__c);

        // make sure our contact's volunteer status was made active
        Contact conT = [SELECT Id, Volunteer_Status__c FROM Contact WHERE Id = :con.Id];
        System.AssertEquals('Active', conT.Volunteer_Status__c);

        // test deleting contact to make sure their hours are deleted and Shift rollups are recalced.
        delete conT;
        shift = [SELECT Id, Total_Volunteers__c FROM Volunteer_Shift__c WHERE Id = :shift.Id LIMIT 1];
        System.AssertEquals(0, shift.Total_Volunteers__c);

        // test undeleting a contact that restores their child objects
        undelete conT;
        shift = [SELECT Id, Total_Volunteers__c FROM Volunteer_Shift__c WHERE Id = :shift.Id LIMIT 1];
        System.AssertEquals(3, shift.Total_Volunteers__c);

        // test changing of Hours from one Shift to another Shift.
        listHours = new List<Volunteer_Hours__c>();
        for (Integer i = 0; i < 9; i++) {
            Volunteer_Hours__c hours = new Volunteer_Hours__c(
                Volunteer_Job__c = job.id,
                Volunteer_Shift__c = shift.Id,
                Contact__c = con.Id,
                Number_of_Volunteers__c = 3,
                Start_Date__c = System.today(),
                Status__c = 'Confirmed'
            );
            listHours.add(hours);
        }
        insert listHours;
        shift = [SELECT Id, Total_Volunteers__c FROM Volunteer_Shift__c WHERE Id = :shift.Id LIMIT 1];
        System.AssertEquals(30, shift.Total_Volunteers__c);
        Volunteer_Shift__c shift2 = new Volunteer_Shift__c(
            Volunteer_Job__c = job.Id,
            Duration__c = 1,
            Start_Date_Time__c = System.now()
        );
        insert shift2;
        listHours[0].Volunteer_Shift__c = shift2.Id;
        listHours[1].Volunteer_Shift__c = shift2.Id;
        listHours[2].Volunteer_Shift__c = shift2.Id;
        update listHours;
        shift = [SELECT Id, Total_Volunteers__c FROM Volunteer_Shift__c WHERE Id = :shift.Id LIMIT 1];
        System.AssertEquals(21, shift.Total_Volunteers__c);
        shift2 = [SELECT Id, Total_Volunteers__c FROM Volunteer_Shift__c WHERE Id = :shift2.Id LIMIT 1];
        System.AssertEquals(9, shift2.Total_Volunteers__c);

        // test reparenting of Hours from one Job to another Job.
        Volunteer_Job__c job2 = new Volunteer_Job__c(name = 'Job2', campaign__c = cmp.Id);
        insert job2;
        listHours[0].Volunteer_Job__c = job2.Id;
        listHours[0].Volunteer_Shift__c = null;
        listHours[1].Volunteer_Job__c = job2.Id;
        listHours[1].Volunteer_Shift__c = null;
        listHours[2].Volunteer_Job__c = job2.Id;
        listHours[2].Volunteer_Shift__c = null;
        update listHours;
        shift2 = [SELECT Id, Total_Volunteers__c FROM Volunteer_Shift__c WHERE Id = :shift2.Id LIMIT 1];
        System.AssertEquals(0, shift2.Total_Volunteers__c);
        job2 = [SELECT Id, Number_of_Volunteers__c FROM Volunteer_Job__c WHERE Id = :job2.Id LIMIT 1];
        System.AssertEquals(9, job2.Number_of_Volunteers__c);

        // test merging of contacts.
        Contact con2 = new Contact(Lastname = 'Testy2', AccountId = acc.Id, Volunteer_Status__c = 'inactive');
        insert con2;
        shift = [SELECT Id, Total_Volunteers__c FROM Volunteer_Shift__c WHERE Id = :shift.Id LIMIT 1];
        System.AssertEquals(21, shift.Total_Volunteers__c);
        Volunteer_Hours__c hours2 = new Volunteer_Hours__c(
            Volunteer_Job__c = job.id,
            Volunteer_Shift__c = shift.Id,
            Contact__c = con2.Id,
            Number_of_Volunteers__c = 4,
            Start_Date__c = System.today(),
            Status__c = 'Confirmed'
        );
        insert hours2;
        listHours = [SELECT Id FROM Volunteer_Hours__c WHERE contact__c = :con.Id];
        System.AssertEquals(12, listHours.size());
        listHours = [SELECT Id FROM Volunteer_Hours__c WHERE contact__c = :con2.Id];
        System.AssertEquals(1, listHours.size());
        shift = [SELECT Id, Total_Volunteers__c FROM Volunteer_Shift__c WHERE Id = :shift.Id LIMIT 1];
        System.AssertEquals(25, shift.Total_Volunteers__c);
        merge con con2;
        listHours = [SELECT Id FROM Volunteer_Hours__c WHERE contact__c = :con.Id];
        System.AssertEquals(13, listHours.size());
        shift = [SELECT Id, Total_Volunteers__c FROM Volunteer_Shift__c WHERE Id = :shift.Id LIMIT 1];
        System.AssertEquals(25, shift.Total_Volunteers__c);
    }
}