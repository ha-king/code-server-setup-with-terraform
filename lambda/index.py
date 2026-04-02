import boto3
import datetime
import os


def handler(event, context):
    ec2 = boto3.client("ec2")
    cloudwatch = boto3.client("cloudwatch")

    target_instance_id = os.environ["TARGET_INSTANCE_ID"]

    response = cloudwatch.get_metric_statistics(
        Namespace="AWS/EC2",
        MetricName="CPUUtilization",
        Dimensions=[{"Name": "InstanceId", "Value": target_instance_id}],
        StartTime=datetime.datetime.utcnow() - datetime.timedelta(minutes=30),
        EndTime=datetime.datetime.utcnow(),
        Period=300,
        Statistics=["Average"],
    )

    datapoints = response["Datapoints"]
    if datapoints and max(point["Average"] for point in datapoints) <= 10:
        print(f"Stopping idle instance: {target_instance_id}")
        ec2.stop_instances(InstanceIds=[target_instance_id])
