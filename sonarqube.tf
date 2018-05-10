provider "aws" {
  region = "us-west-2"
}

variable "ecs_cluster_name" {
  default = "test-cluster"
}


resource "aws_ecs_cluster" "test_cluster" {
  name = "${var.ecs_cluster_name}"
}


resource "aws_iam_role_policy" "test_policy" {
  name = "test_policy"
  role = "${aws_iam_role.test_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
         "ec2:*",
         "elasticloadbalancing:*",
          "logs:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "test_role" {
  name = "test_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "ecs.amazonaws.com",
          "ec2.amazonaws.com"
        ]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}


data "template_file" "user_data" {
  template = "${file("ecs-cluster-userdata.tpl")}"

  vars {
    ecs_cluster_name  = "${aws_ecs_cluster.test_cluster.name}"
  }
}


# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html
# This deploys an AWS instance (VM)
resource "aws_instance" "vm" {
  instance_type = "t2.medium"
  ami           = "ami-decc7fa6"
  iam_instance_profile = "${aws_iam_instance_profile.instance_profile.id}"
  user_data = "${data.template_file.user_data.rendered}"
  key_name = "my-key"
}


resource "aws_iam_instance_profile" "instance_profile" {
  name  = "${var.ecs_cluster_name}"
  role = "${aws_iam_role.role.name}"
}

resource "aws_iam_role" "role" {
  name = "${var.ecs_cluster_name}-ecs-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "role_attachment" {
  role       = "${aws_iam_role.role.name}"
  policy_arn = "${aws_iam_policy.policy.arn}"
}

resource "aws_iam_policy" "policy" {
  name        = "${var.ecs_cluster_name}-ecs-policy"
  path        = "/"
  description = "IAM Policy for ${var.ecs_cluster_name}"
  policy      = "${data.aws_iam_policy_document.policy.json}"
}

data "aws_iam_policy_document" "policy" {
  statement {
    actions = [
      "ecs:*",
      "ecr:*",
      "logs:*",
    ]

    resources = [
      "*"
    ]
  }
}

resource "aws_default_vpc" "default" {
  tags {
    Name = "Default VPC"
  }
}

resource "aws_default_security_group" "default" {
  vpc_id = "${aws_default_vpc.default.id}"

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  ingress {
    protocol  = "tcp"
    from_port = 9000
    to_port   = 9000
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Create a new load balancer
resource "aws_elb" "sonarqube_balancer" {
  name               = "sonarqube-elb"
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]

  listener {
    instance_port     = 9000
    instance_protocol = "http"
    lb_port           = 9000
    lb_protocol       = "http"
  }

  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags {
    Name = "sonarqube-elb"
  }
}

resource "aws_ecr_repository" "sonarqube" {
  name = "sonarqube"
}

data "template_file" "sonarqube_task_definition" {
  template = "${file("sonarqube.json")}"

  vars {
    repository_url  = "sonarqube"
    db_endpoint  = "${aws_db_instance.sonarqube_db.endpoint}"
  }
}

resource "aws_ecs_task_definition" "sonarqube_task" {
  family                = "service"
  container_definitions = "${data.template_file.sonarqube_task_definition.rendered}"
}

resource "aws_ecs_service" "sonarqube" {
  name            = "sonarqube"
  cluster         = "${aws_ecs_cluster.test_cluster.id}"
  task_definition = "${aws_ecs_task_definition.sonarqube_task.arn}"
  desired_count   = 1
  iam_role        = "${aws_iam_role.test_role.arn}"
  depends_on      = ["aws_iam_role_policy.test_policy"]

  load_balancer {
    elb_name       = "${aws_elb.sonarqube_balancer.name}"
    container_name = "sonarqube"
    container_port = 9000
  }
}

resource "aws_db_instance" "sonarqube_db" {
  allocated_storage = "10"
  storage_type = "gp2"
  engine = "postgres"
  engine_version = "9.6"
  instance_class = "db.t2.micro"
  identifier = "sonarqube"
  name = "sonarqube"
  username = "sonarqubeUser"
  password = "sonarqubeSecret"
  vpc_security_group_ids = ["${aws_default_security_group.default.id}"]
}
