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

public with sharing class VOL_CTRL_SendBulkEmail {
    public String subject { get; set; }
    public String message { get; set; }
    public Volunteer_Hours__c hourStatus { get; set; }
    public Id templateId { get; set; }
    public Boolean isHtmlTemplate { get; private set; }
    public Integer numberOfContacts { get; set; }
    public Id fromEmailId { get; set; }
    public String strJobName { get; set; }
    public Boolean fLogActivity { get; set; }
    public Boolean fEmailContactsOnlyOnce { get; set; }

    public Id folderId { get; set; }
    public Id campaignId { get; set; }
    public Id shiftId { get; set; }
    public Id jobId { get; set; }

    // constructor
    public VOL_CTRL_SendBulkEmail() {
        try {
            // figure out what object we were invoked from
            campaignId = ApexPages.currentPage().getParameters().get('campaignId');
            jobId = ApexPages.currentPage().getParameters().get('jobId');
            shiftId = ApexPages.currentPage().getParameters().get('shiftId');
            fEmailContactsOnlyOnce = false;

            if (shiftId != null) {
                // Ensure the user has access to the object and fields before querying
                UTIL_Describe.checkReadAccess(
                    UTIL_Describe.StrTokenNSPrefix('Volunteer_Shift__c'),
                    new Set<String>{ 'Id', 'Name', UTIL_Describe.StrTokenNSPrefix('Volunteer_Job__c') }
                );
                // Using a dynamic describe access check in the method called above.
                /* sfge-disable-next-line ApexFlsViolationRule */
                Volunteer_Shift__c shift = [
                    SELECT Name, Volunteer_Job__r.Name
                    FROM Volunteer_Shift__c
                    WHERE Id = :shiftId
                ];
                strJobName = shift.Volunteer_Job__r.Name + ' - ' + shift.Name;
                templateObject = 'Shift';
            } else if (jobId != null) {
                // Ensure the user has access to the object and fields before querying
                UTIL_Describe.checkReadAccess(
                    UTIL_Describe.StrTokenNSPrefix('Volunteer_Job__c'),
                    new Set<String>{ 'Id', 'Name' }
                );
                // Using a dynamic describe access check in the method called above.
                /* sfge-disable-next-line ApexFlsViolationRule */
                Volunteer_Job__c job = [SELECT Name FROM Volunteer_Job__c WHERE Id = :jobId];
                strJobName = job.Name;
                templateObject = 'Job';
            } else if (campaignId != null) {
                // Ensure the user has access to the object and fields before querying
                UTIL_Describe.checkReadAccess('Campaign', new Set<String>{ 'Id', 'Name' });
                // Using a dynamic describe access check in the method called above.
                /* sfge-disable-next-line ApexFlsViolationRule */
                Campaign cmp = [SELECT Name FROM Campaign WHERE Id = :campaignId];
                strJobName = cmp.Name;
                templateObject = 'Campaign';
                // in the Campaign case, default to Unique Contacts
                fEmailContactsOnlyOnce = true;
            }
            hourStatus = new Volunteer_Hours__c();
            numberOfContacts = 0;
            fLogActivity = true;

            // Ensure the user has access to the object and fields before querying
            UTIL_Describe.checkReadAccess('Folder', new Set<String>{ 'Id', 'DeveloperName' });

            // get the folderId for our Volunteer email templates
            // Using a dynamic describe access check in the method called above.
            /* sfge-disable-next-line ApexFlsViolationRule */
            List<Folder> listf = [SELECT Id FROM Folder WHERE DeveloperName = 'Volunteers_Email_Templates'];
            if (listf.size() > 0) {
                folderId = listf[0].Id;
            }
        } catch (Exception e) {
            ApexPages.addMessages(e);
        }
    }

    // the list of Email Templates
    public List<SelectOption> getlistSOTemplates() {
        List<SelectOption> listSO = new List<SelectOption>();
        listSO.add(new SelectOption('', ''));
        for (EmailTemplate et : [
            SELECT Id, Name, Subject, Body
            FROM EmailTemplate
            WHERE isActive = TRUE AND FolderId = :folderId
            ORDER BY name
            LIMIT 999
        ]) {
            listSO.add(new SelectOption(et.id, et.name));
        }
        return listSO;
    }

    // the list of Org Wide Email Addresses
    public List<SelectOption> getlistSOFromEmails() {
        List<SelectOption> listSO = new List<SelectOption>();
        User thisUser = [SELECT Name, Email FROM User WHERE Id = :UserInfo.getUserId()];
        listSO.add(new SelectOption('', thisUser.Name + ' <' + thisUser.Email + '>'));
        for (OrgWideEmailAddress owa : [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress]) {
            listSO.add(new SelectOption(owa.id, owa.DisplayName + ' <' + owa.Address + '>'));
        }
        return listSO;
    }

    public String templateObject { get; set; }

    /*******************************************************************************************************************
     * @description Sets the email body and subject from the template matching the template Id selected
     * @return null
     */
    public PageReference loadEmailTemplate() {
        isHtmlTemplate = false;
        subject = null;
        message = null;

        if (templateId == null) {
            return null;
        }

        try {
            // Ensure the user has access to the object and fields before querying
            UTIL_Describe.checkReadAccess(
                'EmailTemplate',
                new Set<String>{ 'Id', 'Name', 'Subject', 'HtmlValue', 'Body' }
            );

            EmailTemplate template = [
                SELECT Id, Name, Subject, HtmlValue, Body, TemplateType
                FROM EmailTemplate
                WHERE Id = :templateId
            ];

            loadEmailTemplate(template);
            return null;
        } catch (Exception e) {
            ApexPages.addMessages(e);
            return null;
        }
    }

    /*******************************************************************************************************************
     * @description Sets the email body and subject from the template provided
     * @return null
     */
    @TestVisible
    private void loadEmailTemplate(EmailTemplate template) {
        subject = template.Subject;

        if (template.HtmlValue != null) {
            isHtmlTemplate = true;
            message = parseHtmlBody(template.HtmlValue);
        } else {
            message = template.Body;
        }
    }

    /*******************************************************************************************************************
     * @description The HTML classic email template contains each section of the email within cdata tags
     * @param html - The html value to parse
     * @return String All parts of the html template joined by line breaks
     */
    private String parseHtmlBody(String html) {
        String htmlBody = html.replaceAll('<!\\[CDATA\\[', 'CDATA_START').replaceAll(']]>', 'CDATA_END');
        Pattern cdataPattern = Pattern.compile('(CDATA_START)(.*?)(CDATA_END)');
        Matcher cdataMatcher = cdataPattern.matcher(htmlBody);
        List<String> bodyParts = new List<String>();

        while (cdataMatcher.find()) {
            String bodyPart = cdataMatcher.group().substringAfter('CDATA_START').substringBefore('CDATA_END');
            if (String.isBlank(bodyPart)) {
                continue;
            }
            bodyParts.add(bodyPart);
        }

        htmlBody = bodyParts.isEmpty() ? html : String.join(bodyParts, '<br>');

        return escapeHtml(htmlBody);
    }

    /*******************************************************************************************************************
     * @description Escape the html values by doing a temporary commit to a Rich Text Area field to allow
     * Salesforce to strip the non allowlisted tags for us (NOTE: You cannot rerender rich text input fields on
     * Visualforce pages, https://success.salesforce.com/ideaview?id=08730000000BpHiAAK)
     * @param htmlValue - the value to escape
     * @return Volunteer_Job__c the job associated with this page
     */
    @TestVisible
    private String escapeHtml(String htmlValue) {
        Savepoint savepoint = Database.setSavePoint();
        String escapedHtml = '';
        Volunteer_Job__c job = getRelatedJob();

        try {
            job.Description__c = htmlValue;
            // We are using Salesforce to sanitize the field then reverting the save.
            /* sfge-disable-next-line ApexFlsViolationRule */
            upsert job;
            /* sfge-disable-next-line ApexFlsViolationRule */
            escapedHtml = [SELECT Description__c FROM Volunteer_Job__c WHERE Id = :job.Id LIMIT 1].Description__c;
        } catch (Exception ex) {
            // Catch errors and rollback in the finally block
        } finally {
            Database.rollback(savepoint);
        }

        return escapedHtml;
    }

    /*******************************************************************************************************************
     * @description Retrieves the job associated with this page, either via shift, job or campaign
     * @return Volunteer_Job__c the job associated with this page
     */
    @TestVisible
    private Volunteer_Job__c getRelatedJob() {
        Volunteer_Job__c relatedJob = new Volunteer_Job__c();

        if (shiftId != null) {
            UTIL_Describe.checkReadAccess(
                UTIL_Describe.StrTokenNSPrefix('Volunteer_Shift__c'),
                new Set<String>{ 'Id', UTIL_Describe.StrTokenNSPrefix('Volunteer_Job__c') }
            );
            // Using a dynamic describe access check in the method called above.
            /* sfge-disable-next-line ApexFlsViolationRule */
            relatedJob.Id = [SELECT Volunteer_Job__c FROM Volunteer_Shift__c WHERE Id = :shiftId LIMIT 1]
            .Volunteer_Job__c;
            return relatedJob;
        }

        if (jobId != null) {
            relatedJob.Id = jobId;
            return relatedJob;
        }

        if (campaignId != null) {
            UTIL_Describe.checkReadAccess(
                UTIL_Describe.StrTokenNSPrefix('Volunteer_Job__c'),
                new Set<String>{ 'Id', UTIL_Describe.StrTokenNSPrefix('Campaign__c') }
            );
            // Using a dynamic describe access check in the method called above.
            /* sfge-disable-next-line ApexFlsViolationRule */
            List<Volunteer_Job__c> jobs = [SELECT Id FROM Volunteer_Job__c WHERE Campaign__c = :campaignId LIMIT 1];
            if (jobs.isEmpty()) {
                relatedJob.Campaign__c = campaignId;
            } else {
                relatedJob = jobs[0];
            }

            return relatedJob;
        }

        return null;
    }

    // action method called when status picklist has changed.  requery for number of contacts to email.
    public PageReference statusChanged() {
        try {
            List<Volunteer_Hours__c> listHr;

            // Ensure the user has access to the object and fields before querying
            UTIL_Describe.checkReadAccess(
                UTIL_Describe.StrTokenNSPrefix('Volunteer_Hours__c'),
                new Set<String>{
                    UTIL_Describe.StrTokenNSPrefix('Contact__c'),
                    UTIL_Describe.StrTokenNSPrefix('Status__c'),
                    UTIL_Describe.StrTokenNSPrefix('Volunteer_Shift__c'),
                    UTIL_Describe.StrTokenNSPrefix('Volunteer_Job__c')
                }
            );
            UTIL_Describe.checkReadAccess(
                UTIL_Describe.StrTokenNSPrefix('Volunteer_Job__c'),
                new Set<String>{ UTIL_Describe.StrTokenNSPrefix('Campaign__c') }
            );

            if (shiftId != null) {
                // Using a dynamic describe access check in the method called above.
                /* sfge-disable-next-line ApexFlsViolationRule */
                listHr = [
                    SELECT contact__c
                    FROM Volunteer_Hours__c
                    WHERE Status__c = :hourStatus.Status__c AND Volunteer_Shift__c = :shiftId
                ];
            } else if (jobId != null) {
                /* sfge-disable-next-line ApexFlsViolationRule */
                listHr = [
                    SELECT contact__c
                    FROM Volunteer_Hours__c
                    WHERE Status__c = :hourStatus.Status__c AND Volunteer_Job__c = :jobId
                ];
            } else if (campaignId != null) {
                // Salesforce failed to match our campaignId against the formula field which is text, so use full reference.
                /* sfge-disable-next-line ApexFlsViolationRule */
                listHr = [
                    SELECT contact__c
                    FROM Volunteer_Hours__c
                    WHERE Status__c = :hourStatus.Status__c AND Volunteer_Job__r.Campaign__c = :campaignId
                ];
            }

            if (fEmailContactsOnlyOnce) {
                Set<Id> setContactId = new Set<Id>();
                for (Volunteer_Hours__c hr : listHr) {
                    setContactId.add(hr.contact__c);
                }
                NumberOfContacts = setContactId.size();
            } else {
                NumberOfContacts = (listHR != null ? listHr.size() : 0);
            }
            return null;
        } catch (Exception e) {
            ApexPages.addMessages(e);
            return null;
        }
    }

    // action method to send the email
    public PageReference sendMail() {
        // do our validation
        if (numberOfContacts == 0) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, Label.labelMassEmailErrorNoContacts));
            return null;
        }

        if (templateId == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, Label.labelMassEmailErrorNoTemplate));
            return null;
        }

        try {
            List<Messaging.SingleEmailMessage> listEmail = new List<Messaging.SingleEmailMessage>();

            // cases:
            // specific shift
            // specific job with or without shifts (or mixture)
            // specific campaign, with or without jobs, with or without shifts
            UTIL_Describe.checkReadAccess(
                UTIL_Describe.StrTokenNSPrefix('Volunteer_Hours__c'),
                new Set<String>{
                    UTIL_Describe.StrTokenNSPrefix('Contact__c'),
                    UTIL_Describe.StrTokenNSPrefix('Volunteer_Shift__c'),
                    UTIL_Describe.StrTokenNSPrefix('Volunteer_Job__c'),
                    UTIL_Describe.StrTokenNSPrefix('Status__c')
                }
            );
            UTIL_Describe.checkReadAccess(
                UTIL_Describe.StrTokenNSPrefix('Volunteer_Job__c'),
                new Set<String>{ UTIL_Describe.StrTokenNSPrefix('Campaign__c') }
            );
            UTIL_Describe.checkReadAccess('Contact', new Set<String>{ 'Email' });
            String strSoql =
                'SELECT Contact__c, Volunteer_Shift__c, Volunteer_Job__c, Volunteer_Job__r.Campaign__c from Volunteer_Hours__c ' +
                ' where Status__c = \'' +
                VOL_SharedCode.StrEscape(hourStatus.Status__c) +
                '\' and ' +
                ' Contact__r.Email != null ';

            if (shiftId != null) {
                strSoql += ' and Volunteer_Shift__c = :shiftId ';
            } else if (jobId != null) {
                strSoql += ' and Volunteer_Job__c = :jobId ';
            } else if (campaignId != null) {
                strSoql += ' and Volunteer_Job__r.Campaign__c = :campaignId '; // don't use formula field which is text!
            }
            strSoql += ' order by Start_Date__c ';

            // to keep track of unique contacts
            Set<Id> setContactId = new Set<Id>();
            // Using a dynamic describe access check in the method called above.
            /* sfge-disable-next-line ApexFlsViolationRule */
            for (Volunteer_Hours__c hr : database.query(strSoql)) {
                if (!fEmailContactsOnlyOnce || setContactId.add(hr.Contact__c)) {
                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setTargetObjectId(hr.Contact__c);

                    // the rules for which object (and thus template) to support:
                    // if we aren't doing each contact once, then use the shift if we got it, otherwise use the job.
                    // if we are doing contacts only once, then always use the job, which seems more useful than the campaign.
                    //mail.setWhatId(fEmailContactsOnlyOnce ? hr.Volunteer_Job__c :
                    //  (hr.Volunteer_Shift__c != null ? hr.Volunteer_Shift__c : hr.Volunteer_Job__c));

                    Id whatId = null;
                    if (templateObject == 'Campaign') {
                        whatId = hr.Volunteer_Job__r.Campaign__c;
                    } else if (templateObject == 'Job') {
                        whatId = hr.Volunteer_Job__c;
                    } else if (templateObject == 'Shift') {
                        whatId = (hr.Volunteer_Shift__c != null ? hr.Volunteer_Shift__c : hr.Volunteer_Job__c);
                    } else if (templateObject == 'Hours') {
                        whatId = hr.Id;
                    }
                    mail.setWhatId(whatId);

                    mail.setSaveAsActivity(fLogActivity);
                    if (fromEmailId != null) {
                        mail.setOrgWideEmailAddressId(fromEmailId);
                    }
                    mail.setTemplateID(templateId);
                    listEmail.add(mail);
                }
            }

            // send the email and return
            if (listEmail.size() > 0) {
                List<Messaging.SendEmailResult> listSER;
                listSER = Messaging.sendEmail(listEmail, false);

                // report problems
                Integer cSuccess = 0;
                for (Messaging.SendEmailResult ser : listSER) {
                    if (ser.isSuccess()) {
                        cSuccess++;
                    } else {
                        List<Messaging.SendEmailError> listSEE = ser.getErrors();
                        for (Messaging.SendEmailError see : listSEE) {
                            Id objId = see.getTargetObjectId();
                            if (objId == null) {
                                // see if we can parse it out of the error string.
                                String strErr = see.getMessage();
                                Integer ich = strErr.lastIndexOf(' for Id : ');
                                if (ich >= 0) {
                                    objId = strErr.substring(ich + 10);
                                }
                            }
                            // Ensure the user has access to the object and fields before querying
                            UTIL_Describe.checkReadAccess('Contact', new Set<String>{ 'Id', 'Name', 'Email' });
                            // Using a dynamic describe access check in the method called above.
                            /* sfge-disable-next-line ApexFlsViolationRule */
                            List<Contact> listCon = [SELECT Name, Email FROM Contact WHERE Id = :objId];
                            String strDetails = '';
                            if (listCon.size() > 0) {
                                strDetails = ' ' + listCon[0].Name + ' (' + listCon[0].Email + ') ';
                            } // special case logging Activity failing
                            if (see.getStatusCode() == System.StatusCode.FIELD_INTEGRITY_EXCEPTION && fLogActivity) {
                                strDetails += ' ' + Label.labelMassEmailVolunteersActivityLoggingError;
                            }
                            ApexPages.addMessage(
                                new ApexPages.Message(
                                    ApexPages.Severity.ERROR,
                                    see.getStatusCode() + ': ' + see.getMessage() + strDetails
                                )
                            );
                        }
                    }
                }
                if (cSuccess > 0) {
                    ApexPages.addMessage(
                        new ApexPages.Message(
                            ApexPages.Severity.INFO,
                            Label.labelMassEmailVolunteersSuccessCount + ' ' + cSuccess
                        )
                    );
                }
                if (listSER.size() > 0) {
                    return null;
                } // stay on the page
            }
            return Cancel(); // this will take us back to our calling page.
        } catch (exception ex) {
            ApexPages.addMessages(ex);
            return null;
        }
    }

    // action method that user wants to close this page
    public PageReference cancel() {
        Id prId;
        if (shiftId != null) {
            prId = shiftId;
        } else if (jobId != null) {
            prId = jobId;
        } else {
            prId = campaignId;
        }
        PageReference p = new PageReference('/' + prId);
        p.setRedirect(true);
        return p;
    }
}