public with sharing class OpportunityTriggerHandler extends TriggerHandler {
    /*
    Typically when using a Framework, you will do something like this rather than continuing to pass the Trigger.new, etc. through to the next class.
    
    private List<Opportunity> newOppList;
	private Map<Id, Opportunity> newOppMap;
	private List<Opportunity> oldOppList;
	private Map<Id, Opportunity> oldOppMap;

	public OpportunityTriggerHandler() {
	    this.newOppList = (List<Opportunity>) Trigger.new;
	    this.newOppMap = (Map<Id, Opportunity>) Trigger.newMap;
	    this.oldOppList = (List<Opportunity>) Trigger.old;
	    this.oldOppMap = (Map<Id, Opportunity>) Trigger.oldMap;
	}

    Then you won't need to cast in the opportunityTriggerHelper Class if you do something like

    public override void beforeUpdate() {
        OpportunityTriggerHelper.validateAmount(newOppList);
        OpportunityTriggerHelper.setPrimaryContactToCEO(newOppList);
        OpportunityTriggerHelper.appendDescriptionWithStageChanges(newOppList, Trigger.oldMap);
    }

    */

    public override void beforeUpdate() {
        OpportunityTriggerHelper.validateAmount(Trigger.new);
        OpportunityTriggerHelper.setPrimaryContactToCEO(Trigger.new);
        OpportunityTriggerHelper.appendDescriptionWithStageChanges(Trigger.new, Trigger.oldMap);
    }

    public override void beforeDelete() {
        OpportunityTriggerHelper.preventBankingClosedWonOppDeletion(Trigger.old);
        OpportunityTriggerHelper.preventClosedWonOppsDeleted(Trigger.old);
    }
    
    public override void beforeInsert() {
        OpportunityTriggerHelper.setOppDefaultType(Trigger.new);
    }

    public override void afterInsert() {
        OpportunityTriggerHelper.createTaskForNewOpps(Trigger.new);
    }


    public override void afterDelete() {
        OpportunityTriggerHelper.sendEmailOnOppDel(Trigger.old);
    }

    public override void afterUndelete() {
        OpportunityTriggerHelper.assignPrimaryCon(Trigger.newMap);
    }
}