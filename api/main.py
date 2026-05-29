import functions_framework
from extract import extract_data
from load import upload_json_to_gcs

@functions_framework.http
def apiConnect(request):

    api_data = extract_data()

    upload_json_to_gcs('frost_flow_data', 'frost_flow.json', api_data)

    return {"status": "success", "message": "Data successfully uploaded to bucket"}, 200
