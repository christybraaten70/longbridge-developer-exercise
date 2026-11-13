# Salesforce Developer - Practical Exercise
Loan Application Review - a working slice of a loan origination app

This application will display Loan Applications on one screen where a loan officer can see the applications on their plate and take action in place.


# Loan Application Decisions
- Stamp and Protect the Decision - When a Loan Application record enters a decision ("Approved" or "Rejected" Status) the Decision Date is stamped using a Record Triggered Flow (Loan Application Before Save Flow).  We use the Before Save as we don't have to perform any DML operations to the record in our process.  Flow is used because of performance, easier maintenance and built-in bulkification.  Note that if an Administrator changes the Status back to a pending status (i.e., "Under Review") and a decision is made again, only the first date a decision was made will be captured because we are checking in the Flow if the Decision Date has already been captured.  This is important so we capture the true first date a decision was made.
Alternatives: We could use a trigger, but it is unnecessarily complex and not as maintainable.
Note:  The requirements were to capture only the Decision Date when a Loan Application enters the "Approved" status but for completeness we are also capturing the Decision Date for the "Rejected" status.  It is possible that a loan could be "Rejected", and Administrator changes it back to a pending status and then a Loan Officer subsequently changes the status to "Approved".  In this scenario we would need to ask the business if they want to keep the first Decision Date, or pivot in this scenario and capture the subsequent "Approved" date since the decision made changed.
- Keep the applicant total accurate - As Loan Applications are "Approved" we need to keep a running total of the Total Approved Loan Amount on the Account.  To do this we are using an Apex Trigger (LoanApplicationTrigger) to run on after insert, after update, after delete and after undelete on the Loan Application object.  Apex was chosen in this scenario because there is no "undelete" for record triggered flows.  This apex trigger handler will run without sharing so even if the running user doesn't have access to some Loan Applications, the total will still be accurate.
Alternatives: We could use a record triggered flow but the undelete scenario would not be covered, resulting in possibly incorrect data.
- Notify underwriting reliably - We need to send "Approved" applications to the underwriting system's REST web service.  Because we cannot perform a callout in a trigger and because we don't want the user waiting for a response from the web service, we use an after update apex trigger to enqueue Queueable apex:
  - Compare Trigger.new with Trigger.oldMap in an after update handler and send all the Ids to Queueable apex that allows callouts (Database.AllowCallouts).
  - A transaction only allows 100 callouts so we need to batch 100 records.
  - If there are failures, you can chain queueables with a delay.
  - Use Named Credentials for the Endpoint.
  - Test Class will use a Mock callout.
  Alternatives: We could use Change Data Capture to run on the Loan Application object and check for a status change of "Approved".  This is reliable and failures can be replayed.
  Note:  This is not included in the package due to time constraints, while I can have Claude write the code, testing and ensuring it is accurate is time consuming.