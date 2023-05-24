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
 * @date 11/1/2012
 * @description Main class for managing Volunteer Recurrence Schedules (VRS).
 ********************************************************************************************************/
public with sharing class VOL_VRS {
    //******************************************************************************************************
    // for the specified VRS's, delete all future hours that are not completed or canceled hours.
    // Past Hours and future completed/canceled Hours are detached from the VRS.
    // called from the After Delete VRS trigger.
    public static void deleteListVRS(List<Volunteer_Recurrence_Schedule__c> listVRS) {
        // get a set of the VRS IDs for querying
        Set<Id> setVRSId = new Set<Id>();
        for (Volunteer_Recurrence_Schedule__c vrs : listVRS) {
            setVRSId.add(vrs.Id);
        }

        // get all hours associated with these VRS's
        List<Volunteer_Hours__c> listHours = [
            SELECT
                Id,
                Status__c,
                Shift_Start_Date_Time__c,
                Volunteer_Recurrence_Schedule__r.Name,
                Volunteer_Recurrence_Schedule__c,
                System_Note__c
            FROM Volunteer_Hours__c
            WHERE Volunteer_Recurrence_Schedule__c IN :setVRSId
        ];

        deleteOrDetachVRSHours(listHours);
    }

    //******************************************************************************************************
    // Given a list of Hours, delete those that should be deleted (Future and status <> Completed or Canceled),
    // and just detach the other Hours (Past or Completed/Canceled) from their VRS.
    private static void deleteOrDetachVRSHours(List<Volunteer_Hours__c> listHours) {
        List<Volunteer_Hours__c> listHoursDelete = new List<Volunteer_Hours__c>();
        List<Volunteer_Hours__c> listHoursUpdate = new List<Volunteer_Hours__c>();

        for (Volunteer_Hours__c hr : listHours) {
            if (
                hr.Status__c == 'Completed' ||
                hr.Status__c == 'Canceled' ||
                hr.Shift_Start_Date_Time__c < System.today()
            ) {
                hr.System_Note__c +=
                    ' ' +
                    Label.labelVRSHoursRemovedSystemNote +
                    ' ' +
                    hr.Volunteer_Recurrence_Schedule__r.Name +
                    '.';
                hr.Volunteer_Recurrence_Schedule__c = null;
                listHoursUpdate.add(hr);
            } else {
                listHoursDelete.add(hr);
            }
        }

        if (listHoursUpdate.size() > 0) {
            update listHoursUpdate;
        }

        if (listHoursDelete.size() > 0) {
            delete listHoursDelete;
        }
    }

    //******************************************************************************************************
    // given a list of Volunteer recurring schedules, does all the work to delete any hours that
    // no longer match, and creates new hours into the future.
    // called from both the VRS trigger (when the user modifies a specific VRS),
    // as well as from the JRS processing, so new shifts get their hours assigned.
    // @param listVRS the list of VRS's to process
    // @param listVRSOld If called from the AfterUpdate trigger, the trigger.old list
    // @param fReviewAllShifts Specifies whether called from the trigger on JRS's, in
    // which case we should review all shifts under the Jobs, or from the scheduled batch,
    // in which case we only need to be looking to add additional shifts in the future.
    public static void processListVRS(
        List<Volunteer_Recurrence_Schedule__c> listVRS,
        List<Volunteer_Recurrence_Schedule__c> listVRSOld,
        Boolean fReviewAllShifts
    ) {
        // get a set of the VRS IDs for querying
        // also the Job IDs they are associated with
        // also the contact IDs they are associated with
        Set<Id> setVRSId = new Set<Id>();
        Set<Id> setJobId = new Set<Id>();
        Set<Id> setContactId = new Set<Id>();
        for (Volunteer_Recurrence_Schedule__c vrs : listVRS) {
            setVRSId.add(vrs.Id);
            setJobId.add(vrs.Volunteer_Job__c);
            setContactId.add(vrs.Contact__c);
        }

        // if the VRS was updated, then deal with potential changes to the VRS's job or contact
        if (listVRSOld != null) {
            for (Volunteer_Recurrence_Schedule__c vrs : listVRSOld) {
                setVRSId.add(vrs.Id);
                setJobId.add(vrs.Volunteer_Job__c);
                setContactId.add(vrs.Contact__c);
            }
        }

        // get appropriate shifts of the jobs these vrs's are associated with
        List<Volunteer_Shift__c> listShift = new List<Volunteer_Shift__c>();
        if (fReviewAllShifts) {
            listShift = [
                SELECT Id, Duration__c, Start_Date_Time__c, Desired_Number_of_Volunteers__c, Volunteer_Job__c
                FROM Volunteer_Shift__c
                WHERE Volunteer_Job__c IN :setJobId
            ];
        } else {
            listShift = [
                SELECT Id, Duration__c, Start_Date_Time__c, Desired_Number_of_Volunteers__c, Volunteer_Job__c
                FROM Volunteer_Shift__c
                WHERE Volunteer_Job__c IN :setJobId AND Start_Date_Time__c >= TODAY
            ];
        }

        // construct a map of Job to its associated list of VRS's
        Map<Id, List<Volunteer_Recurrence_Schedule__c>> mapJobIdListVRS = new Map<Id, List<Volunteer_Recurrence_Schedule__c>>();

        // put the VRS's on each job's list
        for (Volunteer_Recurrence_Schedule__c vrs : listVRS) {
            List<Volunteer_Recurrence_Schedule__c> listVRSforJob = mapJobIdListVRS.get(vrs.Volunteer_Job__c);
            if (listVRSforJob == null) {
                listVRSforJob = new List<Volunteer_Recurrence_Schedule__c>();
            }
            listVRSforJob.add(vrs);
            mapJobIdListVRS.put(vrs.Volunteer_Job__c, listVRSforJob);
        }

        // in order to avoid creating hours that already exist (completed or canceled),
        // create a set of shiftId|contactId tuples, which allows us to quickly see if we
        // already have an hours record for the given shift and contact.
        List<Volunteer_Hours__c> listHoursExisting = new List<Volunteer_Hours__c>();
        if (fReviewAllShifts) {
            listHoursExisting = [
                SELECT
                    Id,
                    Volunteer_Job__c,
                    Volunteer_Recurrence_Schedule__c,
                    Shift_Start_Date_Time__c,
                    Volunteer_Recurrence_Schedule__r.Name,
                    System_Note__c,
                    Volunteer_Shift__c,
                    Status__c,
                    Contact__c
                FROM Volunteer_Hours__c
                WHERE Volunteer_Job__c IN :setJobId AND Contact__c IN :setContactId
            ];
        } else {
            listHoursExisting = [
                SELECT
                    Id,
                    Volunteer_Job__c,
                    Volunteer_Recurrence_Schedule__c,
                    Shift_Start_Date_Time__c,
                    Volunteer_Recurrence_Schedule__r.Name,
                    System_Note__c,
                    Volunteer_Shift__c,
                    Status__c,
                    Contact__c
                FROM Volunteer_Hours__c
                WHERE
                    Volunteer_Job__c IN :setJobId
                    AND Contact__c IN :setContactId
                    AND Shift_Start_Date_Time__c >= TODAY
            ];
        }
        Map<String, Volunteer_Hours__c> mapShiftIdContactIdToHours = new Map<String, Volunteer_Hours__c>();
        for (Volunteer_Hours__c hr : listHoursExisting) {
            mapShiftIdContactIdToHours.put(hr.Volunteer_Shift__c + '|' + hr.Contact__c, hr);
        }

        // create hours for these vrs's for each shift
        List<Volunteer_Hours__c> listHoursNew = new List<Volunteer_Hours__c>();
        List<Volunteer_Hours__c> listHoursUpdate = new List<Volunteer_Hours__c>();
        for (Volunteer_Shift__c shift : listShift) {
            List<Volunteer_Recurrence_Schedule__c> listVRSforJob = mapJobIdListVRS.get(shift.Volunteer_Job__c);
            AssignVRSHours(shift, listVRSforJob, mapShiftIdContactIdToHours, listHoursNew, listHoursUpdate);
        }
        if (listHoursNew.size() > 0) {
            insert listHoursNew;
        }

        if (listHoursUpdate.size() > 0) {
            update listHoursUpdate;
        }

        // mapShiftIdContactIdToHours now contains only the Future Hours that did not match the VRS's,
        // so we can delete or detach them if they used to be associated with these VRS's.
        List<Volunteer_Hours__c> listHRDelete = new List<Volunteer_Hours__c>();
        for (Volunteer_Hours__c hr : mapShiftIdContactIdToHours.values()) {
            if (setVRSId.contains(hr.Volunteer_Recurrence_Schedule__c)) {
                listHRDelete.add(hr);
            }
        }
        deleteOrDetachVRSHours(listHRDelete);
    }

    //******************************************************************************************************
    // @description for the specified shift, create VolunteerHours records for all volunteers
    // who have a recurring schedule which should include this shift.
    // @param shift The shift to assign Hours to
    // @param listVRS The list of VRS's to consider for assigning hours to the shift
    // @param mapShiftIdContactIdToHours A map of shiftId/ContactId keys to existing Hours.  As Hours are
    // matched, they are removed from this map.  So upon return, this map contains those Hours that no longer
    // match their VRS (so they can be considered for deletion).
    // @param listHoursNew The returned set of Hours to create (leaving creation to the caller)
    // @param listHoursUpdate The returned set of Hours to update (leaving update to the caller)
    private static void assignVRSHours( //NOPMD
        Volunteer_Shift__c shift,
        List<Volunteer_Recurrence_Schedule__c> listVRS,
        Map<String, Volunteer_Hours__c> mapShiftIdContactIdToHours,
        List<Volunteer_Hours__c> listHoursNew,
        List<Volunteer_Hours__c> listHoursUpdate
    ) {
        if (listVRS == null) {
            return;
        }
        // Strategy:
        // for the given shift, go through the list of VRS's
        // and create hours for the ones that match.

        // we decided not to limit the number of volunteers assigned
        //Integer cDesiredVols = 1000;
        //if (shift.Desired_Number_of_Volunteers__c != null)
        //  cDesiredVols = Integer.valueOf(shift.Desired_Number_of_Volunteers__c);

        Date dtShift = shift.Start_Date_Time__c.Date();
        DateTime dtShiftEnd = shift.Start_Date_Time__c.addMinutes(Integer.valueOf(shift.Duration__c * 60));
        Integer nday = VOL_JRS.nDayOfWeek(dtShift);
        Set<Volunteer_Hours__c> setHoursOld = new Set<Volunteer_Hours__c>();
        Set<Volunteer_Hours__c> setHoursUpdate = new Set<Volunteer_Hours__c>();

        /*
        System.debug('****DJH: shift: ' + shift);
        System.debug('****DJH: dtShift: ' + dtShift);
        System.debug('****DJH: dtShiftEnd: ' + dtShiftEnd);
        System.debug('****DJH: nday: ' + nday);
        */

        for (Volunteer_Recurrence_Schedule__c vrs : listVRS) {
            // exit if we've filled all the slots.
            //if (cDesiredVols <= 0)
            //break;

            // for this jrs, what week should we treat this shift as
            Integer nweek = VOL_JRS.nWeekOfDate(dtFirstOccurrenceInWeek(vrs, dtShift));
            //System.debug('****DJH: nweek: ' + nweek);

            List<Boolean> listWhichDays = WhichDaysVRS(vrs);
            List<Boolean> listWhichWeeks = WhichWeeksVRS(vrs);
            //System.debug('****DJH: listWhichDays: ' + listWhichDays);
            //System.debug('****DJH: listWhichWeeks: ' + listWhichWeeks);

            if (vrs.Weekly_Occurrence__c == null) {
                continue;
            }

            if (
                (listWhichWeeks[nweek] ||
                vrs.Weekly_Occurrence__c.contains('Every') ||
                (vrs.Weekly_Occurrence__c.contains('Alternate') && alternateWeekVRS(vrs, dtShift))) &&
                listWhichDays[nday] &&
                vrs.Schedule_Start_Date_Time__c != null &&
                dtShift >= vrs.Schedule_Start_Date_Time__c.Date() &&
                (vrs.Schedule_End_Date__c == null ||
                vrs.Schedule_End_Date__c >= dtShift)
            ) {
                //System.debug('****DJH: vrs candidate for shift: vrs '+ vrs + ' shift ' + shift);

                // we need to deal with the person already having hours on this shift
                // that might be completed, or canceled, or web signup.
                // avoid creating another confirmed record.
                // note that if we match, we remove the key from the map, so we know it was matched.
                Volunteer_Hours__c hrExisting = mapShiftIdContactIdToHours.get(shift.Id + '|' + vrs.Contact__c);
                if (hrExisting != null) {
                    // only operate on hours from the current VRS or not yet belonging to a VRS to avoid reparenting hours from another VRS
                    if (
                        hrExisting.Volunteer_Recurrence_Schedule__c != null &&
                        hrExisting.Volunteer_Recurrence_Schedule__c != vrs.Id
                    ) {
                        continue;
                    }

                    // if shift/hour in the future, we update a subset of fields (Not Status though!)
                    if (dtShift >= System.today()) {
                        hrExisting.Hours_Worked__c = vrs.Duration__c;
                        if (vrs.Number_of_Volunteers__c != null && vrs.Number_of_Volunteers__c >= 1) {
                            hrExisting.Number_of_Volunteers__c = vrs.Number_of_Volunteers__c;
                        }
                        hrExisting.Planned_Start_Date_Time__c = datetime.newInstance(
                            shift.Start_Date_Time__c.date(),
                            vrs.Schedule_Start_Date_Time__c.time()
                        );
                        if (vrs.Comments__c != null) {
                            hrExisting.Comments__c = vrs.Comments__c;
                        }
                        hrExisting.Volunteer_Recurrence_Schedule__c = vrs.Id; // in case it wasn't already claimed by this VRS
                        setHoursUpdate.add(hrExisting);
                    } else {
                        // shift is in the past.  we won't update it, but track it so before we return we can remove it.
                        setHoursOld.add(hrExisting);
                    }
                    continue;
                }

                // only take volunteers whose time fits in the shift time (to handle multiple shifts per day)
                Time tmVRS = vrs.Schedule_Start_Date_Time__c.Time();
                DateTime dtVRSStart = datetime.newInstance(dtShift, tmVRS);
                if (dtVRSStart < shift.Start_Date_Time__c || dtVRSStart >= dtShiftEnd) {
                    /*
                    System.debug('****DJH: vrs startdatetime no fit!');
                    System.debug('****DJH: tmVRS: ' + tmVRS);
                    System.debug('****DJH: dtVRSStart: ' + dtVRSStart);
                    System.debug('****DJH: shift.Start_Date_Time__c: ' + shift.Start_Date_Time__c);
                    System.debug('****DJH: dtShiftEnd: ' + dtShiftEnd);
                    */
                    continue;
                }

                Volunteer_Hours__c hr = new Volunteer_Hours__c();
                hr.System_Note__c = Label.labelVRSHoursCreatedSystemNote + ' ' + vrs.Name + '.';
                hr.Contact__c = vrs.Contact__c;
                hr.Hours_Worked__c = vrs.Duration__c;
                hr.Number_of_Volunteers__c = 1;
                if (vrs.Number_of_Volunteers__c != null && vrs.Number_of_Volunteers__c > 1) {
                    hr.Number_of_Volunteers__c = vrs.Number_of_Volunteers__c;
                }
                hr.Start_Date__c = dtShift;
                hr.End_Date__c = dtShift;
                hr.Status__c = (vrs.Volunteer_Hours_Status__c == null ? 'Confirmed' : vrs.Volunteer_Hours_Status__c);
                hr.Volunteer_Job__c = shift.Volunteer_Job__c;
                hr.Volunteer_Shift__c = shift.Id;
                hr.Volunteer_Recurrence_Schedule__c = vrs.Id;
                hr.Planned_Start_Date_Time__c = datetime.newInstance(
                    shift.Start_Date_Time__c.date(),
                    vrs.Schedule_Start_Date_Time__c.time()
                );
                hr.Comments__c = vrs.Comments__c;
                listHoursNew.add(hr);

                // add the new hours to our map, so it won't get duplicated by two VRS's
                mapShiftIdContactIdToHours.put(hr.Volunteer_Shift__c + '|' + hr.Contact__c, hr);

                //cDesiredVols--;
            } else {
                System.debug('****DJH: vrs no match shift: vrs ' + vrs + ' shift ' + shift);
            }
        }

        // we remove any matched or new hours from the map, so the caller knows who wasn't matched.
        listHoursUpdate.addAll(setHoursUpdate);
        for (Volunteer_Hours__c hr : setHoursUpdate) {
            mapShiftIdContactIdToHours.remove(hr.Volunteer_Shift__c + '|' + hr.Contact__c);
        }
        for (Volunteer_Hours__c hr : listHoursNew) {
            mapShiftIdContactIdToHours.remove(hr.Volunteer_Shift__c + '|' + hr.Contact__c);
        }
        for (Volunteer_Hours__c hr : setHoursOld) {
            mapShiftIdContactIdToHours.remove(hr.Volunteer_Shift__c + '|' + hr.Contact__c);
        }
        // we let the caller commit the new/updated hours to the db.
    }

    //******************************************************************************************************
    // returns whether the nweek of the specified date is an alternate week for this schedule
    public static Boolean alternateWeekVRS(Volunteer_Recurrence_Schedule__c vrs, Date dt) {
        if (vrs.Schedule_Start_Date_Time__c == null) {
            return false;
        }
        Date dtStart = vrs.Schedule_Start_Date_Time__c.Date().toStartOfWeek();
        Date dtEnd = dt.toStartOfWeek();
        Integer cdays = dtStart.daysBetween(dtEnd);
        Integer nweeks = (cdays + 1) / 7;
        return math.mod(nweeks, 2) == 0 ? true : false;
    }

    //******************************************************************************************************
    // returns an array of booleans for which days are on the schedule.
    // note that you should index by nDay (ie, Mon = index 2).
    private static List<Boolean> whichDaysVRS(Volunteer_Recurrence_Schedule__c vrs) {
        List<Boolean> listWhichDays = new List<Boolean>{ false, false, false, false, false, false, false, false };
        Boolean isSun = VOL_JRS.isSundayFirstOfWeek();

        if (vrs.Days_of_Week__c != null) {
            listWhichDays[isSun ? 1 : 7] = vrs.Days_of_Week__c.contains('Sunday');
            listWhichDays[isSun ? 2 : 1] = vrs.Days_of_Week__c.contains('Monday');
            listWhichDays[isSun ? 3 : 2] = vrs.Days_of_Week__c.contains('Tuesday');
            listWhichDays[isSun ? 4 : 3] = vrs.Days_of_Week__c.contains('Wednesday');
            listWhichDays[isSun ? 5 : 4] = vrs.Days_of_Week__c.contains('Thursday');
            listWhichDays[isSun ? 6 : 5] = vrs.Days_of_Week__c.contains('Friday');
            listWhichDays[isSun ? 7 : 6] = vrs.Days_of_Week__c.contains('Saturday');
        }
        return listWhichDays;
    }

    //******************************************************************************************************
    // returns an array of booleans for which weeks are on the schedule.
    // note that you should index by nWeek (ie, first = index 1).
    private static List<Boolean> whichWeeksVRS(Volunteer_Recurrence_Schedule__c vrs) {
        List<Boolean> listWhichWeeks = new List<Boolean>{ false, false, false, false, false, false };
        if (vrs.Weekly_Occurrence__c != null) {
            listWhichWeeks[1] = vrs.Weekly_Occurrence__c.contains('1st');
            listWhichWeeks[2] = vrs.Weekly_Occurrence__c.contains('2nd');
            listWhichWeeks[3] = vrs.Weekly_Occurrence__c.contains('3rd');
            listWhichWeeks[4] = vrs.Weekly_Occurrence__c.contains('4th');
            listWhichWeeks[5] = vrs.Weekly_Occurrence__c.contains('5th');
        }
        return listWhichWeeks;
    }

    //******************************************************************************************************
    // given the current date, return the first date in that week that should be scheduled
    private static Date dtFirstOccurrenceInWeek(Volunteer_Recurrence_Schedule__c vrs, Date dt) {
        List<Boolean> listWhichDays = WhichDaysVRS(vrs);
        Integer nday = VOL_JRS.nDayOfWeek(dt);
        Integer n;
        for (n = 1; n < nday && n <= 7; n++) {
            if (listWhichDays[n]) {
                break;
            }
        }
        return dt.addDays(n - nday);
    }
}