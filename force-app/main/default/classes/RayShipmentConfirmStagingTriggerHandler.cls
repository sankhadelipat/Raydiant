/**
* @File Name          : RayShipmentConfirmStagingTriggerHandler.apxt
* @Description        : Handler Class for RayShipmentConfirmStagingTrigger.
*/
public class RayShipmentConfirmStagingTriggerHandler {
    public static void entry(TriggerParams triggerParams) {
        List<Ray_Shipment_Confirmation_Staging__c> listOldRayShipmentConfirmStags = (List<Ray_Shipment_Confirmation_Staging__c>) triggerParams.triggerOld;
        List<Ray_Shipment_Confirmation_Staging__c> listNewRayShipmentConfirmStags = (List<Ray_Shipment_Confirmation_Staging__c>) triggerParams.triggerNew;
        Map<Id, Ray_Shipment_Confirmation_Staging__c> mapOldRayShipmentConfirmStags = (Map<Id, Ray_Shipment_Confirmation_Staging__c>) triggerParams.oldMap;
        Map<Id, Ray_Shipment_Confirmation_Staging__c> mapNewRayShipmentConfirmStags = (Map<Id, Ray_Shipment_Confirmation_Staging__c>) triggerParams.newMap;
        System.debug('newMap: ' + triggerParams.newMap);
        if(triggerParams.isAfter) {
            if(triggerParams.isInsert||triggerParams.IsUpdate) {
                createRelatedRecords(mapNewRayShipmentConfirmStags);
            }
        }
    }
    
    private static void createRelatedRecords(Map<Id, Ray_Shipment_Confirmation_Staging__c> mapNewRayShipmentConfirmStags) {
        // Validation on field Status (Start).
        List<Ray_Shipment_Confirmation_Staging__c> listRayShipmentConfirmStags = validateOnStatus(mapNewRayShipmentConfirmStags.keySet());
        // Validation on field Status (End).
        
        // Validation on duplicates (Start).
        Set<String> setMacAddresses = new Set<String>();
        Set<String> setOrderNumbers = new Set<String>();
        Set<String> setCoreProdNames = new Set<String>();
        Set<String> setIds = new Set<String>();
        
        // Update Order Products (Start).
        Map<id, Ray_Shipment_Confirmation_Staging__c> mapUpdatedRayShipmentConfirmStags = new Map<id, Ray_Shipment_Confirmation_Staging__c>();
        List<Ray_Shipment_Confirmation_Staging__c> listErrorRayShipmentConfirmStags = new List<Ray_Shipment_Confirmation_Staging__c>();
        List<OrderItem> listNewOrderItems = new List<OrderItem>();
        Map<String, OrderItem> mapOldOrderItems = new Map<String, OrderItem>();
        System.debug('listRayShipmentConfirmStags: ' + listRayShipmentConfirmStags);
        String orderNumb;
        for(Ray_Shipment_Confirmation_Staging__c rayShipmentConfirmStag : listRayShipmentConfirmStags) {
            setMacAddresses.add(rayShipmentConfirmStag.RAY_MAC_Address__c);
            orderNumb = rayShipmentConfirmStag.RAY_Order_Number_Text__c;
            System.debug('orderNumb: ' + orderNumb);
            System.debug('subs: ' + orderNumb.substring(0,3));
            if(orderNumb.substring(0,3) == 'CPQ'){
                System.debug('here');
                orderNumb = orderNumb.substring(3);
                rayShipmentConfirmStag.RAY_Order_Number_Text__c = orderNumb;
                mapUpdatedRayShipmentConfirmStags.put(rayShipmentConfirmStag.id, rayShipmentConfirmStag);
            }
            System.debug('orderNumb2: ' + orderNumb);
            setOrderNumbers.add(orderNumb);
            //setOrderNumbers.add(rayShipmentConfirmStag.RAY_Order_Number_Text__c);
            setCoreProdNames.add(rayShipmentConfirmStag.RAY_WCA_Product_Name__c);
            
            System.debug('rayShipmentConfirmStag.RAY_Order_Number_Text__c: ' + rayShipmentConfirmStag.RAY_Order_Number_Text__c);
            System.debug('rayShipmentConfirmStag.RAY_Core_Product_Name__c: ' + rayShipmentConfirmStag.RAY_Core_Product_Name__c);
            
            setIds.add(rayShipmentConfirmStag.Id);
        }
        Map<String, Map<String, Map<String, String>>> mapDuplicateRayShipmentConfirmStags = getMapDuplicateRayShipmentConfirmStags(setMacAddresses, setOrderNumbers, setCoreProdNames, setIds);
        Map<String, Map<String, String>> mapDuplicateAssets = getMapDuplicateAssets(setMacAddresses, setOrderNumbers);
        Map<String, Map<String, OrderItem>> mapOrderItems = getMapOrderItems(setOrderNumbers, setCoreProdNames);
        // Validation on duplicates (End).
        System.debug('herre: ' + mapOrderItems);
        
        
        
        Map<String, List<Ray_Shipment_Confirmation_Staging__c>> mapRayShipmentConfirmStagsForError = new Map<String, List<Ray_Shipment_Confirmation_Staging__c>>();
        Map<String, List<Ray_Shipment_Confirmation_Staging__c>> mapRayShipmentConfirmStagsForAsset = new Map<String, List<Ray_Shipment_Confirmation_Staging__c>>();
        
        for(Ray_Shipment_Confirmation_Staging__c rayShipmentConfirmStag : listRayShipmentConfirmStags) { 
            String macAddress = rayShipmentConfirmStag.RAY_MAC_Address__c;
            String orderNumber = rayShipmentConfirmStag.RAY_Order_Number_Text__c;
            String coreProductName;
            String errorMessage = '';
            
            //if(rayShipmentConfirmStag.RAY_Core_Product_Name__c == null){
            System.debug('RAY_Core_Product_Name__c is null');
            Map<String, OrderItem> orderItemsGroupedByProductName = mapOrderItems.get(rayShipmentConfirmStag.RAY_Order_Number_Text__c);
            try{
                Set<String> productNames = orderItemsGroupedByProductName.keySet();
                rayShipmentConfirmStag.RAY_Core_Product_Name__c = (new list<string>(productNames)).get(0); 
                coreProductName = (new list<string>(productNames)).get(0);
            }catch(Exception e){
                System.debug('No matching Order Product found; ');
            }
            if(!mapUpdatedRayShipmentConfirmStags.containsKey(rayShipmentConfirmStag.Id)){
                mapUpdatedRayShipmentConfirmStags.put(rayShipmentConfirmStag.Id, rayShipmentConfirmStag);
            }else{
                mapUpdatedRayShipmentConfirmStags.remove(rayShipmentConfirmStag.Id);
                mapUpdatedRayShipmentConfirmStags.put(rayShipmentConfirmStag.Id, rayShipmentConfirmStag);
            }
            //}else{
            //coreProductName = rayShipmentConfirmStag.RAY_Core_Product_Name__c;
            //}
            
            
            if(mapDuplicateRayShipmentConfirmStags.containsKey(macAddress) && mapDuplicateRayShipmentConfirmStags.get(macAddress).containsKey(orderNumber) && mapDuplicateRayShipmentConfirmStags.get(macAddress).get(orderNumber).containsKey(coreProductName)) {
                errorMessage += 'Duplicate Shipment record found in the Staging object - ' 
                    + mapDuplicateRayShipmentConfirmStags.get(macAddress).get(orderNumber).get(coreProductName) + ' ; ';
            }
            
            if(mapDuplicateAssets.containsKey(macAddress) && mapDuplicateAssets.get(macAddress).containsKey(orderNumber)) {
                errorMessage += 'Asset already exists with matching MAC address ' + macAddress + ' and Order# ' + orderNumber + ' - Possible duplicate record; ';
            }
            
            System.debug('mapOrderItems.containsKey(orderNumber): ' + mapOrderItems.containsKey(orderNumber));
            System.debug('mapOrderItems: ' + mapOrderItems);
            //System.debug('mapOrderItems.get(orderNumber).containsKey(coreProductName): ' + mapOrderItems.get(orderNumber).containsKey(coreProductName));
            System.debug('mapOrderItems.get(orderNumber): ' + mapOrderItems.get(orderNumber));
            
            System.debug('coreProductName: ' + coreProductName);
            System.debug('mapOrderItems.containsKey(orderNumber): ' + mapOrderItems.containsKey(orderNumber));
            System.debug('mapOrderItems.get(orderNumber)' + mapOrderItems.get(orderNumber));
            //System.debug('mapOrderItems.get(orderNumber).containsKey(coreProductName): ' + mapOrderItems.get(orderNumber).containsKey(coreProductName));
            
            if(!mapOrderItems.containsKey(orderNumber) || !mapOrderItems.get(orderNumber).containsKey(coreProductName)) {
                errorMessage += 'No matching Order Product found or it has been already shipped; ';
            } 
            
            if(String.isBlank(errorMessage)) {
                rayShipmentConfirmStag.RAY_Status__c = 'Processing';
                rayShipmentConfirmStag.RAY_Error_Message__c = '';
                
                OrderItem orderItemOld = mapOrderItems.get(orderNumber).get(coreProductName);
                mapOldOrderItems.put(orderItemOld.Id, orderItemOld);
                
                String orderItemId = mapOrderItems.get(orderNumber).get(coreProductName).Id;
                
                OrderItem orderItemNew = mapOrderItems.get(orderNumber).get(coreProductName);
                orderItemNew.F52_Shipped_Quantity__c = String.isBlank(String.valueOf(orderItemNew.F52_Shipped_Quantity__c)) ? 1 : ++orderItemNew.F52_Shipped_Quantity__c;
                orderItemNew.F52_Ship_Date__c = rayShipmentConfirmStag.RAY_Ship_Date__c;
                orderItemNew.F52_Carrier_Service__c = rayShipmentConfirmStag.RAY_Carrier_Service__c;
                
                String shipTracking = String.isBlank(orderItemNew.F52_Shipment_Tracking__c) ? '' : String.valueOf(orderItemNew.F52_Shipment_Tracking__c + ' ; ');
                String trackingNumber = String.isBlank(rayShipmentConfirmStag.RAY_Tracking_Number__c) ? '' : String.valueOf(rayShipmentConfirmStag.RAY_Tracking_Number__c + ' ; ');
                
                if(shipTracking.contains(trackingNumber)){
                    orderItemNew.F52_Shipment_Tracking__c = shipTracking;
                }else{
                    orderItemNew.F52_Shipment_Tracking__c = shipTracking + trackingNumber;
                }
                
                listNewOrderItems.add(orderItemNew);
                try{
                    rayShipmentConfirmStag.RAY_Order_number__c = mapOrderItems.get(orderNumber).get(coreProductName).OrderId;
                    rayShipmentConfirmStag.RAY_Order_Product__c = orderItemId;
                }catch(Exception e){
                    rayShipmentConfirmStag.RAY_Status__c = 'Error';
                    rayShipmentConfirmStag.RAY_Error_Message__c = 'There is no order';
                }
                
                if(!mapUpdatedRayShipmentConfirmStags.containsKey(rayShipmentConfirmStag.Id)){
                    mapUpdatedRayShipmentConfirmStags.put(rayShipmentConfirmStag.Id, rayShipmentConfirmStag);
                }else{
                    mapUpdatedRayShipmentConfirmStags.remove(rayShipmentConfirmStag.Id);
                    mapUpdatedRayShipmentConfirmStags.put(rayShipmentConfirmStag.Id, rayShipmentConfirmStag);
                }
                
                List<Ray_Shipment_Confirmation_Staging__c> listRayShipmentConfirmStagsTemp = new List<Ray_Shipment_Confirmation_Staging__c>();
                
                if(mapRayShipmentConfirmStagsForAsset.containsKey(orderItemId)) {
                    listRayShipmentConfirmStagsTemp.addAll(mapRayShipmentConfirmStagsForAsset.get(orderItemId));         
                } 
                
                listRayShipmentConfirmStagsTemp.add(rayShipmentConfirmStag);
                
                mapRayShipmentConfirmStagsForAsset.put(orderItemId, listRayShipmentConfirmStagsTemp);
            } else {
                rayShipmentConfirmStag.RAY_Status__c = 'Error';
                rayShipmentConfirmStag.RAY_Error_Message__c	= errorMessage.length() > 255 ? errorMessage.substring(0, 255) : errorMessage;
                listErrorRayShipmentConfirmStags.add(rayShipmentConfirmStag);
            }
        }
        
        Database.SaveResult[] listOrderItemSaveResults = Database.update(listNewOrderItems, false);
        
        Set<String> setSuccessOrderItemsIds = new Set<String>();
        List<Asset> listAssetsToRollbak = new List<Asset>();
        List<OrderItem> listOrderItemsToRollbak = new List<OrderItem>();
        
        for(Integer i = 0; i < listOrderItemSaveResults.size(); i++) {
            Database.SaveResult ur = listOrderItemSaveResults[i];
            
            if(ur.isSuccess()) {
                setSuccessOrderItemsIds.add(ur.getId());
            } else {
                listOrderItemsToRollbak.add(mapOldOrderItems.get(listNewOrderItems[i].Id));
                listErrorRayShipmentConfirmStags.addAll(mapRayShipmentConfirmStagsForAsset.remove(listNewOrderItems[i].Id));
            }
        }
        // Update Order Products (End).
        
        // Update Assets (Start).
        Map<Id, Asset> mapOldAssets = getMapAssets(setSuccessOrderItemsIds);
        Map<Id, Asset> mapNewAssets = new Map<Id, Asset>();
        Map<Id, Ray_Shipment_Confirmation_Staging__c> mapAssetToRayShipmentConfirmStag = new Map<Id, Ray_Shipment_Confirmation_Staging__c>();
        List<Opportunity> listOpportunitiesToUpdate = new List<Opportunity>();
        
        for(Asset assetIter : mapOldAssets.values()) {
            if(!mapRayShipmentConfirmStagsForAsset.get(assetIter.SBQQ__OrderProduct__c).isEmpty()) {
                Ray_Shipment_Confirmation_Staging__c rayShipmentConfirmStag = mapRayShipmentConfirmStagsForAsset.get(assetIter.SBQQ__OrderProduct__c).remove(0);
                
                List<Ray_Shipment_Confirmation_Staging__c> listRayShipmentConfirmStagsTemp = new List<Ray_Shipment_Confirmation_Staging__c>();
                
                if(mapRayShipmentConfirmStagsForError.containsKey(assetIter.SBQQ__OrderProduct__c)) {
                    listRayShipmentConfirmStagsTemp.addAll(mapRayShipmentConfirmStagsForError.get(assetIter.SBQQ__OrderProduct__c));         
                }
                
                listRayShipmentConfirmStagsTemp.add(rayShipmentConfirmStag);
                mapRayShipmentConfirmStagsForError.put(assetIter.SBQQ__OrderProduct__c, listRayShipmentConfirmStagsTemp);
                
                assetIter.F_52_MACAddress__c = rayShipmentConfirmStag.RAY_MAC_Address__c;
                assetIter.F52_Ship_Date__c = rayShipmentConfirmStag.RAY_Ship_Date__c;
                assetIter.F52_Carrier_Service__c = rayShipmentConfirmStag.RAY_Carrier_Service__c;
                assetIter.Status = 'Shipped';
                assetIter.SerialNumber = rayShipmentConfirmStag.RAY_Serial_Numbers__c;
                assetIter.F52_Shipment_Tracking__c = rayShipmentConfirmStag.RAY_Tracking_Number__c;
                
                mapNewAssets.put(assetIter.Id, assetIter);
                try{
                    rayShipmentConfirmStag.RAY_Asset__c = assetIter.Id;
                }catch(Exception e){
                    rayShipmentConfirmStag.RAY_Status__c = 'Error';
                    rayShipmentConfirmStag.RAY_Error_Message__c = 'Problems with asset';
                }
                
                if(!mapUpdatedRayShipmentConfirmStags.containsKey(rayShipmentConfirmStag.Id)){
                    mapUpdatedRayShipmentConfirmStags.put(rayShipmentConfirmStag.Id, rayShipmentConfirmStag);
                }else{
                    mapUpdatedRayShipmentConfirmStags.remove(rayShipmentConfirmStag.Id);
                    mapUpdatedRayShipmentConfirmStags.put(rayShipmentConfirmStag.Id, rayShipmentConfirmStag);
                }
                mapAssetToRayShipmentConfirmStag.put(assetIter.Id, rayShipmentConfirmStag);
            }
        }
        
        for(Ray_Shipment_Confirmation_Staging__c rayShipmentConfirmStag : mapUpdatedRayShipmentConfirmStags.values()){
            if(rayShipmentConfirmStag.RAY_Status__c != 'Error' && rayShipmentConfirmStag.RAY_Status__c != ''){
                rayShipmentConfirmStag.RAY_Status__c = 'Success';
                if(!mapUpdatedRayShipmentConfirmStags.containsKey(rayShipmentConfirmStag.Id)){
                    mapUpdatedRayShipmentConfirmStags.put(rayShipmentConfirmStag.Id, rayShipmentConfirmStag);
                }else{
                    mapUpdatedRayShipmentConfirmStags.remove(rayShipmentConfirmStag.Id);
                    mapUpdatedRayShipmentConfirmStags.put(rayShipmentConfirmStag.Id, rayShipmentConfirmStag);
                }
            }
        }
        
        Database.update(mapUpdatedRayShipmentConfirmStags.values(), false);
        
        Database.SaveResult[] listAssetSaveResults = Database.update(mapNewAssets.values(), false);
        // Update Assets (End).
        
        // Update Opportunities (Start).
        Map<String, List<Asset>> mapOppIdToOldAssets = new Map<String, List<Asset>>();
        
        for(Integer i = 0; i < listAssetSaveResults.size(); i++) {
            Database.SaveResult ur = listAssetSaveResults[i];
            
            if(ur.isSuccess()) {
                Asset asset = mapNewAssets.get(ur.getId());
                
                if(asset.F52_Order__r != NULL && asset.F52_Order__r.OpportunityId != NULL) {
                    if(mapAssetToRayShipmentConfirmStag.containsKey(asset.Id)) {
                        Ray_Shipment_Confirmation_Staging__c rayShipmentConfirmStag = mapAssetToRayShipmentConfirmStag.get(asset.Id);
                        
                        Opportunity opp = new Opportunity();
                        opp.Id = asset.F52_Order__r.OpportunityId;
                        
                        String oppCarrierService = String.isBlank(asset.F52_Order__r.Opportunity.F52_Carrier_Service__c) ? '' : String.valueOf(asset.F52_Order__r.Opportunity.F52_Carrier_Service__c + ' ; ');
                        String shipCarrierService = String.isBlank(rayShipmentConfirmStag.RAY_Carrier_Service__c) ? '' : String.valueOf(rayShipmentConfirmStag.RAY_Carrier_Service__c + ' ; ');
                        opp.F52_Carrier_Service__c = oppCarrierService + shipCarrierService;
                        
                        String oppShipmentTracking = String.isBlank(asset.F52_Order__r.Opportunity.F52_Shipment_Tracking__c) ? '' : String.valueOf(asset.F52_Order__r.Opportunity.F52_Shipment_Tracking__c + ' ; '); 
                        String shipConfirmStag = String.isBlank(rayShipmentConfirmStag.RAY_Tracking_Number__c) ? '' : String.valueOf(rayShipmentConfirmStag.RAY_Tracking_Number__c + ' ; ');        
                        
                        if(oppShipmentTracking.contains(shipConfirmStag)){
                            opp.F52_Shipment_Tracking__c = oppShipmentTracking;
                        }else{
                            opp.F52_Shipment_Tracking__c = oppShipmentTracking + shipConfirmStag;
                        }
                        
                        listOpportunitiesToUpdate.add(opp);
                        
                        List<Asset> listAssets = new List<Asset>();
                        
                        if(mapOppIdToOldAssets.containsKey(opp.Id)) {
                            listAssets = mapOppIdToOldAssets.get(opp.Id);         
                        } 
                        
                        listAssets.add(mapOldAssets.get(asset.Id));
                        mapOppIdToOldAssets.put(opp.Id, listAssets);
                    }
                }
            } else {
                listOrderItemsToRollbak.add(mapOldOrderItems.get(mapNewAssets.values()[i].SBQQ__OrderProduct__c));
                listErrorRayShipmentConfirmStags.addAll(mapRayShipmentConfirmStagsForError.get(mapNewAssets.values()[i].SBQQ__OrderProduct__c));
            }
        }
        
        Database.SaveResult[] listOpportunitySaveResults = Database.update(listOpportunitiesToUpdate, false);
        
        for(Integer i = 0; i < listOpportunitySaveResults.size(); i++) {
            Database.SaveResult ur = listOpportunitySaveResults[i];
            
            if(!ur.isSuccess()) {
                listAssetsToRollbak.addAll(mapOppIdToOldAssets.get(listOpportunitiesToUpdate[i].Id));
                
                for(Asset asset : listAssetsToRollbak) {
                    if(mapOldOrderItems.containsKey(asset.SBQQ__OrderProduct__c)) {
                        listOrderItemsToRollbak.add(mapOldOrderItems.get(asset.SBQQ__OrderProduct__c));
                        listErrorRayShipmentConfirmStags.addAll(mapRayShipmentConfirmStagsForError.get(asset.SBQQ__OrderProduct__c));
                    }
                }
            }
        }
        // Update Opportunities (End).
        
        // Rollbak failed records (Start).
        update listAssetsToRollbak;
        update listOrderItemsToRollbak;
        
        for(Integer i = 0; i < listErrorRayShipmentConfirmStags.size(); i++) {
            if(listErrorRayShipmentConfirmStags[i].RAY_Status__c != 'Error' && String.isBlank(listErrorRayShipmentConfirmStags[i].RAY_Error_Message__c)) {
                listErrorRayShipmentConfirmStags[i].RAY_Status__c = 'Error';
                listErrorRayShipmentConfirmStags[i].RAY_Error_Message__c = 'Error on DML operation of next step.';
            }
        }
        
        update listErrorRayShipmentConfirmStags;
        if(!listErrorRayShipmentConfirmStags.isEmpty()) {
            sendEmailAboutErrors(listErrorRayShipmentConfirmStags);
        }
        // Rollbak failed records (End).
    } 
    
    private static List<Ray_Shipment_Confirmation_Staging__c> validateOnStatus(Set<Id> setIds) {
        List<Ray_Shipment_Confirmation_Staging__c> validated = [SELECT Id, RAY_Status__c, RAY_MAC_Address__c, RAY_Ship_Date__c, RAY_Order_Number_Text__c, RAY_Core_Product_Name__c, RAY_Tracking_Number__c,
                                                                RAY_Serial_Numbers__c, RAY_Carrier_Service__c, RAY_WCA_Product_Name__c FROM Ray_Shipment_Confirmation_Staging__c WHERE Id IN :setIds AND RAY_Status__c = NULL];
        return validated;
    } 
    
    private static Map<String, Map<String, Map<String, String>>> getMapDuplicateRayShipmentConfirmStags(Set<String> setMacAddresses, Set<String> setOrderNumbers, Set<String> setCoreProdNames, Set<String> setIds) {
        List<Ray_Shipment_Confirmation_Staging__c> listDuplicateRayShipmentConfirmStags = [SELECT Id, RAY_MAC_Address__c, RAY_Order_Number_Text__c, RAY_Core_Product_Name__c, RAY_Tracking_Number__c, RAY_WCA_Product_Name__c FROM Ray_Shipment_Confirmation_Staging__c 
                                                                                           WHERE RAY_MAC_Address__c IN :setMacAddresses AND RAY_Order_Number_Text__c IN :setOrderNumbers 
                                                                                           AND RAY_WCA_Product_Name__c IN :setCoreProdNames AND Id NOT IN :setIds];
        
        Map<String, Map<String, Map<String, String>>> mapDuplicateRayShipmentConfirmStags = new Map<String, Map<String, Map<String, String>>>();
        
        for(Ray_Shipment_Confirmation_Staging__c rayShipmentConfirmStag : listDuplicateRayShipmentConfirmStags) {
            Map<String, Map<String, String>> mapItemsFirstLevel = new Map<String, Map<String, String>>();
            
            if(mapDuplicateRayShipmentConfirmStags.containsKey(rayShipmentConfirmStag.RAY_MAC_Address__c)) {
                mapItemsFirstLevel = mapDuplicateRayShipmentConfirmStags.get(rayShipmentConfirmStag.RAY_MAC_Address__c);
            } 
            
            Map<String, String> mapItemsSecondLevel = new Map<String, String>();
            
            if(mapItemsFirstLevel.containsKey(rayShipmentConfirmStag.RAY_Order_Number_Text__c)) {
                mapItemsSecondLevel = mapItemsFirstLevel.get(rayShipmentConfirmStag.RAY_Order_Number_Text__c);
            }
            
            mapItemsSecondLevel.put(rayShipmentConfirmStag.RAY_Core_Product_Name__c, rayShipmentConfirmStag.Id);
            mapItemsFirstLevel.put(rayShipmentConfirmStag.RAY_Order_Number_Text__c, mapItemsSecondLevel);
            mapDuplicateRayShipmentConfirmStags.put(rayShipmentConfirmStag.RAY_MAC_Address__c, mapItemsFirstLevel);
        }
        
        return mapDuplicateRayShipmentConfirmStags;
    }
    
    private static Map<String, Map<String, String>> getMapDuplicateAssets(Set<String> setMacAddresses, Set<String> setOrderNumbers) {
        List<Asset> listDuplicateAssets = [SELECT Id, F_52_MACAddress__c, F52_Order__c, F52_Order__r.OrderNumber FROM Asset 
                                           WHERE F_52_MACAddress__c IN :setMacAddresses AND F52_Order__r.OrderNumber IN :setOrderNumbers];
        
        Map<String, Map<String, String>> mapDuplicateAssets = new Map<String, Map<String, String>>();
        
        for(Asset asset : listDuplicateAssets) {
            Map<String, String> mapItems = new Map<String, String>();
            
            if(mapDuplicateAssets.containsKey(asset.F_52_MACAddress__c)) {
                mapItems = mapDuplicateAssets.get(asset.F_52_MACAddress__c);
            }
            
            mapItems.put(asset.F52_Order__r.OrderNumber, asset.Id);
            mapDuplicateAssets.put(asset.F_52_MACAddress__c, mapItems);
        }
        
        return mapDuplicateAssets;
    }
    
    private static Map<String, Map<String, OrderItem>> getMapOrderItems(Set<String> setOrderNumbers, Set<String> setCoreProdNames) {
        List<OrderItem> listOrderItems = [SELECT Id, OrderItemNumber, Order.OrderNumber, Product2Id, Product2.F52_Core_Product_Name__c, F52_Ship_Date__c, 
                                          F52_Shipment_Tracking__c, F52_Shipped_Quantity__c, SBQQ__OrderedQuantity__c FROM OrderItem 
                                          WHERE Order.OrderNumber IN :setOrderNumbers AND Product2.RAY_WCA_Product_Name__c IN :setCoreProdNames];
        
        System.debug('setOrderNumbers: ' + setOrderNumbers);
        System.debug('setCoreProdNames: ' + setCoreProdNames);
        System.debug('listOrderItems: ' + listOrderItems);
        Map<String, Map<String, OrderItem>> mapOrderItems = new Map<String, Map<String, OrderItem>>();
        
        for(OrderItem orderItem : listOrderItems) {
            System.debug('orderItem.F52_Shipped_Quantity__c: ' + orderItem.F52_Shipped_Quantity__c);
            System.debug('orderItem.SBQQ__OrderedQuantity__c: ' + orderItem.SBQQ__OrderedQuantity__c);
            
            if(orderItem.F52_Shipped_Quantity__c != orderItem.SBQQ__OrderedQuantity__c) {
                Map<String, OrderItem> mapItems = new Map<String, OrderItem>();
                
                if(mapOrderItems.containsKey(orderItem.OrderItemNumber)) {
                    mapItems = mapOrderItems.get(orderItem.Order.OrderNumber);
                }
                
                mapItems.put(orderItem.Product2.F52_Core_Product_Name__c, orderItem);
                mapOrderItems.put(orderItem.Order.OrderNumber, mapItems);
            }
        }
        
        return mapOrderItems;
    }
    
    private static Map<Id, Asset> getMapAssets(Set<String> setOrderProductsIds) {
        Map<Id, Asset> mapAssets = new Map<ID, Asset>([SELECT Id, SBQQ__OrderProduct__c, F_52_MACAddress__c, F52_Ship_Date__c,
                                                       SerialNumber, F52_Carrier_Service__c, Status, F52_Shipment_Tracking__c,
                                                       F52_Order__r.OpportunityId, F52_Order__r.Opportunity.F52_Shipment_Tracking__c, F52_Order__r.Opportunity.F52_Carrier_Service__c
                                                       FROM Asset WHERE F_52_MACAddress__c = NULL AND SBQQ__OrderProduct__c IN :setOrderProductsIds]);
        
        return mapAssets;
    }
    
    public static void sendEmailAboutErrors(List<Ray_Shipment_Confirmation_Staging__c> listRayShipmentConfirmStags) {   
        try {
            List<String> listEmailRecipients = getEmailRecipients();
            String emailSubject = 'Errors on staging records.'; 
            String emailBody = ''; 
            String domain = String.valueOf(URL.getSalesforceBaseUrl().toExternalForm());
            
            for(Ray_Shipment_Confirmation_Staging__c rayShipmentConfirmStag : listRayShipmentConfirmStags) {
                emailBody += domain + '/' + rayShipmentConfirmStag.Id + '   ' + rayShipmentConfirmStag.RAY_Order_Number_Text__c + '   ' 
                    + rayShipmentConfirmStag.RAY_Core_Product_Name__c + '\n' + rayShipmentConfirmStag.RAY_Error_Message__c + '\n\n';
            }
            
            EmailManager.sendMail(listEmailRecipients, emailSubject, emailBody);
        } catch (Exception ex) {
            System.debug('Exception message: ' + ex.getMessage() 
                         + '\n Line number:' + ex.getLineNumber());
        }
    }
    
    private static List<String> getEmailRecipients() {
        List<String> listEmailRecipients = new List<String>();
        
        for(F52_CPQ_Configuration__mdt configuration : [SELECT Id, F52_Operations_Email_Address__c FROM F52_CPQ_Configuration__mdt]) {
            if(String.isNotBlank(configuration.F52_Operations_Email_Address__c)){
                listEmailRecipients.add(configuration.F52_Operations_Email_Address__c);
            }
        }
        
        return listEmailRecipients;
    }
}