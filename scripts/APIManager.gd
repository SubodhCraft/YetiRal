extends Node

## Centralized HTTP Request manager for the backend API
const API_URL = "http://127.0.0.1:5000"

signal request_completed(endpoint: String, success: bool, data: Dictionary)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

## Generic method to make an API call
func make_request(endpoint: String, method: int, payload: Dictionary = {}, callback: Callable = Callable()):
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	http_request.request_completed.connect(
		func(result, response_code, headers, body):
			_on_request_completed(result, response_code, headers, body, endpoint, http_request, callback)
	)
	
	var url = API_URL + endpoint
	var headers = ["Content-Type: application/json"]
	
	var err
	if method == HTTPClient.METHOD_GET:
		err = http_request.request(url, headers, method)
	else:
		var json = JSON.stringify(payload)
		err = http_request.request(url, headers, method, json)
		
	if err != OK:
		push_error("Failed to start HTTP request to: " + url)
		http_request.queue_free()
		if callback.is_valid():
			callback.call(false, {"message": "Connection error."})

func _on_request_completed(result, response_code, _headers, body, endpoint, http_request, callback):
	http_request.queue_free()
	
	var success = (result == HTTPRequest.RESULT_SUCCESS and response_code == 200)
	var data = {}
	
	if body.size() > 0:
		var json = JSON.new()
		var err = json.parse(body.get_string_from_utf8())
		if err == OK:
			data = json.get_data()
			if typeof(data) == TYPE_DICTIONARY and data.has("success"):
				success = data.get("success", false)
				
	emit_signal("request_completed", endpoint, success, data)
	if callback.is_valid():
		callback.call(success, data)
