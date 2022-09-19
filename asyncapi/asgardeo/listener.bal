import ballerina/websub;
import ballerina/http;

@display {
    label: ""
}
public class Listener {
    private websub:Listener websubListener;
    private DispatcherService dispatcherService;
    private ListenerConfig config;
    private http:ClientConfiguration httpConfig = {};
    private string[] topics = [];

    public function init(ListenerConfig config, int|websub:Listener listenOn = 8080) returns error? {
        if listenOn is websub:Listener {
            self.websubListener = listenOn;
        } else {
            self.websubListener = check new (listenOn);
        }
        self.config = config;
        self.dispatcherService = new DispatcherService();
        string token = check self.fetchToken(config.tokenEndpoint, config.clientId, config.clientSecret);
        http:ClientConfiguration httpConfig = {
            auth: {
                token: token
            }
        };
        self.httpConfig = httpConfig;
    }

    private isolated function fetchToken(string tokenEndpoint, string clientId, string clientSecret) returns string|error {
        final http:Client clientEndpoint = check new (tokenEndpoint);
        string authHeader = string `${clientId}:${clientSecret}`;
        http:Request tokenRequest = new;
        tokenRequest.setHeader("Authorization", "Basic " + authHeader.toBytes().toBase64());
        tokenRequest.setHeader("Content-Type", "application/json");
        tokenRequest.setPayload({
            "grant_type": "client_credentials"
        });
        json resp = check clientEndpoint->post("/oauth2/token", tokenRequest);
        string accessToken = check resp.access_token;
        return accessToken;
    }

    public isolated function attach(GenericServiceType serviceRef, () attachPoint) returns @tainted error? {
        self.topics.push(self.getTopic(serviceRef));
        string serviceTypeStr = self.getServiceTypeStr(serviceRef);
        check self.dispatcherService.addServiceRef(serviceTypeStr, serviceRef);
    }

    public isolated function detach(GenericServiceType serviceRef) returns error? {
        string serviceTypeStr = self.getServiceTypeStr(serviceRef);
        check self.dispatcherService.removeServiceRef(serviceTypeStr);
    }

    public isolated function 'start() returns error? {
        websub:SubscriberServiceConfiguration subConfig = {
            target: [self.config.hubURL, self.topics[0]],
            callback: self.config.callbackURL,
            appendServicePath: true,
            secret: self.config.secret,
            httpConfig: self.httpConfig
        };
        check self.websubListener.attachWithConfig(self.dispatcherService, subConfig, "/subscriber");
        return self.websubListener.'start();
    }

    public isolated function gracefulStop() returns @tainted error? {
        return self.websubListener.gracefulStop();
    }

    public isolated function immediateStop() returns error? {
        return self.websubListener.immediateStop();
    }

    private isolated function getServiceTypeStr(GenericServiceType serviceRef) returns string {
        if serviceRef is RegistrationsService {
            return "RegistrationsService";
        } else if serviceRef is UserOperationsService {
            return "UserOperationsService";
        } else {
            return "LoginsService";
        }
    }

    private isolated function getTopic(GenericServiceType serviceRef) returns string {
        string base = string `${self.config.organization}-`;
        if serviceRef is RegistrationsService {
            return base + "REGISTRATIONS";
        } else if serviceRef is UserOperationsService {
            return base + "USER_OPERATIONS";
        } else {
            return base + "LOGINS";
        }
    }
}
