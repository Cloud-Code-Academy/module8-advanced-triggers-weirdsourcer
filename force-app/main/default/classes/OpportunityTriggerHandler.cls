public with sharing class OpportunityTriggerHandler extends TriggerHandler {
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