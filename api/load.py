import json
from google.cloud import storage
from google.cloud.exceptions import GoogleCloudError
import sys

def upload_json_to_gcs(bucket_name, destination_blob_name, json_data):
  
  try:
    storage_client = storage.Client()
      
    bucket = storage_client.bucket(bucket_name)
    
    blob = bucket.blob(destination_blob_name)
      
    json_string = json.dumps(json_data, indent=2)
      
    blob.upload_from_string(
      data=json_string,
      content_type='application/json'
    )

    print(f"Successfully uploaded data to gs://{bucket_name}/{destination_blob_name}")

  except GoogleCloudError as gcp_err:
    # Catch GCS errors (e.g., bucket not found, permissions issues)
    print(f"Google Cloud Error: {gcp_err}", file=sys.stderr)
    sys.exit(1) # Exit with a failure code
        
  except Exception as err:
    # Catch other unexpected Python errors (e.g., JSON parsing failure)
    print(f"An unexpected error occurred: {err}", file=sys.stderr)
    sys.exit(1) # Exit with a failure code
