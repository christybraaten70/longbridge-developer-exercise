trigger LoanApplicationTrigger on Loan_Application__c (after insert, after update, after delete, after undelete) {
    switch on Trigger.operationType {
        when AFTER_INSERT {
            LoanApplicationTriggerHandler.handleAfterInsert(Trigger.new);
        }
        when AFTER_UPDATE {
            LoanApplicationTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
        when AFTER_DELETE {
            LoanApplicationTriggerHandler.handleAfterDelete(Trigger.old);
        }
        when AFTER_UNDELETE {
            LoanApplicationTriggerHandler.handleAfterUndelete(Trigger.new);
        }
    }
}