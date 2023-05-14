import os
import urllib3
import json


def make_message_card(event_detail_type,
                      service,
                      account_id,
                      start_time,
                      event_type_code,
                      resources,
                      event_description):
    message_card_dict = {
        "@type": "MessageCard",
        "@context": "http://schema.org/extensions",
        "themeColor": "D7000B",
        "summary": "Alert For Teams",
        "sections": [{
            "activityTitle": event_detail_type,
            "activitySubtitle": service + " event alert",
            "facts": [{
                "name": "Account",
                "value": account_id
            }, {
                "name": "StartTime",
                "value": start_time
            }, {
                "name": "EventTypeCode",
                "value": event_type_code
            }, {
                "name": "Resources",
                "value": ", ".join(resources)
            }, {
                "name": "Description",
                "value": event_description
            }],
            "markdown": "true"
        }]}
    return message_card_dict


def lambda_handler(event, context):
    event_detail_type = event.get("detail-type", "")
    account_id = event.get("account", "")
    resources = event.get("resources", "")
    source = event.get("source", "")

    detail = event.get("detail", {})

    if source == "aws.health":
        service = detail.get("service", "")
        start_time = detail.get("startTime", "")
        event_type_code = detail.get("eventTypeCode", "")
        event_description = detail.get("eventDescription", "")
        if event_description:
            event_description = event_description[0].get(
                "latestDescription", "")

    message_dict = make_message_card(
        event_detail_type, service, account_id, start_time, event_type_code, resources, event_description)
    message_json = json.dumps(message_dict)

    TEAMS_URL = os.environ["TEAMS_URL"]
    HTTP_METHOD = "POST"
    HTTP_HEADERS = {"Content-Type": "application/json"}
    http = urllib3.PoolManager()

    response = http.request(HTTP_METHOD, TEAMS_URL,
                            body=message_json, headers=HTTP_HEADERS)
    print(message_dict)
    print({"status_code": response.status,
           "response": response.data})
