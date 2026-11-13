/**
 * @description       : Tests for LoanApplicationTriggerHandler
 * @last modified on  : 11/12/2026
 **/
@IsTest
private class LoanApplicationTriggerHandlerTest {

    @TestSetup
    static void setup() {
        insert new List<Account>{
            new Account(Name = 'Acme'),
            new Account(Name = 'Globex')
        };
    }

    private static Account getAccount(String name) {
        return [SELECT Id FROM Account WHERE Name = :name LIMIT 1];
    }

    private static Decimal total(String name) {
        Account a = [
            SELECT Total_Approved_Loan_Amount__c FROM Account WHERE Name = :name LIMIT 1
        ];
        return a.Total_Approved_Loan_Amount__c == null ? 0 : a.Total_Approved_Loan_Amount__c;
    }

    // NOTE: add any other required fields on Loan_Applicant__c here.
    private static Loan_Application__c newLoan(Id accountId, Decimal amount, String status) {
        return new Loan_Application__c(
            Applicant_Account__c = accountId,
            Loan_Amount__c = amount,
            Status__c = status,
            Product__c = 'HELOC'
        );
    }

    // ---- tests ----------------------------------------------------------

    @IsTest
    static void insertApproved_addsToTotal_andIgnoresNonApproved() {
        Id acmeId = getAccount('Acme').Id;

        Test.startTest();
        insert new List<Loan_Application__c>{
            newLoan(acmeId, 1000, 'Approved'),
            newLoan(acmeId, 250, 'Approved'),
            newLoan(acmeId, 500, 'Under Review')
        };
        Test.stopTest();

        Assert.areEqual(1250, total('Acme'));
    }

    @IsTest
    static void updateToApproved_addsToTotal() {
        Loan_Application__c loan = newLoan(getAccount('Acme').Id, 500, 'Under Review');
        insert loan;
        Assert.areEqual(0, total('Acme'));

        Test.startTest();
        loan.Status__c = 'Approved';
        update loan;
        Test.stopTest();

        Assert.areEqual(500, total('Acme'));
    }

    @IsTest
    static void approvalWithAmountAndAccountChange_updatesBothAccounts() {
        Id acmeId = getAccount('Acme').Id;
        Id globexId = getAccount('Globex').Id;
        Loan_Application__c loan = newLoan(acmeId, 500, 'Under Review');
        insert loan;

        Test.startTest();
        loan.Status__c = 'Approved';
        loan.Loan_Amount__c = 700;
        loan.Applicant_Account__c = globexId;
        update loan;
        Test.stopTest();

        Assert.areEqual(0, total('Acme'));
        Assert.areEqual(700, total('Globex'));
    }

    @IsTest
    static void deleteApproved_subtractsFromTotal() {
        Id acmeId = getAccount('Acme').Id;
        Loan_Application__c keep = newLoan(acmeId, 300, 'Approved');
        Loan_Application__c remove = newLoan(acmeId, 1000, 'Approved');
        insert new List<Loan_Application__c>{ keep, remove };
        Assert.areEqual(1300, total('Acme'));

        Test.startTest();
        delete remove;
        Test.stopTest();

        Assert.areEqual(300, total('Acme'));
    }

    @IsTest
    static void undeleteApproved_restoresTotal() {
        Loan_Application__c loan = newLoan(getAccount('Acme').Id, 1000, 'Approved');
        insert loan;
        delete loan;
        Assert.areEqual(0, total('Acme'));

        Test.startTest();
        undelete [SELECT Id FROM Loan_Application__c WHERE Id = :loan.Id ALL ROWS];
        Test.stopTest();

        Assert.areEqual(1000, total('Acme'));
    }

    @IsTest
    static void bulkInsertAcrossAccounts_isCorrect() {
        Id acmeId = getAccount('Acme').Id;
        Id globexId = getAccount('Globex').Id;

        List<Loan_Application__c> loans = new List<Loan_Application__c>();
        for (Integer i = 0; i < 200; i++) {
            loans.add(newLoan(Math.mod(i, 2) == 0 ? acmeId : globexId, 100, 'Approved'));
        }

        Test.startTest();
        insert loans;
        Test.stopTest();

        Assert.areEqual(10000, total('Acme'));
        Assert.areEqual(10000, total('Globex'));

        // Bulk delete
        delete loans;
        Assert.areEqual(0, total('Acme'));
        Assert.areEqual(0, total('Globex'));
    }
}