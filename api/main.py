import functions_framework
import time
from extract import extract_data
from load import upload_json_to_gcs

@functions_framework.http
def apiConnect(request):

    api_data = extract_data()

    timestamp = time.strftime('%Y-%m-%dT%H-%M-%S')
    file_name = f'fema_disaster_{timestamp}.json'
    upload_json_to_gcs('fema-disaster-data', file_name, api_data)

    return {"status": "success", "message": "Data successfully uploaded to bucket"}, 200
