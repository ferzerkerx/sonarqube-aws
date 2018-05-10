#Create a customized image

- mvn install
- docker build . -t <your-ecr-repo-url>/sonarqube
- aws ecr get-login --no-include-email --region us-west-2 
- docker login –u AWS –p password –e none https://aws_account_id.dkr.ecr.us-west-2.amazonaws.com
- docker push <your-ecr-repo-url>/my-web-app

