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
private with sharing class VOL_CTRL_VolunteersSignupFS_TEST {
    //==================== TEST METHOD(s) ======================================

    /*******************************************************************************************************
     * @description test the visualforce page controller, running as the Sites Guest User, if such as user
     * exists.  if not, will run under the current user.
     ********************************************************************************************************/
    @IsTest
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
                CodeCoverageTests();
            }
        } else {
        */
        System.debug('Running test as System.');
        CodeCoverageTests();
        //}
    }

    private static void codeCoverageTests() {
        // create test bucket account
        Account acc = new Account(Name = 'Test Individual Bucket Account');
        insert acc;

        // exercise some initial settings code
        System.Assert(VOL_SharedCode.VolunteersSettings != null);

        // specify our settings
        Volunteers_Settings__c settings = new Volunteers_Settings__c();
        settings.Signup_Bucket_Account_On_Create__c = 'Test Individual Bucket Account';
        VOL_SharedCode.getVolunteersSettingsForTests(settings);

        PageReference pageRef = Page.VolunteersSignupFS;
        pageRef.getParameters().put('FileUploadLabel', 'Upload a test file');
        Test.setCurrentPage(pageRef);

        //instantiate the controller
        VOL_CTRL_VolunteersSignupFS ctrl = new VOL_CTRL_VolunteersSignupFS();

        // scenario 1: creating a new contact to the bucket account.
        Contact contact = ctrl.contact;
        System.Assert(contact != null);
        contact.FirstName = 'TestFirstName';
        contact.LastName = 'TestLastName';
        contact.Email = 'foovolunteer@bar.com';
        contact.MailingState = 'wa';
        ctrl.Save();
        System.AssertEquals(System.Label.labelVolunteerSignupThankYou, ctrl.StrSaveResult);

        // make sure it got created correctly
        contact = [
            SELECT Id, AccountId
            FROM Contact
            WHERE Email = 'foovolunteer@bar.com' AND Firstname = 'TestFirstName'
            LIMIT 1
        ];
        System.Assert(contact.Id != null);
        System.AssertEquals(VOL_SharedCode.SettingsBucketAccountId, contact.AccountId);

        // scenario 2: creating a new contact to an existing account
        Account acc2 = new Account(Name = 'My GW Volunteers Test Company');
        insert acc2;
        contact = ctrl.contact;
        System.Assert(contact != null);
        contact.FirstName = 'TestFirstName2';
        contact.LastName = 'TestLastName2';
        contact.Email = 'foo2volunteer@bar.com';
        contact.MailingCountry = 'us';
        contact.Volunteer_Organization__c = 'My GW Volunteers Test Company';
        ctrl.Save();
        System.AssertEquals(System.Label.labelVolunteerSignupThankYou, ctrl.StrSaveResult);

        // make sure it got created
        contact = [
            SELECT Id, AccountId
            FROM Contact
            WHERE Email = 'foo2volunteer@bar.com' AND Firstname = 'TestFirstName2'
            LIMIT 1
        ];
        System.Assert(contact.Id != null);
        System.AssertEquals(acc2.Id, contact.AccountId);

        // scenario 3: update to an existing contact
        contact = ctrl.contact;
        System.Assert(contact != null);
        contact.FirstName = 'TestFirstName2';
        contact.LastName = 'TestLastName2';
        contact.Email = 'foo2volunteer@bar.com';
        contact.Phone = '425-123-4567';
        contact.HomePhone = '206-123-4567';
        ctrl.Save();
        System.AssertEquals(System.Label.labelVolunteerSignupThankYou, ctrl.StrSaveResult);

        // make sure the existing contact's volunteer status field was updated
        contact = [
            SELECT Id, Volunteer_Status__c, Phone
            FROM Contact
            WHERE Email = 'foo2volunteer@bar.com' AND Firstname = 'TestFirstName2'
            LIMIT 1
        ];
        System.AssertEquals('New Sign Up', contact.Volunteer_Status__c);
        System.Assert(('425-123-4567' == contact.Phone) || ('206-123-4567' == contact.Phone));

        // anything else
        System.Assert(ctrl.strURLtoCSSFile == ctrl.strURLtoCSSFile);

        // attachments
        System.assert(ctrl.attachment != null);
        ctrl.attachment.Body = Blob.valueof('some random test string');
        System.assert(ctrl.attachment.body != null);
        ctrl.Save();

        // test error handling
        UTIL_Describe.throwException = true;
        contact = ctrl.contact;
        System.Assert(contact != null);
        contact.FirstName = 'TestFirstName';
        contact.LastName = 'TestLastName';
        contact.Email = 'foovolunteer@bar.com';
        contact.Department = 'Some Random Company';
        System.assertEquals(null, ctrl.Save());
        System.assert(ctrl.StrSaveResult.contains('permissions'));
    }
}