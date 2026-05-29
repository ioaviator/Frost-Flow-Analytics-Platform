import requests
import os
import sys

URL = os.getenv('API_URL')

def extract_data():

  try:
    response = requests.get(URL)

    response.raise_for_status()

  except requests.exceptions.RequestException as e:
    print(f'error from api connection: {e}')
    sys.exit(1) # Exit with a failure code

  return response.json()['PublicAssistanceFundedProjectsDetails']
