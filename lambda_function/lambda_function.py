import json
import os
import hvac

def lambda_handler(event, context):
    username = event.get('username')
    password = event.get('password')

    if not username or not password:
        return {
            'statusCode': 400,
            'body': json.dumps('Username and password are required.')
        }

    client = hvac.Client(
        url=os.environ['VAULT_ADDR']
    )

    try:
        auth_response = client.auth.userpass.login(
            username=username,
            password=password
        )
        if auth_response:
            return {
                'statusCode': 200,
                'body': json.dumps('Login erfolgreich!')
            }
        else:
            return {
                'statusCode': 401,
                'body': json.dumps('Ungültige Anmeldeinformationen.')
            }
    except hvac.exceptions.InvalidRequest:
        return {
            'statusCode': 401,
            'body': json.dumps('Ungültige Anmeldeinformationen.')
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps('Interner Serverfehler.')
        }
