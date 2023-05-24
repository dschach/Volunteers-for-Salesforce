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

trigger VOL_Contact_MaintainHours on Contact(before delete, after delete, after undelete) {
	// Hours are true children of Contacts, but Salesforce doesn't
	// have the cascading delete fire events on the child objects.
	// So we have to call the trigger ourselves.
	if (Trigger.isDelete && Trigger.isBefore) {
		Set<Id> setContactId = new Set<Id>();
		for (SObject obj : Trigger.old) {
			setContactId.add(obj.Id);
		}
		List<Volunteer_Hours__c> listHours = new List<Volunteer_Hours__c>();
		listHours = [
			SELECT Id, Status__c, Volunteer_Shift__c, Volunteer_Job__c, Number_Of_Volunteers__c
			FROM Volunteer_Hours__c
			WHERE Contact__c IN :setContactId
		];

		VOL_SharedCode.VolunteerHoursTrigger(listHours, null, false);
	}

	// in the case of Merge, we've removed the hours from the old shift during the Before Delete.
	// now in the After Delete, we are able to see who the winning contacts are.
	// unfortunately, we can't tell which are the Hours that got moved to the winning contact,
	// so we have to recalc the Shifts rollups for all its hours.
	if (Trigger.isDelete && Trigger.isAfter) {
		Set<Id> setContactId = new Set<Id>();
		for (Contact obj : Trigger.old) {
			setContactId.add(obj.MasterRecordId);
		}
		List<Volunteer_Hours__c> listHours = [
			SELECT Id, Status__c, Volunteer_Shift__c, Volunteer_Job__c, Number_Of_Volunteers__c
			FROM Volunteer_Hours__c
			WHERE Contact__c IN :setContactId
		];

		// get all the Hours for the affected Shifts
		Set<Id> setShiftId = new Set<Id>();
		for (Volunteer_Hours__c hr : listHours) {
			if (hr.Volunteer_Shift__c != null) {
				setShiftId.add(hr.Volunteer_Shift__c);
			}
		}
		if (setShiftId.size() > 0) {
			listHours = [
				SELECT Id, Status__c, Volunteer_Shift__c, Volunteer_Job__c, Number_Of_Volunteers__c
				FROM Volunteer_Hours__c
				WHERE Volunteer_Shift__c IN :setShiftId
			];

			VOL_SharedCode.volunteerHoursTrigger(null, listHours, true);
		}
	}

	// similar issue with undeletes of contacts.
	// Salesforce won't fire an undelete trigger on the hours.
	// So we have to call the trigger ourselves.
	if (Trigger.isUndelete) {
		Set<Id> setContactId = new Set<Id>();
		for (SObject obj : Trigger.new) {
			setContactId.add(obj.Id);
		}
		List<Volunteer_Hours__c> listHours = [
			SELECT Id, Status__c, Volunteer_Shift__c, Volunteer_Job__c, Number_Of_Volunteers__c
			FROM Volunteer_Hours__c
			WHERE Contact__c IN :setContactId
		];

		VOL_SharedCode.volunteerHoursTrigger(null, listHours, false);
	}

}