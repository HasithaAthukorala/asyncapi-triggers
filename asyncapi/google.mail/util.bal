// Copyright (c) 2022, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/log;
import ballerina/uuid;
import ballerina/http;
import ballerinax/'client.config;
import ballerinax/googleapis.gmail as gmail;

type mapJson map<json>;
isolated function createTopic(http:Client pubSubClient, string project, string pushEndpoint) 
                                returns @tainted TopicSubscriptionDetail | error {
    string uuid = uuid:createType4AsString();        
    string topicName = TOPIC_NAME_PREFIX + uuid;
    string subscriptionName = SUBSCRIPTION_NAME_PREFIX + uuid;
    Topic topic = check createPubsubTopic(pubSubClient, project,topicName);
    string topicResource = topic.name;
    log:printInfo(topicResource + " is created");
    if (topicResource !== "") {
        Policy existingPolicy = check getPubsubTopicIamPolicy(pubSubClient, <@untainted>topicResource);
        string etag = existingPolicy.etag;
        if (etag !== "") {
            Policy newPolicy = {
                                        'version: 1,
                                        etag: etag,
                                        bindings: [
                                            {
                                                role: ROLE,
                                                members: [
                                                         IAM_POLICY_BINDING_MEMBER
                                                        ]
                                            }
                                        ]
                                    };                      
            json newPolicyRequestbody = {
                                            "policy": newPolicy.toJson()
                                        };
            _ = check setPubsubTopicIamPolicy(pubSubClient, <@untainted>topicResource,
                                                                                    newPolicyRequestbody);
            string subscriptionResource = check createSubscription(pubSubClient, subscriptionName, project, pushEndpoint,
                                                                   topicResource);
            TopicSubscriptionDetail topicSubscriptionDetail = {
                                                                topicResource: topicResource,
                                                                subscriptionResource: subscriptionResource
                                                              };                                                  
            return topicSubscriptionDetail;                                                                  
        }
    }
    return error(GMAIL_LISTENER_ERROR_CODE, message ="Could not setup a topic and subscription.");
}

isolated function createSubscription(http:Client pubSubClient, string subscriptionName, string project, 
                                     string pushEndpoint, string topicResource) returns @tainted string | error {
    SubscriptionRequest subscriptionRequestbody  = {
                                    topic: topicResource,
                                    pushConfig: {
                                                    pushEndpoint: pushEndpoint
                                                }
                                };
    Subscription subscription = check subscribePubsubTopic(pubSubClient, project, subscriptionName, 
                                                                                    subscriptionRequestbody);
    log:printInfo(subscription.name + " is created");                                                                           
    return  subscription.name;                                                                               
}

    
isolated function createPubsubTopic(http:Client pubSubClient, string project, string topic, 
                                    TopicRequestBody? requestBody ={}) returns @tainted Topic | error {
    string path = PROJECTS + project + TOPICS + topic;
    http:Response httpResponse = <http:Response> check pubSubClient->put(path, requestBody.toJson());
    json jsonResponse = check handleResponse(httpResponse);
    return jsonResponse.cloneWithType(Topic);
}

isolated function getPubsubTopicIamPolicy(http:Client pubSubClient, string resourceName) 
                                          returns @tainted Policy | error {
    string path = FORWARD_SLASH_SYMBOL + resourceName + GETIAMPOLICY;
    http:Response httpResponse = <http:Response> check pubSubClient->get(path);
    json jsonResponse = check handleResponse(httpResponse);
    return jsonResponse.cloneWithType(Policy);
}

isolated function setPubsubTopicIamPolicy(http:Client pubSubClient, string resourceName, json requestBody) 
                                          returns @tainted Policy | error {
    string path = FORWARD_SLASH_SYMBOL + resourceName + SETIAMPOLICY;
    http:Response httpResponse = <http:Response> check pubSubClient->post(path, requestBody);
    json jsonResponse = check handleResponse(httpResponse);
    return jsonResponse.cloneWithType(Policy);
}

isolated function subscribePubsubTopic(http:Client pubSubClient, string project, string subscription, 
                                       SubscriptionRequest requestBody) returns @tainted Subscription | error {
    string path = PROJECTS + project + SUBSCRIPTIONS + subscription;
    http:Response httpResponse = <http:Response> check pubSubClient->put(path, requestBody.toJson());
    json jsonResponse = check handleResponse(httpResponse);
    return jsonResponse.cloneWithType(Subscription);
}

isolated function deletePubsubTopic(http:Client pubSubClient, string topic) returns @tainted json | error {
    string path = FORWARD_SLASH_SYMBOL + topic;
    http:Response httpResponse = <http:Response> check pubSubClient->delete(path);
    json jsonResponse = check handleResponse(httpResponse);
    return jsonResponse;
}

isolated function deletePubsubSubscription(http:Client pubSubClient, string subscription) returns @tainted json | error {
    string path = FORWARD_SLASH_SYMBOL + subscription;
    http:Response httpResponse = <http:Response> check pubSubClient->delete(path);        
    json jsonResponse = check handleResponse(httpResponse);
    return jsonResponse;
} 

isolated function handleResponse(http:Response httpResponse) returns @tainted json|error {
    if (httpResponse.statusCode == http:STATUS_NO_CONTENT) {
        //If status 204, then no response body. So returns json boolean true.
        return true;
    }
    var jsonResponse = httpResponse.getJsonPayload();
    if (jsonResponse is json) {
        if (httpResponse.statusCode == http:STATUS_OK) {
            //If status is 200, request is successful. Returns resulting payload.
            return jsonResponse;
        } else if (httpResponse.statusCode == http:STATUS_CONFLICT) {
            //If status is 409, request has conflict. Returns error message.
            json conflictResponseJson = check httpResponse.getJsonPayload();
            map<json> conflictResponse = <map<json>>conflictResponseJson;
            if (conflictResponse.hasKey("error")) {
                PubSubError pubSubError = check conflictResponse["error"].cloneWithType(PubSubError);
                error err = error(GMAIL_LISTENER_ERROR_CODE, message = pubSubError?.message);
                return err;
            }           
            return error(GMAIL_LISTENER_ERROR_CODE, message = conflictResponseJson);        
        } else {
            //If status is not 200 or 204, request is unsuccessful. Returns error.
            error err = error(GMAIL_LISTENER_ERROR_CODE, message = jsonResponse);
            return err;
        }
    } else {
        error err = error(GMAIL_LISTENER_ERROR_CODE, message = 
            "Error occurred while accessing the JSON payload of the response", 'error= jsonResponse);
        return err;
    }
}

// Gmail watch and stop Functions

isolated function watch(http:Client gmailHttpClient, string userId, WatchRequestBody requestBody) 
                        returns @tainted WatchResponse | error {
    http:Request request = new;
    string watchPath = USER_RESOURCE + userId + WATCH;
    request.setJsonPayload(requestBody.toJson());
    http:Response httpResponse = <http:Response> check gmailHttpClient->post(watchPath, request);
    json jsonWatchResponse = check handleResponse(httpResponse);
    WatchResponse watchResponse = check jsonWatchResponse.cloneWithType(WatchResponse);
    return watchResponse;
}

isolated function stop(http:Client gmailHttpClient, string userId) returns @tainted error? {
    http:Request request = new;
    string stopPath = USER_RESOURCE + userId + STOP;
    return check gmailHttpClient->post(stopPath, request);
}

isolated function getClient(gmail:ConnectionConfig config) returns http:Client|error {
    http:ClientConfiguration httpClientConfig = check config:constructHTTPClientConfig(config);
    return check new (gmail:BASE_URL, httpClientConfig);
}

# Retrieves whether the particular remote method is available.
#
# + methodName - Name of the required method
# + methods - All available methods
# + return - `true` if method available or else `false`
isolated function isMethodAvailable(string methodName, string[] methods) returns boolean {
    boolean isAvailable = methods.indexOf(methodName) is int;
    if (isAvailable) {
        var index = methods.indexOf(methodName);
        if (index is int) {
            _ = methods.remove(index);
        }
    }
    return isAvailable;
}

isolated function readMessage(gmail:ConnectionConfig gmailConfig, string messageId, string? format = (), 
                              string[]? metadataHeaders = (), string? userId = ()) returns @tainted gmail:Message|error {
    string userEmailId = ME;
    if (userId is string) {
        userEmailId = userId;
    }
    string uriParams = "";
    //Append format query parameter
    if (format is string) {
        uriParams = check gmail:appendEncodedURIParameter(uriParams, gmail:FORMAT, format);
    }
    if (metadataHeaders is string[]) {
        foreach string metaDataHeader in metadataHeaders {
            uriParams = check gmail:appendEncodedURIParameter(uriParams, gmail:METADATA_HEADERS, metaDataHeader);
        }
    }
    string readMessagePath = USER_RESOURCE + userEmailId + gmail:MESSAGE_RESOURCE + FORWARD_SLASH_SYMBOL + messageId 
        + uriParams;

    http:Client httpClient = check getClient(gmailConfig);
    http:Response httpResponse = <http:Response>check httpClient->get(readMessagePath);
    //Get json message response. If unsuccessful, throws and returns error.
    json jsonreadMessageResponse = check handleResponse(httpResponse);
    //Transform the json mail response from Gmail API to Message type. If unsuccessful, throws and returns error.
    return gmail:convertJSONToMessageType(<@untainted>jsonreadMessageResponse);
}

isolated function readThread(gmail:ConnectionConfig gmailConfig, string threadId, string? format = (), 
                             string[]? metadataHeaders = (), string? userId = ()) returns @tainted gmail:MailThread|error {
    string userEmailId = ME;
    if (userId is string) {
        userEmailId = userId;
    }
    string uriParams = "";
    if (format is string) {
        uriParams = check gmail:appendEncodedURIParameter(uriParams, gmail:FORMAT, format);
    }
    if (metadataHeaders is string[]) {
        //Append the optional meta data headers as query parameters
        foreach string metaDataHeader in metadataHeaders {
            uriParams = check gmail:appendEncodedURIParameter(uriParams, gmail:METADATA_HEADERS, metaDataHeader);
        }
    }
    string readThreadPath = USER_RESOURCE + userEmailId + gmail:THREAD_RESOURCE + FORWARD_SLASH_SYMBOL + threadId 
                             + uriParams;

    http:Client httpClient = check getClient(gmailConfig);
    http:Response httpResponse = <http:Response>check httpClient->get(readThreadPath);
    //Get json thread response. If unsuccessful, throws and returns error.
    json jsonReadThreadResponse = check handleResponse(httpResponse);
    //Transform json thread response from Gmail API to MailThread type. If unsuccessful, throws and returns error.
    return gmail:convertJSONToThreadType(<@untainted>jsonReadThreadResponse);
}

isolated function listHistory(gmail:ConnectionConfig gmailConfig, string startHistoryId, string[]? historyTypes = (), 
                              string? labelId = (), string? maxResults = (), string? pageToken = (), string? userId = ()) 
                              returns @tainted stream<gmail:History,error?>|error {
    string userEmailId = ME; 
    if (userId is string) {
        userEmailId = userId;
    }
    http:Client httpClient = check getClient(gmailConfig);   
    gmail:MailboxHistoryStream mailboxHistoryStream = check new gmail:MailboxHistoryStream (httpClient, userEmailId,
            startHistoryId, historyTypes, labelId, maxResults, pageToken);
    return new stream<gmail:History,error?>(mailboxHistoryStream);
}  
