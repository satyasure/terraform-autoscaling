# step 0: Create Key Pair
resource "aws_key_pair" "automate_infra" {
  key_name = "automate_infra"
  public_key = file(var.public_key_path)
}

# Stpe 1: Creating the autoscaling launch configuration that contains AWS EC2 instance details

resource "aws_launch_configuration" "aws_autoscale_conf" {
  name          = "web_config"
  image_id      = "${data.aws_ami.ubuntu}"
  instance_type = "${var.instance_type}"
  key_name      = aws_key_pair.automate_infra.key_name
}
# Step 2: Creating the autoscaling group within eu-west-3a availability zone

resource "aws_autoscaling_group" "asg-group" {
  name                      = "autoscalegroup"
  #vpc_zone_identifier       = ["${data.aws_subnet_ids.all.ids}"]
  for_each                  = ${data.aws_subnet_ids.private.ids}
  vpc_zone_identifier       = each.value
  #subnet_id                 = each.value
  availability_zones        = ["eu-west-3a"]
  max_size                  = 2
  min_size                  = 1
  health_check_grace_period = 30
  health_check_type         = "EC2"
  force_delete              = true
  termination_policies      = ["OldestInstance"]
  launch_configuration      = aws_launch_configuration.aws_autoscale_conf.name
}

# Step 3: Creating the autoscaling schedule of the autoscaling group

resource "aws_autoscaling_schedule" "asg-group_schedule" {
  scheduled_action_name  = "autoscalegroup_action"
  min_size               = 1
  max_size               = 2
  desired_capacity       = 1
  start_time             = "2022-02-09T18:00:00Z"
  autoscaling_group_name = aws_autoscaling_group.asg-group.name
}

# Step 4:  Creating the autoscaling policy of the autoscaling group

resource "aws_autoscaling_policy" "asg-group_scale_up_policy" {
  name                   = "autoscalegroup_policy"
  scaling_adjustment     = 2
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.asg-group.name
  policy_type            = "SimpleScaling"
}
# step 5: Creating the AWS CLoudwatch Alarm that will autoscale the AWS EC2 instance based on CPU utilization.

resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_up" {
  alarm_name = "web_cpu_alarm_up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "60"
  statistic = "Average"
# CPU Utilization threshold is set to 10 percent
  threshold = "10"
  alarm_actions = [
        "${aws_autoscaling_policy.asg-group_scale_up_policy.arn}"
    ]
dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.asg-group.name}"
  }
}
# Step 6:  Descaling policy

resource "aws_autoscaling_policy" "asg-group_descale_policy" {
  name                   = "autoscalegroup_policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.asg-group.name
  policy_type            = "SimpleScaling"
}

# Step 7 : Descaling cloud watch alaram

resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_down" {
  alarm_name = "web_cpu_alarm_down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
# CPU Utilization threshold is set to 10 percent
  threshold = "10"
  alarm_actions = ["${aws_autoscaling_policy.asg-group_descale_policy.arn}" ]
  actions_enabled = true
  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.asg-group.name}"
  }
}