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
private with sharing class VOL_CTRL_PersonalSiteContactLookup_TEST {
    //==================== TEST METHOD(s) ======================================

    @IsTest
    private static void shouldInsertTaskRecordsWhenEmailSent() {
        PageReference personalSiteLookupPage = new PageReference('Page.PersonalSiteContactLookup');
        Test.setCurrentPageReference(personalSiteLookupPage);
        VOL_CTRL_PersonalSiteContactLookup personalSiteLookupCtrl = new VOL_CTRL_PersonalSiteContactLookup();

        VOL_Access_TEST.Stub accessMock = new VOL_Access_TEST.Stub();
        VOL_CTRL_PersonalSiteContactLookup.access = (VOL_Access) Test.createStub(VOL_Access.class, accessMock);

        Contact contactRecord = UTIL_UnitTest.createContact();
        insert contactRecord;

        personalSiteLookupCtrl.SendEmailToContact(contactRecord);
        accessMock.assertMethodCalled('insertRecords', Task.SObjectType);
    }
    @IsTest
    private static void shouldConvertEmailToTask() {
        String expectedSubject = 'This is the subject';
        String expectedDescription = 'This the description.';
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();

        email.setSubject(expectedSubject);
        email.setPlainTextBody(expectedDescription);

        Task actualTask = VOL_CTRL_PersonalSiteContactLookup.toTask(email);
        System.assert(
            actualTask.Subject.contains(expectedSubject),
            'Expected the Task subject to contain the Email\'s subject.'
        );
        System.assert(
            actualTask.Description.contains(expectedDescription),
            'Expected the Task subject to contain the Email\'s subject.'
        );
    }

    @IsTest
    private static void shouldReturnDefaultClosedStatus() {
        final String defaultClosedStatus = 'Completed';

        System.assertEquals(
            defaultClosedStatus,
            VOL_CTRL_PersonalSiteContactLookup.getClosedTaskStatus(),
            'Expected the system to find the default closed task status.'
        );
    }

    @IsTest
    private static void shouldReturnDefaultClosedStatusWhenRunAsGuest() {
        final String defaultClosedStatus = 'Completed';

        System.runAs(UTIL_UnitTest.guestUser) {
            System.assertEquals(
                defaultClosedStatus,
                VOL_CTRL_PersonalSiteContactLookup.getClosedTaskStatus(),
                'Expected the system to find the default closed task status when ran as a guest user.'
            );
        }
    }

    @SuppressWarnings('PMD.ApexUnitTestShouldNotUseSeeAllDataTrue')
    @IsTest(SeeAllData=true) // SeeAllData so the CSS file is viewable
    /*******************************************************************************************************
     * @description test the visualforce page controller, running as the Sites Guest User, if such as user
     * exists.  if not, will run under the current user.
     ********************************************************************************************************/
    private static void testPageWithSitesGuestUser() {
        /** Without the ability to create sharing records in apex when owd sharing is public read/write or controlled by parent, we can no longer
         * run this test as the guest user and will only run it as the admin. Commenting out so that we can reinstate
         * if / when the ability to do so becomes available
         * List<User> listU = [Select Username, UserType, Name, IsActive, Id From User where IsActive = true and UserType = 'Guest' and
        Name like '%Site Guest User%'];
        if (listU.size() > 0) {
            UTIL_UnitTest.enableElevateGuestUserAccess();
            System.debug('Running test as Sites Guest User: ' + listU[0]);
            System.runAs(listU[0]) {
                TestPersonalSiteContactLookup();
            }
        } else {
        */
        System.debug('Running test as System.');
        testPersonalSiteContactLookup();
        //}
    }

    private static void testPersonalSiteContactLookup() {
        //point to our VF page
        PageReference p = new PageReference('Page.PersonalSiteContactLookup');
        Test.setCurrentPageReference(p);

        //instantiate the controller for this page
        VOL_CTRL_PersonalSiteContactLookup ctrl = new VOL_CTRL_PersonalSiteContactLookup();
        System.assertNotEquals(null, ctrl.strURLtoCSSFile);
        System.assertNotEquals(null, ctrl.contact);
        System.assertNotEquals(null, ctrl.strLanguage);
        System.assertEquals(null, ctrl.strResult);
        System.assertNotEquals(null, ctrl.emailTemplateId);
        System.assert(ctrl.orgWideEmailId == ctrl.orgWideEmailId);

        // test empty contact
        ctrl.contact.Firstname = null;
        ctrl.contact.Lastname = null;
        ctrl.contact.Email = null;
        System.assertEquals(null, ctrl.LookupContact());
        System.assertEquals(System.Label.labelContactLookupAmbiguous, ctrl.strResult);

        // test bogus contact
        ctrl.contact.Firstname = 'Not There';
        ctrl.contact.Lastname = 'Not There';
        ctrl.contact.Email = 'NotThere@NotThere.com';
        System.assertEquals(null, ctrl.LookupContact());
        System.assertEquals(System.Label.labelContactLookupAmbiguous, ctrl.strResult);

        // create a temp contact
        Contact con = new Contact();
        con.FirstName = 'LookupTestFirstName';
        con.LastName = 'LookupTestLastName';
        con.Email = 'LookupTestEmail@email.com';
        insert con;

        // test existing contact
        ctrl.contact.FirstName = 'LookupTestFirstName';
        ctrl.contact.LastName = 'LookupTestLastName';
        ctrl.contact.Email = 'LookupTestEmail@email.com';
        System.assertEquals(null, ctrl.LookupContact());
        System.assertEquals(System.Label.labelContactLookupAmbiguous, ctrl.strResult);

        // test error email handling
        con.Email = null;
        if (VOL_SharedCode.IsNPSPInstalled) {
            con.put('npe01__AlternateEmail__c', null);
            con.put('npe01__HomeEmail__c', null);
            con.put('npe01__WorkEmail__c', null);
        }
        update con;
        ctrl.SendEmailToContact(con);
        System.assertNotEquals(System.Label.labelContactLookupAmbiguous, ctrl.strResult);
    }
}