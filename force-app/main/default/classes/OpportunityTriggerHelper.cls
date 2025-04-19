public with sharing class OpportunityTriggerHelper {
    /*
    * Opportunity Trigger
    * When an opportunity is updated validate that the amount is greater than 5000.
    * Trigger should only fire on update.
    */
    public static void validateAmount(List<SObject> newOpps){
        for (Opportunity opp : (List<Opportunity>) newOpps){
            if(opp.Amount < 5000){
                opp.addError('Opportunity amount must be greater than 5000');
            }
        }
    }

    /*
   * Opportunity Trigger
   * When an opportunity is deleted prevent the deletion of a closed won opportunity if the account industry is 'Banking'.
   * Trigger should only fire on delete.
   */
    public static void preventBankingClosedWonOppDeletion(List<SObject> oldOpps) {
       Map<Id, Account> accounts = new Map<Id, Account>([SELECT Id, Industry FROM Account WHERE Id IN (SELECT AccountId FROM Opportunity WHERE Id IN :oldOpps)]);
       for (Opportunity opp : (List<Opportunity>) oldOpps) {
           if(opp.StageName == 'Closed Won') {
               if(accounts.get(opp.AccountId).Industry == 'Banking') {
                   opp.addError('Cannot delete a closed won opportunity for a banking account');
               }
           }
       }
    }

    /*
    * Opportunity Trigger
    * When an opportunity is updated set the primary contact on the opportunity to the contact with the title of 'CEO'.
    * Trigger should only fire on update.
    */
    public static void setPrimaryContactToCEO(List<SObject> newOpps) {
    
        //Get contacts related to the opportunity account
        Set<Id> accountIds = new Set<Id>();
        for(Opportunity opp : (List<Opportunity>) newOpps){
            accountIds.add(opp.AccountId);
        }
       
       Map<Id, Contact> contacts = new Map<Id, Contact>([SELECT Id, FirstName, AccountId FROM Contact WHERE AccountId IN :accountIds AND Title = 'CEO' ORDER BY FirstName ASC]);
       Map<Id, Contact> accountIdToContact = new Map<Id, Contact>();

       for (Contact cont : contacts.values()) {
           if (!accountIdToContact.containsKey(cont.AccountId)) {
               accountIdToContact.put(cont.AccountId, cont);
           }
       }

       for (Opportunity opp : (List<Opportunity>) newOpps){
           if(opp.Primary_Contact__c == null){
               if (accountIdToContact.containsKey(opp.AccountId)){
                   opp.Primary_Contact__c = accountIdToContact.get(opp.AccountId).Id;
               }
           }
       }
    }

     // Set default Type for new Opportunities
    public static void setOppDefaultType(List<SObject> newOpps) {
        for (Opportunity opp : (List<Opportunity>) newOpps) {
            if (opp.Type == null){
                opp.Type = 'New Customer';
            }  
        }
    }

    // Prevent deletion of closed Opportunities
    public static void preventClosedWonOppsDeleted(List<SObject> oldOpps) {
        for (Opportunity opp : (List<Opportunity>) oldOpps) {
            if (opp.IsClosed) {
                opp.addError('Cannot delete closed opportunity');
            }
        }
    }

    // Create a new Task for newly inserted Opportunities
    public static void createTaskForNewOpps(List<SObject> newOpps) {
        List<Task> tskToInsert = new List<Task>();

        for (Opportunity opp : (List<Opportunity>) newOpps){
            Task tsk = new Task();
            tsk.Subject = 'Call Primary Contact';
            tsk.WhatId = opp.Id;
            tsk.WhoId = opp.Primary_Contact__c;
            tsk.OwnerId = opp.OwnerId;
            tsk.ActivityDate = Date.today().addDays(3);
            tskToInsert.add(tsk);
        }
        Database.insert(tskToInsert, AccessLevel.SYSTEM_MODE);
    }

    // Append Stage changes in Opportunity Description
    public static void appendDescriptionWithStageChanges(List<SObject> newOpps, Map<Id, SObject> oldOppsMap) {
        //List<Opportunity> opps = (List<Opportunity>) newOpps;
        //Map<Id, Opportunity> oldOpps = (Map<Id, Opportunity>) oldOppsMap;
        for (Opportunity opp : (List<Opportunity>) newOpps) {
            Opportunity oldOpp = (Opportunity) oldOppsMap.get(opp.Id);
            if (opp.StageName != null && opp.StageName != oldOpp.StageName){
                opp.Description += '\n Stage Change:' + opp.StageName + ':' + DateTime.now().format();
            //opps.add(opp);
            }               
        }

        //update opps;
        //Database.update(opps, AccessLevel.SYSTEM_MODE);
    }

    // Send email notifications when an Opportunity is deleted 
    public static void sendEmailOnOppDel(List<SObject> oldOpps) {
        notifyOwnersOpportunityDeleted((List<Opportunity>) oldOpps);
    }

    // Assign the primary contact to undeleted Opportunities
    public static void assignPrimaryCon(Map<Id, SObject> newOppsMap) {
        Map<Id, Opportunity> oppsMap = (Map<Id, Opportunity>) newOppsMap;
        assignPrimaryContact(oppsMap);
    }

    /*
    notifyOwnersOpportunityDeleted:
    - Sends an email notification to the owner of the Opportunity when it gets deleted.
    - Uses Salesforce's Messaging.SingleEmailMessage to send the email.
    */
    private static void notifyOwnersOpportunityDeleted(List<Opportunity> opps) {
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        //Map<Id, User> oppIdToOwner = new Map<Id, User>();
        //for (Opportunity opp : opps){
        //    oppIdToOwner.put(opp.Id, opp.OwnerId)
        //}
        Map<Id, Opportunity> oppsIdToOpp = new Map<Id, Opportunity>(opps);
        List<Opportunity> extractedOpps = [SELECT Id, Name, Owner.Email FROM Opportunity WHERE Id IN :oppsIdToOpp.keyset() WITH SYSTEM_MODE];

        for (Opportunity opp : extractedOpps){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            //String[] toAddresses = new String[] {[SELECT Id, Email FROM User WHERE Id = :opp.OwnerId].Email};
            mail.setToAddresses(new String[] {opp.Owner.Email});
            mail.setSubject('Opportunity Deleted : ' + opp.Name);
            mail.setPlainTextBody('Your Opportunity: ' + opp.Name +' has been deleted.');
            mails.add(mail);
        }        
        
        try {
            Messaging.sendEmail(mails);
        } catch (Exception e){
            System.debug('Exception: ' + e.getMessage());
        }
    }


    /*
    assignPrimaryContact:
    - Assigns a primary contact with the title of 'VP Sales' to undeleted Opportunities.
    - Only updates the Opportunities that don't already have a primary contact.
    */
    private static void assignPrimaryContact(Map<Id, Opportunity> oppNewMap) {        
        // Get Account IDs from Opportunities
        Map<Id, Id> oppIdToAccId = new Map<Id, Id>();
            for (Opportunity opp : oppNewMap.values()){
                if(opp.AccountId != null) {
                    oppIdToAccId.put(opp.Id, opp.AccountId);
                }
            }
        
        // Query VP Sales contacts
            List<Contact> primaryContact = [
                SELECT Id, AccountId
                FROM Contact
                WHERE Title = 'VP Sales' AND AccountId IN :oppIdToAccId.values()
                WITH SYSTEM_MODE
            ];

            // Map Account to Contact
            Map<Id, Id> accIdToConId = new Map<Id,Id>();
            for (Contact con : primaryContact) {
                if(!accIdToConId.containsKey(con.AccountId)) {
                    accIdToConId.put(con.AccountId, con.Id);
                }            
            }

            // Update Opportunities
            Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>();
                for (Opportunity opp : oppNewMap.values()){            
                    //Contact primaryContact = [SELECT Id, AccountId FROM Contact WHERE Title = 'VP Sales' AND AccountId = :opp.AccountId LIMIT 1];
                    if (opp.Primary_Contact__c == null && accIdToConId.containsKey(opp.AccountId)){
                        Opportunity oppToUpdate = new Opportunity(Id = opp.Id);
                        oppToUpdate.Primary_Contact__c = accIdToConId.get(opp.AccountId);
                        oppMap.put(opp.Id, oppToUpdate);
                    }
                }
            update oppMap.values();
    }
        
}