# Salesforce Developer - Practical Exercise
Loan Application Review - a working slice of a loan origination app

This application will display Loan Applications on one screen where a loan officer can see the applications on their plate and take action in place.


# Data Model
Loan Application (Loan_Application__c):
- The Applicant Account and Primary Applicant are both lookup relationships.  If we had used a master-detail relationship we are then restricted to the ownership and sharing of the parent which would not be ideal as we want only Loan Officers to be able to manage the Loan Applications.  We also do not want a Loan Application to be deleted when an Account is deleted for any reason.
- Required fields include Applicant Account, Loan Amount, Product and Status as these are key to a Loan Application and will be displayed on the Review Screen.
- Decision Date is a Date/Time field and will be stamped upon Approval or Rejection with the exact time the decision took place.  This date will only be stamped the first time entering a decision.
- Decision Reason will only be required when the Loan Application is Rejected.  When Approving reasoning comments are generally not required as it is an affirmative action but they can optionally be entered.  This will be enforced using a validation rule called "Decision_Reason_Required".
- At this time we don't have differences in picklists or how we display a Loan Application based on Product or some other value so Record Types are not implemented.
- Sharing for the Loan Application will be Private and access to the Loan Application fields and records will be granted through permission sets. 
- A Permission Set Group named "Loan Officer" will be created so we can manage all permissions for users with this job function.  A Permission Set called "Manage Loan Applications" will be created and added to the "Loan Officer" Permission Set group.  This "Manage Loan Applications" permission set will give users read/write access to all Loan Application records/fields and access to run necessary Apex Classes.  Although we only have one permission set for the Loan Officer Permission Set Group right now, we can add more permissions in the future.
- The Loan Application will be "locked" after it has been Approved or Rejected.  This will be enforced using a validation rule called "Approved_Rejected_Locked".  You could also use Apex and addError functionality to lock the record but it is more complex and doesn't offer a clear advantage over validation rules.

# Review Screen
- When the review screen loads the default filter status will be "All Pending" which will include both "New" and "Under Review" loan applications.  The Loan Officers can come here to load which Loan Applications need to be actioned.  The most recently created Loan Applications will display at the top when filtering by any Status.
- The limit of Loan Applications that will load on the Review Screen is set at 200.  For now, this Review Screen would be a place to view the most recent Loan Applications and those that need to be actioned.  More comments on this in the list of items that were intentionally left out.
- Approve and Reject buttons will display for Loan Applications that have not yet had an Approve or Reject decision.  When Loan Applications have already been decisioned these buttons will be greyed out.
- There are summary fields of Total Applications and Total Loan Amount that will sum the Loan Applications that are displayed based on the Status filter selected.
- An App Page was created to display the Loan Application Review lwc and it was added to an App called Longbridge Financial. This decision was made so when users load the app, the Loan Application Review component is the first tab/component they can use.
- To load the Loan Applications, we used @wire because this data is read only and needs to be easily refreshed when the Status Filter changes or a Loan Application is actioned.
- Imperative calls were used to action the loan as we need to perform DML statements.

Items that were intentionally left out due to time constraints that could be future enhancements include:
   - Additional filters (i.e., Product, etc.)
   - Including pagination so all Loan Applications could be loaded using the Review Screen instead of limiting the query to 200.  Pagination is preferred for fast loading time and avoiding having to scroll indefinitely to find Loan Applications.
   - Icons to visually show the status of a loan application
   - Dynamically pull in the Loan Application Status values from the Status picklist values, so if they change the LWC does not have to be updated
   - Highlighting rows or showing additional information when hovering over a loan application line item


# Loan Application Review Screen
Lightning Web Component (loanApplicationReview) Decisions:
- When loading the list of Loan Applications we will default to the 'All Pending' Status Filter, which will show anything in 'New' or 'Under Review' status, focusing on loans that need attention. The most  recently created will be at the top to easily see new loans coming in for processing.
- Retrieving loan application data to display is done using an @wire as we need to be able to refresh it as the Status filter changes and it is read only data.
- RefreshApex is called to refresh the loan data in the @Wire after an action has been performed (approve or reject) or when a Status Filter is changed.  This ensures the user is always seeing accurate data in the datatable.
- Approving and Rejecting a loan application is done imperatively as we need to modify the loan application data.
- Validation to require a Decision Reason is included in the modal when rejecting.  However, as mentioned earlier, there is a validation rule to enforce this validation which is valid regardless which context the records are updated.


# Items that were intentionally left out due to time constraints that should be future enhancements include:
   - Additional filters (i.e., Product, Loan Amount Thresholds, etc.).  A search bar would also be helpful for when users are looking for a particular loan.
   - Icons to visually show the status of a loan application when looking at the All Applications or All Pending status filters.
   - Allow loading of more than 200 loan applications on the Loan Application Review screen.  Pagination would work nicely here so we see the most recent first but the user can optionally click "Next" to get to older applications.
   - Dynamically pull in the Loan Application Status values from the Status picklist values, so if they change the LWC does not have to be updated.
   - Highlighting rows or showing additional information when hovering over a loan application line item.
   - More complete documentation on how to install from this repo.
   - Better documentation and consistency of comments on apex classes and test classes.
   - The web service callout was intentionally left out due to time constraints.  While I could include code, I felt it better to explain my thought process than to include code that I didn't have time to fully test for accuracy.
   - More thought around record ownership and when to assign Loan Applications to a Loan Officer.
   - Instructions and method to seed sample data when installing the application.
   - Storing thresholds in Custom Metadata to ensure Loan Officers cannot approve more than a configurable amount.  We could use Custom Metadata as we can use this in validations rules.
   - Better Error Logs.  Creation of an Error Log object that stores valueable information about callouts and errors.  Also, building in a notification to System Administrators when certain errors occur is a good way to timely notify Administrators of issues.
   - Better testing and completeness of solution!


# Installation Instructions
To install this Salesforce application, you will clone the repository locally and deploy the metadata using the Salesforce CLI.
Permissions:
- Grant Loan Officers the "Loan Officer" Permission Set Group
- Grant System Administrators and Integration Users the "Override Loan Application Lock" Permission Set


# Production-thinking Scenarios
- Two hundrend applications are approved in one Data Loader transaction:  Flows and apex are bulkified so limits will not be breached.
- The underwriting service is unavailable for 30 minutes:  Adding the retry mechanism using Queueable jobs will solve for this as we can add a delay for the queueables.
- An approved application is edited several times after the first notification:  Because we are using a trigger to send the loan application when the status changes to "Approved", it could be sent multiple times to the underwriting system, need to make sure the underwriting system is aware and expects this scenario.
- A loan officer can see a record but lacks permission to update on the decision fields:  Need to ensure the Loan Officer has the correct permission set group assigned and that the loan application has not already been approved or rejected.
- The business later asks for additional approval rules by product and state:  Additional logic can be built into the flows, apex, validation rules, etc. depending on the complexityof these rules.