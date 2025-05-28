# lambda/stop_instances.py
import boto3
import logging
import os

# Configura o logger
logger = logging.getLogger()
logger.setLevel(os.environ.get('LOG_LEVEL', 'INFO'))

def lambda_handler(event, context):
    """
    Função Lambda que para instâncias EC2 com a tag 'AutoStop' = 'true'
    quando um alarme de faturamento é acionado.
    """
    logger.info("Alarme de faturamento acionado. Iniciando a verificação de instâncias para parar.")
    ec2 = boto3.client('ec2')

    try:
        # Descreve as instâncias com o filtro de tags
        response = ec2.describe_instances(
            Filters=[
                {
                    'Name': 'tag:AutoStop',
                    'Values': ['true']
                },
                {
                    'Name': 'instance-state-name',
                    'Values': ['running'] # Apenas instâncias em execução
                }
            ]
        )

        instances_to_stop = []
        for reservation in response['Reservations']:
            for instance in reservation['Instances']:
                instance_id = instance['InstanceId']
                instance_name = "N/A"
                for tag in instance.get('Tags', []):
                    if tag['Key'] == 'Name':
                        instance_name = tag['Value']
                instances_to_stop.append({'id': instance_id, 'name': instance_name})
                logger.info(f"Instância encontrada para parar: {instance_name} ({instance_id})")

        if instances_to_stop:
            # Extrai apenas os IDs das instâncias
            instance_ids = [inst['id'] for inst in instances_to_stop]
            logger.info(f"Parando as seguintes instâncias: {instance_ids}")
            ec2.stop_instances(InstanceIds=instance_ids)
            logger.info("Comando de parada enviado com sucesso.")
            return {
                'statusCode': 200,
                'body': f"Paradas {len(instance_ids)} instâncias: {instance_ids}"
            }
        else:
            logger.info("Nenhuma instância com a tag 'AutoStop' = 'true' e em execução foi encontrada para parar.")
            return {
                'statusCode': 200,
                'body': "Nenhuma instância para parar."
            }

    except Exception as e:
        logger.error(f"Erro ao parar instâncias: {e}")
        return {
            'statusCode': 500,
            'body': f"Erro ao parar instâncias: {str(e)}"
        }
