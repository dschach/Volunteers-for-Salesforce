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
private with sharing class VOL_CTRL_BatchProgress_TEST {
    //--------------------TEST METHOD------------------------
    @IsTest
    private static void batchStatusBarTest() {
        UTIL_JobProgress_CTRL controller = new UTIL_JobProgress_CTRL();
        controller.getBatchJobs();
        controller.numberOfJobs = 10;
        System.assertEquals(10, controller.numberOfJobs);
        controller.batchComponentLabel = 'my label';
        System.assertEquals('my label', controller.batchComponentLabel);
        // Verify defaults
        System.assertEquals(0, controller.getBatchJobs().size());
        System.assertEquals(null, controller.bj);
        System.assertEquals(false, controller.rerenderoncomplete);
        System.assertEquals(false, controller.hasExtendedStatus);
        System.assertEquals(true, controller.allCompleted);
    }

    @IsTest
    private static void testRollup() {
        VOL_CTRL_BatchProgress controller = new VOL_CTRL_BatchProgress();
        System.assertEquals(true, controller.batching);
        System.assertEquals(false, controller.batchRunning);
        System.assertEquals(null, controller.rollup());
    }

    @IsTest
    private static void testJobProgressController() {
        VOL_BATCH_Recurrence_TEST.createRecurringJob();
        PageReference bPage = Page.VolunteersBatchJobsProgress;
        Test.setCurrentPage(bPage);
        VOL_CTRL_BatchProgress bController = new VOL_CTRL_BatchProgress();
        UTIL_JobProgress_CTRL jpController = new UTIL_JobProgress_CTRL();

        Test.startTest();
        PageReference rollup = bController.rollup();
        Test.stopTest();

        System.assertEquals(1, jpController.getBatchJobs().size(), 'There should be 1 batch job ran.');
        System.assertEquals('Completed', UTIL_JobProgress_CTRL.getBatchJobsStatus(1)[0].status);
        System.assertEquals(null, rollup, 'The rollup button should always return null.');
    }

    @IsTest
    private static void testPageMessagesController() {
        ApexPages.addMessage(new ApexPages.message(ApexPages.severity.WARNING, 'summary'));
        UTIL_PageMessages_CTRL controller = new UTIL_PageMessages_CTRL();
        List<UTIL_PageMessages_CTRL.Message> messages = controller.getPageMessages();

        System.assertEquals(1, messages.size(), 'There should be one error on the page.');
        System.assertEquals(Label.PageMessagesWarning, messages[0].getSeverityLabel(), 'The label should be WARNING.');
        System.assertEquals('warning', messages[0].getSeverityTheme(), 'The theme should be warning.');
    }
}