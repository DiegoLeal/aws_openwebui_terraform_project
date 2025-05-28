import boto3

def lambda_handler(event, context):
    ec2 = boto3.client('ec2')
    filters = [{
        'Name': 'tag:AutoStop',
        'Values': ['true']
    }]
    response = ec2.describe_instances(Filters=filters)
    instances_to_stop = []

    for reservation in response['Reservations']:
        for instance in reservation['Instances']:
            if instance['State']['Name'] == 'running':
                instances_to_stop.append(instance['InstanceId'])

    if instances_to_stop:
        ec2.stop_instances(InstanceIds=instances_to_stop)
        print(f"Stopped instances: {instances_to_stop}")
    else:
        print("No running instances with tag AutoStop=true")
