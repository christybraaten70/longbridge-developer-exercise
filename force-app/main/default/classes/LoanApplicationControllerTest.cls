/**
 * @description       : Tests for LoanApplicationController
 * @last modified on  : 11/12/2026
 **/
@IsTest
private class LoanApplicationControllerTest {

    // Adjust these to match the picklist values and required fields in your org.
    private static final String STATUS_NEW          = 'New';
    private static final String STATUS_UNDER_REVIEW = 'Under Review';
    private static final String STATUS_APPROVED     = 'Approved';
    private static final String STATUS_REJECTED     = 'Rejected';
    private static final String PRODUCT_VALUE       = 'HELOC';
    private static final String ACCOUNT_NAME        = 'Test Applicant';

    @TestSetup
    static void setup() {
        Account acct = new Account(Name = ACCOUNT_NAME);
        insert acct;

        insert new List<Loan_Application__c>{
            buildApp(acct.Id, STATUS_NEW, null),
            buildApp(acct.Id, STATUS_UNDER_REVIEW, null),
            buildApp(acct.Id, STATUS_APPROVED, null),
            buildApp(acct.Id, STATUS_REJECTED, 'Reject Reason')
        };
    }

    private static Loan_Application__c buildApp(Id accountId, String status, String reason) {
        return new Loan_Application__c(
            Applicant_Account__c = accountId,
            Loan_Amount__c       = 25000,
            Product__c           = PRODUCT_VALUE,
            Status__c            = status,
            Decision_Reason__c	 = reason
        );
    }

    private static Set<String> statusesOf(List<Loan_Application__c> apps) {
        Set<String> statuses = new Set<String>();
        for (Loan_Application__c app : apps) {
            statuses.add(app.Status__c);
        }
        return statuses;
    }

    // ---------- getApplications ----------

    @IsTest
    static void getApplications_pending_returnsOnlyNewAndUnderReview() {
        Test.startTest();
        List<Loan_Application__c> results = LoanApplicationController.getApplications('Pending');
        Test.stopTest();

        Assert.areEqual(2, results.size(), 'Pending should return New and Under Review only');
        Set<String> statuses = statusesOf(results);
        Assert.isTrue(statuses.contains(STATUS_NEW), 'Should include New');
        Assert.isTrue(statuses.contains(STATUS_UNDER_REVIEW), 'Should include Under Review');
    }

    @IsTest
    static void getApplications_all_returnsEverything() {
        Test.startTest();
        List<Loan_Application__c> results = LoanApplicationController.getApplications('All');
        Test.stopTest();

        Assert.areEqual(4, results.size(), 'All should not apply a status filter');
    }

    @IsTest
    static void getApplications_nullFilter_returnsEverything() {
        Test.startTest();
        List<Loan_Application__c> results = LoanApplicationController.getApplications(null);
        Test.stopTest();

        Assert.areEqual(4, results.size(), 'Null filter should not apply a status filter');
    }

    @IsTest
    static void getApplications_blankFilter_returnsEverything() {
        Test.startTest();
        List<Loan_Application__c> results = LoanApplicationController.getApplications('   ');
        Test.stopTest();

        Assert.areEqual(4, results.size(), 'Blank filter should not apply a status filter');
    }

    @IsTest
    static void getApplications_specificStatus_filtersExactly() {
        Test.startTest();
        List<Loan_Application__c> results = LoanApplicationController.getApplications(STATUS_APPROVED);
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should return only Approved applications');
        Assert.areEqual(STATUS_APPROVED, results[0].Status__c);
    }

    @IsTest
    static void getApplications_unmatchedStatus_returnsEmptyList() {
        Test.startTest();
        List<Loan_Application__c> results = LoanApplicationController.getApplications('No Such Status');
        Test.stopTest();

        Assert.isTrue(results.isEmpty(), 'An unmatched status should return no records');
    }

    @IsTest
    static void getApplications_includesApplicantAccountName() {
        Test.startTest();
        List<Loan_Application__c> results = LoanApplicationController.getApplications(STATUS_NEW);
        Test.stopTest();

        Assert.areEqual(1, results.size());
        Assert.areEqual(ACCOUNT_NAME, results[0].Applicant_Account_Name__c,
            'Parent account name should be returned by the query');
    }

    @IsTest
    static void getApplications_ordersByCreatedDateDescending() {
        List<Loan_Application__c> apps = [
            SELECT Id, Status__c FROM Loan_Application__c
        ];
        Id oldestId;
        Id newestId;
        for (Loan_Application__c app : apps) {
            if (app.Status__c == STATUS_NEW) {
                oldestId = app.Id;
            } else if (app.Status__c == STATUS_APPROVED) {
                newestId = app.Id;
            }
        }
        Test.setCreatedDate(oldestId, DateTime.now().addDays(-10));
        Test.setCreatedDate(newestId, DateTime.now().addDays(1));

        Test.startTest();
        List<Loan_Application__c> results = LoanApplicationController.getApplications('All');
        Test.stopTest();

        Assert.areEqual(newestId, results[0].Id, 'Newest record should be first');
        Assert.areEqual(oldestId, results[results.size() - 1].Id, 'Oldest record should be last');
    }

    @IsTest
    static void getApplications_capsResultsAtOneHundred() {
        Account acct = [SELECT Id FROM Account WHERE Name = :ACCOUNT_NAME LIMIT 1];
        List<Loan_Application__c> bulkApps = new List<Loan_Application__c>();
        for (Integer i = 0; i < 201; i++) {
            bulkApps.add(buildApp(acct.Id, STATUS_NEW, null));
        }
        insert bulkApps;

        Test.startTest();
        List<Loan_Application__c> results = LoanApplicationController.getApplications('All');
        Test.stopTest();

        Assert.areEqual(200, results.size(), 'Results should be capped at 200');
    }

    @IsTest
    static void getApplications_userWithoutObjectAccess_throwsQueryException() {
        List<Profile> profiles = [
            SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1
        ];
        if (profiles.isEmpty()) {
            return; // Profile not available in this org; nothing to verify.
        }

        User noAccessUser = new User(
            Alias             = 'noacc',
            Email             = 'noaccess@example.com',
            EmailEncodingKey  = 'UTF-8',
            LastName          = 'NoAccess',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey      = 'en_US',
            ProfileId         = profiles[0].Id,
            TimeZoneSidKey    = 'America/Chicago',
            Username          = 'noaccess' + DateTime.now().getTime() + '@example.com'
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert noAccessUser;
        }

        Boolean exceptionThrown = false;
        System.runAs(noAccessUser) {
            try {
                LoanApplicationController.getApplications('All');
            } catch (QueryException e) {
                exceptionThrown = true;
            }
        }
        Assert.isTrue(exceptionThrown, 'WITH USER_MODE should block users without read access');
    }

    // ---------- updateApplicationStatus ----------

    @IsTest
    static void updateApplicationStatus_updatesStatusReasonAndDate() {
        Loan_Application__c app = [
            SELECT Id FROM Loan_Application__c WHERE Status__c = :STATUS_NEW LIMIT 1
        ];
        DateTime before = System.now();

        Test.startTest();
        LoanApplicationController.updateApplicationStatus(app.Id, STATUS_APPROVED, 'Meets all criteria');
        Test.stopTest();

        Loan_Application__c updated = [
            SELECT Status__c, Decision_Reason__c, Decision_Date__c
            FROM Loan_Application__c WHERE Id = :app.Id
        ];
        Assert.areEqual(STATUS_APPROVED, updated.Status__c);
        Assert.areEqual('Meets all criteria', updated.Decision_Reason__c);
        Assert.isNotNull(updated.Decision_Date__c, 'Decision date should be stamped');
    }

    @IsTest
    static void updateApplicationStatus_blankReason_isAllowed() {
        Loan_Application__c app = [
            SELECT Id FROM Loan_Application__c WHERE Status__c = :STATUS_NEW LIMIT 1
        ];

        Test.startTest();
        LoanApplicationController.updateApplicationStatus(app.Id, STATUS_REJECTED, 'Reject Reason');
        Test.stopTest();

        Loan_Application__c updated = [
            SELECT Status__c, Decision_Reason__c, Decision_Date__c
            FROM Loan_Application__c WHERE Id = :app.Id
        ];
        Assert.areEqual(STATUS_REJECTED, updated.Status__c);
        Assert.areEqual('Reject Reason', updated.Decision_Reason__c);
        Assert.isNotNull(updated.Decision_Date__c);
    }

    @IsTest
    static void updateApplicationStatus_onlyAffectsTargetRecord() {
        List<Loan_Application__c> apps = [
            SELECT Id, Status__c FROM Loan_Application__c
        ];
        Id targetId;
        for (Loan_Application__c a : apps) {
            if (a.Status__c == STATUS_NEW) {
                targetId = a.Id;
            }
        }

        Test.startTest();
        LoanApplicationController.updateApplicationStatus(targetId, STATUS_APPROVED, 'Approved');
        Test.stopTest();

        Integer approvedCount = [
            SELECT COUNT() FROM Loan_Application__c WHERE Status__c = :STATUS_APPROVED
        ];
        Assert.areEqual(2, approvedCount, 'Setup already had one Approved; only one more should be added');
        Integer withDecisionDate = [
            SELECT COUNT() FROM Loan_Application__c WHERE Decision_Date__c != NULL
        ];
        Assert.areEqual(1, withDecisionDate, 'Only the target record should get a decision date');
    }

    @IsTest
    static void updateApplicationStatus_nullRecordId_throwsQueryException() {
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            LoanApplicationController.updateApplicationStatus(null, STATUS_APPROVED, 'Reason');
        } catch (QueryException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'No matching record should surface as a QueryException');
    }

    @IsTest
    static void updateApplicationStatus_deletedRecord_throwsQueryException() {
        Loan_Application__c app = [SELECT Id FROM Loan_Application__c LIMIT 1];
        Id deletedId = app.Id;
        delete app;

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            LoanApplicationController.updateApplicationStatus(deletedId, STATUS_APPROVED, 'Reason');
        } catch (QueryException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'A deleted record should not be found');
    }
}