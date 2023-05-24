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
private with sharing class VOL_JRS_TEST {
    //******************************************************************************************************
    // Test Job Recurrence Schedules
    @IsTest
    private static void testJRS() {
        // create test data
        Campaign cmp = new Campaign(
            recordtypeid = VOL_SharedCode.recordtypeIdVolunteersCampaign,
            name = 'Job Calendar Test Campaign',
            IsActive = true
        );
        insert cmp;
        Volunteer_Job__c job = new Volunteer_Job__c(name = 'Job1', campaign__c = cmp.Id);
        insert job;
        Volunteer_Shift__c shift = new Volunteer_Shift__c(
            Volunteer_Job__c = job.Id,
            Duration__c = 1,
            Start_Date_Time__c = date.newInstance(2012, 1, 1)
        ); // 1/1/2012 was a Sunday
        insert shift;
        Job_Recurrence_Schedule__c jrs = new Job_Recurrence_Schedule__c(Volunteer_Job__c = job.Id);
        jrs.Days_of_Week__c = 'Monday;Wednesday;Friday';
        jrs.Duration__c = 1;

        jrs.Schedule_Start_Date_Time__c = date.newInstance(2012, 1, 1);
        jrs.Weekly_Occurrence__c = 'Every';
        jrs.Desired_Number_of_Volunteers__c = 5;
        insert jrs;

        // test Day of Week
        Boolean isSun = VOL_JRS.isSundayFirstOfWeek();
        System.assertEquals(isSun ? 1 : 7, VOL_JRS.nDayOfWeek(date.valueOf('2012-1-1')));
        System.assertEquals(isSun ? 7 : 6, VOL_JRS.nDayOfWeek(date.valueOf('2012-1-7')));
        System.assertEquals(isSun ? 3 : 2, VOL_JRS.nDayOfWeek(date.valueOf('2012-1-31')));
        System.assertEquals(isSun ? 4 : 3, VOL_JRS.nDayOfWeek(date.valueOf('2012-2-1')));
        System.assertEquals(isSun ? 4 : 3, VOL_JRS.nDayOfWeek(date.valueOf('2012-2-29')));

        // test dtNthDay
        System.assertEquals(Date.today(), VOL_JRS.dtNthDay(2012, 1, 1, 1));

        // test Every week.
        Date dtNext = VOL_JRS.dtNextDateforJRS(jrs, date.valueOf(shift.Start_Date_Time__c));
        System.assertEquals(1, VOL_JRS.cWeeksNext(jrs, dtNext, false));
        System.assertEquals(date.valueOf('2012-1-2'), dtNext);
        dtNext = VOL_JRS.dtNextDateforJRS(jrs, dtNext);
        System.assertEquals(date.valueOf('2012-1-4'), dtNext);
        dtNext = VOL_JRS.dtNextDateforJRS(jrs, dtNext);
        System.assertEquals(date.valueOf('2012-1-6'), dtNext);
        dtNext = VOL_JRS.dtNextDateforJRS(jrs, dtNext);
        System.assertEquals(date.valueOf('2012-1-9'), dtNext);

        // test Alternate weeks.
        jrs.Weekly_Occurrence__c = 'Alternate';
        update jrs;
        System.assertEquals(2, VOL_JRS.cWeeksNext(jrs, dtNext, true));
        dtNext = VOL_JRS.dtNextDateforJRS(jrs, dtNext);
        System.assertEquals(date.valueOf('2012-1-11'), dtNext);
        dtNext = VOL_JRS.dtNextDateforJRS(jrs, dtNext);
        System.assertEquals(date.valueOf('2012-1-13'), dtNext);
        dtNext = VOL_JRS.dtNextDateforJRS(jrs, dtNext);
        System.assertEquals(date.valueOf('2012-1-23'), dtNext);

        // test figuring out occurrence of day in month
        System.assertEquals(1, VOL_JRS.nWeekOfDate(date.valueOf('2012-1-1')));
        System.assertEquals(1, VOL_JRS.nWeekOfDate(date.valueOf('2012-1-7')));
        System.assertEquals(2, VOL_JRS.nWeekOfDate(date.valueOf('2012-1-8')));
        System.assertEquals(5, VOL_JRS.nWeekOfDate(date.valueOf('2012-1-29')));
        System.assertEquals(5, VOL_JRS.nWeekOfDate(date.valueOf('2012-1-31')));
        System.assertEquals(1, VOL_JRS.nWeekOfDate(date.valueOf('2012-2-1')));
        System.assertEquals(1, VOL_JRS.nWeekOfDate(date.valueOf('2012-2-4')));
        System.assertEquals(1, VOL_JRS.nWeekOfDate(date.valueOf('2012-2-5')));
        System.assertEquals(5, VOL_JRS.nWeekOfDate(date.valueOf('2012-2-29')));
        System.assertEquals(1, VOL_JRS.nWeekOfDate(date.valueOf('2012-2-6')));

        // test Nth week of Month
        jrs.Weekly_Occurrence__c = '3rd';
        update jrs;
        List<Boolean> listWhichWeeks = VOL_JRS.WhichWeeksJRS(jrs);
        System.assertEquals(false, listWhichWeeks[0]);
        System.assertEquals(false, listWhichWeeks[1]);
        System.assertEquals(false, listWhichWeeks[2]);
        System.assertEquals(true, listWhichWeeks[3]);
        System.assertEquals(false, listWhichWeeks[4]);
        System.assertEquals(false, listWhichWeeks[5]);

        System.assertEquals(2, VOL_JRS.cWeeksNext(jrs, date.valueOf('2012-1-1'), false));
        System.assertEquals(2, VOL_JRS.cWeeksNext(jrs, date.valueOf('2012-1-7'), false));
        System.assertEquals(1, VOL_JRS.cWeeksNext(jrs, date.valueOf('2012-1-8'), false));
        System.assertEquals(1, VOL_JRS.cWeeksNext(jrs, date.valueOf('2012-1-14'), false));
        System.assertEquals(5, VOL_JRS.cWeeksNext(jrs, date.valueOf('2012-1-15'), false));

        dtNext = VOL_JRS.dtNextDateforJRS(jrs, date.valueOf('2012-1-7'));
        System.assertEquals(date.valueOf('2012-1-16'), dtNext);

        jrs.Days_of_Week__c = 'Monday';
        update jrs;
        dtNext = VOL_JRS.dtNextDateforJRS(jrs, date.valueOf('2012-4-16'));
        System.assertEquals(date.valueOf('2012-5-21'), dtNext);

        jrs.Days_of_Week__c = 'Wednesday';
        update jrs;
        dtNext = VOL_JRS.dtNextDateforJRS(jrs, date.valueOf('2012-4-18'));
        System.assertEquals(date.valueOf('2012-5-16'), dtNext);

        jrs.Weekly_Occurrence__c = '1st';
        jrs.Days_of_Week__c = 'Monday';
        update jrs;
        dtNext = VOL_JRS.dtNextDateforJRS(jrs, date.valueOf('2012-2-6'));
        System.assertEquals(date.valueOf('2012-3-5'), dtNext);

        jrs.Weekly_Occurrence__c = '2nd;4th;';
        jrs.Days_of_Week__c = 'Sunday';
        update jrs;
        dtNext = VOL_JRS.dtNextDateforJRS(jrs, date.valueOf('2012-8-1'));
        System.assertEquals(date.valueOf('2012-8-12'), dtNext);

        // test batch calculations
        VOL_BATCH_Recurrence r = new VOL_BATCH_Recurrence();
        r.execute(null);

        // test deleting the JRS
        List<Volunteer_Shift__c> listShift = [
            SELECT Id, Name
            FROM Volunteer_Shift__c
            WHERE Job_Recurrence_Schedule__c = :jrs.Id
        ];
        System.assert(listShift.size() > 0);
        delete jrs;
        listShift = [SELECT Id, Name FROM Volunteer_Shift__c WHERE Job_Recurrence_Schedule__c = :jrs.Id];
        System.assertEquals(0, listShift.size());
    }

    //******************************************************************************************************
    // test that modifying a JRS reuses already existing Shifts
    @IsTest
    private static void testJRSShiftReuse() {
        // create test data
        Campaign cmp = new Campaign(
            recordtypeid = VOL_SharedCode.recordtypeIdVolunteersCampaign,
            name = 'Job Calendar Test Campaign',
            IsActive = true
        );
        insert cmp;
        Volunteer_Job__c job = new Volunteer_Job__c(name = 'Job1', campaign__c = cmp.Id);
        insert job;
        Job_Recurrence_Schedule__c jrs = new Job_Recurrence_Schedule__c(Volunteer_Job__c = job.Id);
        jrs.Days_of_Week__c = 'Monday';
        jrs.Duration__c = 1;
        jrs.Schedule_Start_Date_Time__c = System.now();
        jrs.Weekly_Occurrence__c = 'Every';
        jrs.Desired_Number_of_Volunteers__c = 5;
        jrs.Description__c = 'initial description';
        insert jrs;

        List<Volunteer_Shift__c> listShift = [SELECT Id FROM Volunteer_Shift__c];
        Set<Id> setShiftId = new Set<Id>();
        for (Volunteer_Shift__c shift : listShift) {
            setShiftId.add(shift.Id);
        }
        Integer cShifts = setShiftId.size();
        System.assert(cShifts > 0);

        // now modify the JRS
        jrs.Days_of_Week__c = 'Monday;Tuesday';
        jrs.Description__c = 'new description';
        Test.startTest();
        update jrs;
        Test.stopTest();

        listShift = [SELECT Id, CreatedDate, LastModifiedDate, Description__c FROM Volunteer_Shift__c];
        Integer cShiftsInitial = 0;
        Integer cShiftsNew = 0;
        for (Volunteer_Shift__c shift : listShift) {
            if (setShiftId.contains(shift.Id)) {
                cShiftsInitial++;
            } else {
                cShiftsNew++;
            }
            System.assertEquals('new description', shift.Description__c);
        }
        System.assertEquals(cShifts, cShiftsInitial);
        System.assert(cShifts == cShiftsNew || cShifts == cShiftsNew - 1 || cShifts == cShiftsNew + 1);
    }

    //******************************************************************************************************
    // test that modifying a JRS deletes already existing Shifts that no longer match the JRS
    @IsTest
    private static void testJRSShiftDelete() {
        // create test data
        Campaign cmp = new Campaign(
            recordtypeid = VOL_SharedCode.recordtypeIdVolunteersCampaign,
            name = 'Job Calendar Test Campaign',
            IsActive = true
        );
        insert cmp;
        Volunteer_Job__c job = new Volunteer_Job__c(name = 'Job1', campaign__c = cmp.Id);
        insert job;
        Job_Recurrence_Schedule__c jrs = new Job_Recurrence_Schedule__c(Volunteer_Job__c = job.Id);
        jrs.Days_of_Week__c = 'Monday';
        jrs.Duration__c = 1;
        jrs.Schedule_Start_Date_Time__c = System.now();
        jrs.Weekly_Occurrence__c = 'Every';
        jrs.Desired_Number_of_Volunteers__c = 5;
        jrs.Description__c = 'initial description';
        insert jrs;

        List<Volunteer_Shift__c> listShift = [SELECT Id FROM Volunteer_Shift__c];
        Set<Id> setShiftId = new Set<Id>();
        for (Volunteer_Shift__c shift : listShift) {
            setShiftId.add(shift.Id);
        }
        Integer cShifts = setShiftId.size();
        System.assert(cShifts > 0);

        // now modify the JRS
        jrs.Days_of_Week__c = 'Tuesday';
        jrs.Description__c = 'new description';
        Test.startTest();
        update jrs;
        Test.stopTest();

        listShift = [SELECT Id, CreatedDate, LastModifiedDate, Description__c FROM Volunteer_Shift__c];
        Integer cShiftsInitial = 0;
        Integer cShiftsNew = 0;
        for (Volunteer_Shift__c shift : listShift) {
            if (setShiftId.contains(shift.Id)) {
                cShiftsInitial++;
            } else {
                cShiftsNew++;
            }
            System.assertEquals('new description', shift.Description__c);
        }
        System.assertEquals(0, cShiftsInitial);
        System.assert(cShifts == cShiftsNew || cShifts == cShiftsNew - 1 || cShifts == cShiftsNew + 1);
    }

    //******************************************************************************************************
    // test that deleting a JRS deletes Shifts with no Hours, and just detaches Shifts with Hours.
    @IsTest
    private static void testJRSDelete() {
        // create test data
        Account acc = new Account(name = 'account1');
        insert acc;
        Contact con = new Contact(Lastname = 'foo', AccountId = acc.Id);
        insert con;
        Campaign cmp = new Campaign(
            recordtypeid = VOL_SharedCode.recordtypeIdVolunteersCampaign,
            name = 'Job Calendar Test Campaign',
            IsActive = true
        );
        insert cmp;
        Volunteer_Job__c job = new Volunteer_Job__c(name = 'Job1', campaign__c = cmp.Id);
        insert job;
        Job_Recurrence_Schedule__c jrs = new Job_Recurrence_Schedule__c(Volunteer_Job__c = job.Id);
        jrs.Days_of_Week__c = 'Monday';
        jrs.Duration__c = 1;
        jrs.Schedule_Start_Date_Time__c = System.today().addMonths(-1).toStartOfMonth();
        jrs.Schedule_End_Date__c = System.today().addmonths(2).toStartOfMonth().addDays(-1);
        jrs.Weekly_Occurrence__c = 'Every';
        jrs.Desired_Number_of_Volunteers__c = 5;
        jrs.Description__c = 'initial description';
        insert jrs;

        List<Volunteer_Shift__c> listShift = [SELECT Id, Volunteer_Job__c, Start_Date_Time__c FROM Volunteer_Shift__c];
        Integer countTotalShifts = listShift.size();
        System.assert(countTotalShifts >= 12); // we should get at least 4 Mondays each month.

        // now create Hours for half the shifts
        List<Volunteer_Hours__c> listHours = new List<Volunteer_Hours__c>();
        Integer countShiftsWithHours = 0;
        for (Integer i = 0; i < listShift.size(); i++) {
            if (Math.mod(i, 2) == 0) {
                Volunteer_Shift__c shift = listShift[i];
                countShiftsWithHours++;
                Integer cHoursLDV = 1;
                // for the first shift, we create a bunch of hours, to ensure our delete handler uses soql-for-loops
                // on the subquery it uses!
                if (countShiftsWithHours == 1) {
                    cHoursLDV = 2000;
                }
                for (Integer j = 0; j < cHoursLDV; j++) {
                    Volunteer_Hours__c hr = new Volunteer_Hours__c(
                        Contact__c = con.Id,
                        Volunteer_Job__c = shift.Volunteer_Job__c,
                        Volunteer_Shift__c = shift.Id,
                        Status__c = 'Prospect',
                        Start_Date__c = shift.Start_Date_Time__c.Date(),
                        Planned_Start_Date_Time__c = shift.Start_Date_Time__c,
                        Hours_Worked__c = 0,
                        Number_Of_Volunteers__c = 0
                    );
                    listHours.add(hr);
                }
            }
        }
        System.assert(countTotalShifts > countShiftsWithHours);
        insert listHours;

        Test.startTest();
        delete jrs;
        Test.stopTest();

        // verify some Shifts deleted and some detached
        listShift = [
            SELECT Id, Volunteer_Job__c, Start_Date_Time__c, Job_Recurrence_Schedule__c, System_Note__c
            FROM Volunteer_Shift__c
        ];
        System.assertEquals(countShiftsWithHours, listShift.size());
        for (Volunteer_Shift__c shift : listShift) {
            System.assertEquals(null, shift.Job_Recurrence_Schedule__c);
            System.assert(shift.System_Note__c.contains(Label.labelJRSShiftRemovedSystemNote));
        }
    }
    //******************************************************************************************************
    // test that updating a JRS deletes Shifts with no Hours, and just detaches Shifts with Hours.
    @IsTest
    private static void testJRSUpdate() {
        // create test data
        Account acc = new Account(name = 'account1');
        insert acc;
        Contact con = new Contact(Lastname = 'foo', AccountId = acc.Id);
        insert con;
        Campaign cmp = new Campaign(
            recordtypeid = VOL_SharedCode.recordtypeIdVolunteersCampaign,
            name = 'Job Calendar Test Campaign',
            IsActive = true
        );
        insert cmp;
        Volunteer_Job__c job = new Volunteer_Job__c(name = 'Job1', campaign__c = cmp.Id);
        insert job;
        Job_Recurrence_Schedule__c jrs = new Job_Recurrence_Schedule__c(Volunteer_Job__c = job.Id);
        jrs.Days_of_Week__c = 'Monday;Wednesday';
        jrs.Duration__c = 1;
        jrs.Schedule_Start_Date_Time__c = System.today().addMonths(-1).toStartOfMonth();
        jrs.Schedule_End_Date__c = System.today().addmonths(2).toStartOfMonth().addDays(-1);
        jrs.Weekly_Occurrence__c = 'Every';
        jrs.Desired_Number_of_Volunteers__c = 5;
        jrs.Description__c = 'initial description';
        insert jrs;

        List<Volunteer_Shift__c> listShift = [SELECT Id, Volunteer_Job__c, Start_Date_Time__c FROM Volunteer_Shift__c];
        Integer countTotalShifts = listShift.size();
        System.assert(countTotalShifts >= 24); // we should get at least 4 Mondays & Wednesdays each month.

        // now create Hours for half the shifts
        List<Volunteer_Hours__c> listHours = new List<Volunteer_Hours__c>();
        Integer countShiftsWithHours = 0;
        for (Integer i = 0; i < listShift.size(); i++) {
            if (Math.mod(i, 3) == 0) {
                Volunteer_Shift__c shift = listShift[i];
                countShiftsWithHours++;
                Integer cHoursLDV = 1;
                // for the first shift, we create a bunch of hours, to ensure our delete handler uses soql-for-loops
                // on the subquery it uses!
                if (countShiftsWithHours == 1) {
                    cHoursLDV = 2000;
                }
                for (Integer j = 0; j < cHoursLDV; j++) {
                    Volunteer_Hours__c hr = new Volunteer_Hours__c(
                        Contact__c = con.Id,
                        Volunteer_Job__c = shift.Volunteer_Job__c,
                        Volunteer_Shift__c = shift.Id,
                        Status__c = 'Prospect',
                        Start_Date__c = shift.Start_Date_Time__c.Date(),
                        Planned_Start_Date_Time__c = shift.Start_Date_Time__c,
                        Hours_Worked__c = 0,
                        Number_Of_Volunteers__c = 0
                    );
                    listHours.add(hr);
                }
            }
        }
        System.assert(countTotalShifts > countShiftsWithHours);
        insert listHours;

        Test.startTest();
        jrs.Days_of_Week__c = 'Monday;Friday';
        update jrs;
        Test.stopTest();

        // verify some Shifts deleted and some detached
        listShift = [
            SELECT Id, Volunteer_Job__c, Start_Date_Time__c, Job_Recurrence_Schedule__c, System_Note__c
            FROM Volunteer_Shift__c
            WHERE Job_Recurrence_Schedule__c = NULL
        ];
        System.assert(listShift.size() > 0);
        for (Volunteer_Shift__c shift : listShift) {
            System.assertEquals(null, shift.Job_Recurrence_Schedule__c);
            System.assert(shift.System_Note__c.contains(Label.labelJRSShiftRemovedSystemNote));
        }
    }
}