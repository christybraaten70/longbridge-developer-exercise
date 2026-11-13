/**
 * @description       : Controller for the loanApplicationReview LWC
 * @author            : Christy Braaten
 * @last modified on  : 11/12/2026
 * @last modified by  : Christy Braaten
 **/
public with sharing class LoanApplicationController {
    
    @AuraEnabled(cacheable=true)
    public static List<Loan_Application__c> getApplications(String statusFilter) {
        String query = 'SELECT Id, Name, Applicant_Account_Name__c, Loan_Amount__c, Product__c, Status__c FROM Loan_Application__c';
        
        if (statusFilter == 'Pending') {
            List<String> pendingFilters = new List<String> {'New','Under Review'};
            query += ' WHERE Status__c IN :pendingFilters';
        } else if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
            query += ' WHERE Status__c = :statusFilter';
        }
        query += ' WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 200';
        return Database.query(query);                
    }

    @AuraEnabled
    public static void updateApplicationStatus(String recordId, String newStatus, String reason) {
        Loan_Application__c app = [SELECT Id FROM Loan_Application__c WHERE Id = :recordId LIMIT 1];
        app.Status__c = newStatus;
        app.Decision_Reason__c = reason;
        update as user app;
    }
}