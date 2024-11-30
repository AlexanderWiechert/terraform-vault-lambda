import boto3
import requests
from requests_aws4auth import AWS4Auth
import argparse

# Kommandozeilenargumente parsen
parser = argparse.ArgumentParser(description="Login Script for Vault API")
parser.add_argument("--username", required=True, help="Username for login")
parser.add_argument("--password", required=True, help="Password for login")
args = parser.parse_args()

# AWS Authentication
region = 'eu-central-1'
service = 'execute-api'
credentials = boto3.Session().get_credentials()
auth = AWS4Auth(credentials.access_key, credentials.secret_key, region, service, session_token=credentials.token)

# API Request
url = 'https://680k27jzog.execute-api.eu-central-1.amazonaws.com/prod/login'
body = {"username": args.username, "password": args.password}  # Python-Objekt
response = requests.post(url, auth=auth, json=body)  # `json=` verwenden

# Debugging-Ausgaben
print(f"Request URL: {url}")
print(f"Payload: {body}")
print(f"Response Status Code: {response.status_code}")
print(f"Response Body: {response.text}")
