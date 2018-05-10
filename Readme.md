## Creates the basic infrastructure to deploy sonarqube on AWS ECS

- Make sure aws config is pointing to the right place
- terraform init
- terraform plan
- If all looks good proceed with terraform apply
- Wait until all is created
- Look for the public DNS for the load balancer
 ![alt](https://github.com/ferzerkerx/sonarqube-aws/raw/master/screenshots/custom_sonar.png)
- Sonarqube will be available on http://<your-load-balancer-public-dns>:9000/

# Sonarqube docker image
- The project will use the latest version available on dockerhub
- If you want to use a customized image make sure you push it to the ECR and change the task definition to pull from ECR instead

```hcl-terraform
    data "template_file" "sonarqube_task_definition" {
      template = "${file("sonarqube.json")}"
    
      vars {
        repository_url  = "${aws_ecr_repository.sonarqube.repository_url}"
      }
}
```