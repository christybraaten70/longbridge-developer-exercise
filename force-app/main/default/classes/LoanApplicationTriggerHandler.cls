/**
 * Keeps Account.Total_Approved_Loan_Amount__c equal to the sum of
 * Loan_Application__c.Loan_Amount__c where Status__c = 'Approved'.
 *
 * Runs without sharing so the total always reflects ALL approved loans on the
 * account, regardless of what the running user can see.
 *
 * Strategy: collect affected account Ids, then fully recalculate each one with a
 * single aggregate query. Recalculating (rather than applying +/- deltas) makes
 * the total self-healing.
 */
public without sharing class LoanApplicationTriggerHandler {
 
    private static final String APPROVED = 'Approved';
 
    public static void handleAfterInsert(List<Loan_Application__c> newRecords) {
        Set<Id> accountIds = new Set<Id>();
        for (Loan_Application__c loan : newRecords) {
            if (isApproved(loan)) {
                addId(accountIds, loan.Applicant_Account__c);
            }
        }
        recalculate(accountIds);
    }
 
    public static void handleAfterUpdate(
        List<Loan_Application__c> newRecords,
        Map<Id, Loan_Application__c> oldMap
    ) {
        Set<Id> accountIds = new Set<Id>();
        for (Loan_Application__c newLoan : newRecords) {
            Loan_Application__c oldLoan = oldMap.get(newLoan.Id);
 
            // Only matters if the loan is, or was, approved.
            if (!isApproved(newLoan) && !isApproved(oldLoan)) {
                continue;
            }
 
            Boolean relevantChange =
                newLoan.Status__c != oldLoan.Status__c ||
                newLoan.Loan_Amount__c != oldLoan.Loan_Amount__c ||
                newLoan.Applicant_Account__c != oldLoan.Applicant_Account__c;
 
            if (relevantChange) {
                addId(accountIds, newLoan.Applicant_Account__c);
                addId(accountIds, oldLoan.Applicant_Account__c); // covers reparenting
            }
        }
        recalculate(accountIds);
    }
 
    public static void handleAfterDelete(List<Loan_Application__c> oldRecords) {
        Set<Id> accountIds = new Set<Id>();
        for (Loan_Application__c loan : oldRecords) {
            if (isApproved(loan)) {
                addId(accountIds, loan.Applicant_Account__c);
            }
        }
        recalculate(accountIds);
    }
 
    public static void handleAfterUndelete(List<Loan_Application__c> restoredRecords) {
        Set<Id> accountIds = new Set<Id>();
        for (Loan_Application__c loan : restoredRecords) {
            if (isApproved(loan)) {
                addId(accountIds, loan.Applicant_Account__c);
            }
        }
        recalculate(accountIds);
    }
 
    // ---------------------------------------------------------------------
 
    private static void recalculate(Set<Id> accountIds) {
        if (accountIds.isEmpty()) {
            return;
        }
 
        // Default every affected account to 0 so accounts that no longer have
        // any approved loans are reset (the aggregate returns no row for them).
        Map<Id, Decimal> totals = new Map<Id, Decimal>();
        for (Id accountId : accountIds) {
            totals.put(accountId, 0);
        }
 
        for (AggregateResult ar : [
            SELECT Applicant_Account__c acct, SUM(Loan_Amount__c) totalAmt
            FROM Loan_Application__c
            WHERE Applicant_Account__c IN :accountIds
              AND Status__c = :APPROVED
            GROUP BY Applicant_Account__c
        ]) {
            Decimal sumAmt = (Decimal) ar.get('totalAmt');
            totals.put((Id) ar.get('acct'), sumAmt == null ? 0 : sumAmt);
        }
 
        // Only update accounts whose value actually changes. ORDER BY Id keeps
        // lock acquisition order consistent across concurrent transactions.
        List<Account> toUpdate = new List<Account>();
        for (Account acct : [
            SELECT Id, Total_Approved_Loan_Amount__c
            FROM Account
            WHERE Id IN :accountIds
            ORDER BY Id
        ]) {
            Decimal newTotal = totals.get(acct.Id);
            if (acct.Total_Approved_Loan_Amount__c == null
                || acct.Total_Approved_Loan_Amount__c != newTotal) {
                acct.Total_Approved_Loan_Amount__c = newTotal;
                toUpdate.add(acct);
            }
        }
 
        if (!toUpdate.isEmpty()) {
            Database.update(toUpdate, AccessLevel.SYSTEM_MODE);
        }
    }
 
    private static Boolean isApproved(Loan_Application__c loan) {
        return loan.Status__c == APPROVED;
    }
 
    private static void addId(Set<Id> ids, Id value) {
        if (value != null) {
            ids.add(value);
        }
    }
}