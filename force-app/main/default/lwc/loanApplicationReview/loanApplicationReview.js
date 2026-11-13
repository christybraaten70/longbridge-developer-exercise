import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getApplications from '@salesforce/apex/LoanApplicationController.getApplications';
import updateApplicationStatus from '@salesforce/apex/LoanApplicationController.updateApplicationStatus';

const COLUMNS = [
    { label: 'Loan Application Number', fieldName: 'Name', type: 'text' },
    { label: 'Status', fieldName: 'Status__c', type: 'text', initialWidth: 120 },
    { label: 'Applicant Account', fieldName: 'Applicant_Account_Name__c', type: 'text' },    
    { label: 'Product', fieldName: 'Product__c', type: 'text' },
    { label: 'Loan Amount', fieldName: 'Loan_Amount__c', type: 'currency', initialWidth: 140, typeAttributes: {
            currencyCode: 'USD',
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        }
    },
    {
        type: 'button',
        label: 'Approve',
        initialWidth: 110,
        typeAttributes: {
            label: 'Approve',
            name: 'approve',
            title: 'Approve Application',
            variant: 'success',
            disabled: { fieldName: 'isActionDisabled' }
        }
    },
    {
        type: 'button',
        label: 'Reject',
        initialWidth: 100,
        typeAttributes: {
            label: 'Reject',
            name: 'reject',
            title: 'Reject Application',
            variant: 'destructive',
            disabled: { fieldName: 'isActionDisabled' }
        }
    }
];

export default class ApplicationReview extends LightningElement {
    columns = COLUMNS;
    selectedStatus = 'Pending';  //Default status will display any loans that are not already been approved or rejected
    applications = [];
    wiredAppsResult;  //Wired result that can be refreshed programmatically
    isLoading = false;
    isEmpty = false;

    // Modal variables
    isModalOpen = false;
    selectedRecordId;
    pendingAction; // 'Approved' or 'Rejected'
    decisionReason = '';

    statusOptions = [
        { label: 'All Applications', value: 'All' },
        { label: 'All Pending', value: 'Pending' },        
        { label: 'New', value: 'New' },
        { label: 'Under Review', value: 'Under Review' },
        { label: 'Approved', value: 'Approved' },
        { label: 'Rejected', value: 'Rejected' }
    ];    

    @wire(getApplications, { statusFilter: '$selectedStatus' })
    applications(result) {
        console.log('wired call');
;        this.wiredAppsResult = result;
        const { data, error } = result;
        if (data) {
            if (data.length > 0) {
                // Disable buttons if already Approved or Rejected
                this.applications = data.map(row => ({
                    ...row,
                    isActionDisabled: row.Status__c === 'Approved' || row.Status__c === 'Rejected'
                }));
                this.isEmpty = false;
            } else {
                this.applications = [];
                this.isEmpty = true;
            }
        } else if (error) {
            this.applications = [];
            this.isEmpty = true;
        }        
    }

     // Modal Dynamic Properties
    get modalTitle() {
        return this.pendingAction === 'Approved' ? 'Approve Loan Application' : 'Reject Loan Application';
    }

    get confirmButtonLabel() {
        return this.pendingAction === 'Approved' ? 'Confirm Approval' : 'Confirm Rejection';
    }

    get confirmButtonVariant() {
        return this.pendingAction === 'Approved' ? 'success' : 'destructive';
    }

    get isCommentRequired() {
        // Require comments for rejections, optional for approvals
        return this.pendingAction === 'Rejected';
    }

    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
        refreshApex(this.wiredAppsResult);
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        this.selectedRecordId = row.Id;
        this.pendingAction = actionName === 'approve' ? 'Approved' : 'Rejected';
        this.decisionReason = '';
        this.isModalOpen = true;
    }

    handleCommentChange(event) {
        this.decisionReason = event.detail.value;
    }

    closeModal() {
        this.isModalOpen = false;
        this.selectedRecordId = null;
        this.pendingAction = '';
        this.decisionReason = '';
    }

    async handleConfirmAction() {
        // Validate required comment field
        const textarea = this.template.querySelector('lightning-textarea');
        if (!textarea.reportValidity()) {
            return;
        }

        this.isLoading = true;
        try {
            await updateApplicationStatus({
                recordId: this.selectedRecordId,
                newStatus: this.pendingAction,
                reason: this.decisionReason
            });

            this.showToast('Success', `Loan application ${this.pendingAction.toLowerCase()}.`, 'success');
            this.closeModal();
            await refreshApex(this.wiredAppsResult);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to update loan status.', 'error');
        } finally {
            this.isLoading = false;
        }
    }


   // Dynamic Summary Total Applications
    get summaryCount() {
        return this.applications.length;
    }

    // Dynamic Summary Loan Amount
    get summaryTotal() {
        return this.applications.reduce((total, loan) => {
            return total + (loan.Loan_Amount__c || 0);
        }, 0);
    }   

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}