import json
import os
import hvac
import logging

logger = logging.getLogger()
logger.setLevel("DEBUG")

def lambda_handler(event, context):
    logger.info('## ENVIRONMENT VARIABLES')
    logger.info(os.environ.get('AWS_LAMBDA_LOG_GROUP_NAME', 'Unbekannt'))
    logger.info(os.environ.get('AWS_LAMBDA_LOG_STREAM_NAME', 'Unbekannt'))

    logger.info('## EVENT')
    logger.info(json.dumps(event))  # Sichere Protokollierung

    # Umgebungsvariable prüfen
    if 'VAULT_ADDR' not in os.environ:
        logger.error("VAULT_ADDR ist nicht gesetzt.")
        return {
            'statusCode': 500,
            'body': json.dumps('Fehlende Konfiguration.')
        }

    # Daten aus dem Event extrahieren
    if 'body' in event:
        try:
            body = json.loads(event['body'])
            username = body.get('username')
            password = body.get('password')
        except Exception as e:
            logger.error(f"Fehler beim Dekodieren der Payload: {str(e)}")
            return {
                'statusCode': 400,
                'body': json.dumps('Ungültige JSON-Payload.')
            }
    else:
        username = event.get('username')
        password = event.get('password')

    if not username or not password:
        logger.warning("Fehlende Anmeldedaten.")
        return {
            'statusCode': 400,
            'body': json.dumps('Du musst User und Passwort eingeben.')
        }

    try:
        client = hvac.Client(
            url=os.environ['VAULT_ADDR'],
            timeout=10  # Timeout setzen
        )
        logger.info(f"Vault-Client erstellt mit URL: {os.environ['VAULT_ADDR']}")

        auth_response = client.auth.userpass.login(
            username=username,
            password=password
        )
        if 'auth' in auth_response and 'client_token' in auth_response['auth']:
            logger.info("Vault-Login erfolgreich.")
            return {
                'statusCode': 200,
                'body': json.dumps('Login erfolgreich!')
            }
        else:
            logger.warning("Falsche Anmeldeinformationen.")
            return {
                'statusCode': 401,
                'body': json.dumps('Falsche Anmeldeinformationen du Horst.')
            }

    except hvac.exceptions.InvalidRequest as e:
        logger.error(f"Vault-Fehler: {str(e)}")
        return {
            'statusCode': 401,
            'body': json.dumps('Falsche Anmeldeinformationen du Horst.')
        }
    except Exception as e:
        logger.error(f"Unerwarteter Fehler: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps('Interner Serverfehler.')
        }
