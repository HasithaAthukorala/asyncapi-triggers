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

// Listener related configurations should be included here
public type ListenerConfig record {
};

public type SmsStatusChangeEventWrapper record {
    # The 34 character id of the Messaging Service associated with the message.
    string MessagingServiceSid?;
    # The version of the Twilio API used to handle this message.
    string ApiVersion?;
    # Same value as MessageSid. Deprecated and included for backward compatibility.
    string SmsSid?;
    # The status of the message.
    string SmsStatus?;
    # A unique identifier for this message, generated by Twilio.
    string SmsMessageSid?;
    # Number of SMS messages it took to deliver the body of the message.
    string NumSegments?;
    # The phone number or Channel address that sent this message.
    string From?;
    # The state or province of the recipient.
    string ToState?;
    # A 34 character unique identifier for the message.
    string MessageSid?;
    # The 34 character id of the Account this message is associated with.
    string AccountSid?;
    # The status of the message.
    string MessageStatus?;
    # The country of the called sender.
    string FromCountry?;
    # The city of the recipient.
    string ToCity?;
    # The postal code of the recipient.
    string ToZip?;
    # The city of the sender.
    string FromCity?;
    # The number of media items associated with a "Click to WhatsApp" advertisement.
    string ReferralNumMedia?;
    # The phone number or Channel address of the recipient.
    string To?;
    # The postal code of the called sender.
    string FromZip?;
    # The text body of the message. Up to 1600 characters long.
    string Body?;
    # The country of the recipient.
    string ToCountry?;
    # The number of media items associated with your message.
    string NumMedia?;
    # The state or province of the sender.
    string FromState?;
};

public type CallStatusEventWrapper record {
    # Called number.
    string Called?;
    # The URL of the phone call's recorded audio.
    string RecordingUrl?;
    # The postal code of the called party.
    string ToState?;
    # The country of the caller.
    string CallerCountry?;
    # A string describing the direction of the call.
    string Direction?;
    # The state of the caller.
    string CallerState?;
    # The postal code of the called party.
    string ToZip?;
    # A unique identifier for this call, generated by Twilio.
    string CallSid?;
    # The phone number or client identifier of the called party.
    string To?;
    # he zip code of the caller.
    string CallerZip?;
    # The country of the called party.
    string ToCountry?;
    # The value that verify the authentiticy of a caler ID on an incomming call.
    string StirVerstat?;
    # A token string needed to invoke a forwarded call.
    string CallToken?;
    # The version of the Twilio API used to handle this call.
    string ApiVersion?;
    # The zip code that called.
    string CalledZip?;
    # A descriptive status for the call.
    string CallStatus?;
    # The city that called.
    string CalledCity?;
    # The unique id of the Recording from this call.
    string RecordingSid?;
    # The phone number or client identifier of the party that initiated the call.
    string From?;
    # The duration in seconds of the just-completed call.
    string CallDuration?;
    # Your Twilio account ID. It is 34 characters long, and always starts with the letters AC.
    string AccountSid?;
    # The country that called.
    string CalledCountry?;
    # The city of the caller.
    string CallerCity?;
    # The identity token which contains the information needs for authentication and verification of calls.
    string StirPassportToken?;
    # The number of the caller.
    string Caller?;
    # The country of the caller.
    string FromCountry?;
    # The city of the called party.
    string ToCity?;
    # The city of the caller.
    string FromCity?;
    # The state that called.
    string CalledState?;
    # The postal code of the caller.
    string FromZip?;
    # The state or province of the caller.
    string FromState?;
    # The duration of the recorded audio (in seconds).
    string RecordingDuration?;
};

public type GenericDataType SmsStatusChangeEventWrapper|CallStatusEventWrapper;
