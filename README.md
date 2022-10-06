# NLP-Name-Entity-Recognition-MLOps

### Descriptions:

This project facilitates the automated training and serving of NLP named-entity recognition models on AWS. This repository deploys the ML model code developed by Jeff Zemerick and David Smithbauer at [HashiTalks 2021](https://events.hashicorp.com/hashitalks2021) presentation.


### Key Technologies:

Infrastructure/ Model Training: Amazon EventBridge Rule (Cloud Watch), Amazon ECS Cluster, Amazon SQS, Amazon DynamoDB, AWS Lambda, Amazon S3, Amazon VPC

Model Serving: Amazon ECS Service, Task, Application Load Balancer(ALB)




> **Note: this project will create resources outside the AWS free tier. You are responsible for all associated costs/charges.**

### Building the Containers

This project uses Docker containers for model training and serving. One container is used for training an NLP NER model and another container is used to serve a model via a simple REST API. Refer to each container's Dockerfile for details on the training and serving. The NLP is handled by [Flair](https://github.com/flairNLP/flair).

**Important First Steps**

* You will need a DockerHub <hub.docker.com> account.
* You will need to log the Docker CLI into your account `docker login`
* Export your DockerHub username to the shell you'll be using `export DOCKERHUB_USERNAME=<your-user-name>`

Find and use the most recent compatible nvidia/cuda docker 11.7.1, Flair 0.7 and python 3.8 versions 

increase memory on Amazon Linux machine:

    1.    Use the dd command to create a swap file on the root file system. In the command, bs is the block size and count is the number of blocks. The size of the swap file is the block size option multiplied by the count option in the dd command. Adjust these values to determine the desired swap file size.

The block size you specify should be less than the available memory on the instance or you receive a "memory exhausted" error.

-In this example dd command, the swap file is 4 GB (128 MB x 32):

            sudo dd if=/dev/zero of=/swapfile bs=128M count=32
    
    2.    Update the read and write permissions for the swap file:
    
            sudo chmod 600 /swapfile
    
    3.    Set up a Linux swap area:
    
            sudo mkswap /swapfile
    
    4.    Make the swap file available for immediate use by adding the swap file to swap space:

            sudo swapon /swapfile
    
    5.    Verify that the procedure was successful:
    
            sudo swapon -s
    
    6.    Start the swap file at boot time by editing the /etc/fstab file.
    
            Open the file in the editor:
            
                sudo vi /etc/fstab
            
            Add the following new line at the end of the file, save the file, and then exit:
    
                /swapfile swap swap defaults 0 0      (save and quit :x or :wq  enter, quit without saving :q!  enter )
    
    
    7. remove swapfile when needed 
    
            sudo swapoff -v /swapfile   # turn the file off
            
            sudo rm /swapfile
            
-To further make space for the build:

    to remove all unused images

        - docker system prune 

    to figure out what is taking up the space run

        - docker system df
    
    to clean whatever takes up all the space.  
    
        - docker <image/builder/container> prune --all 
    
-Check the local EBS volume space if requires more space
        
        - df -h
        
        - bash resize.sh 30


Now you can build and push the NLP NER training container:

```
cd training
./build-image.sh
docker push $DOCKERHUB_USERNAME/ner-training:latest
```

Now build and push the serving container:

```
cd serving
./build-image.sh
docker push $DOCKERHUB_USERNAME/ner-serving:latest
```


### Building the Lambda Function

Before install lambda function install apache maven on local system

    - sudo wget http://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo -O /etc/yum.repos.d/epel-apache-maven.repo

    - sudo sed -i s/\$releasever/6/g /etc/yum.repos.d/epel-apache-maven.repo

    - sudo yum install -y apache-maven

    - mvn –version


The Lambda function is implemented in Java. The Lambda function controls the creation of ECS tasks.

To build the Lambda function, run `build-lamdba.sh` or the command:

```
mvn clean package -f ./lambda-handler/pom.xml -DskipTests=true
```

### Creating the infrastructure using Terraform

With the Docker images built and pushed we can now create the infrastructure using Terraform. In `variables.tf` there is a `name_prefix` variable that you can set in order to instantiate multiple copies of the infrastructure.

```
terraform init
terraform apply
```

This step creates:

* An SQS queue that holds the model training definitions (the models we want to train).
* An ECS cluster on which the model training and model serving containers will be run.
* An EventsBridge rule to trigger the Lambda function.
* A Lambda function that consumes from the SQS queue and initiates model training by creating the ECS service and task.
* An S3 bucket that will contain the trained models and their associated files.
* A DynamoDB table that will contain metadata about the models.

To delete the resources and clean up run `terraform destroy`.

#### Lambda Function

The Lambda function is deployed via Terraform. It is a Java 11 function that is triggered by an Amazon EventBridge (CloudWatch Events) Rule. The function consumes messages from the SQS queue. The function is parameterized through environment variables set by the terraform script.

### Training a Model

To train a model, publish a message to the SQS queue. Using the `queue-training.sh` scripts. Look at the contents of this script to change things such as the number of epochs and embeddings. The only required argument is the name of the model to train, shown below as `my-model`.

`./queue-training.sh my-model`

This publishes a message to the SQS queue which describes a desired model training. The Lambda function will be triggered by a Cloud Watch EventBridge (Events) rule. The function will consume the message(s) from the queue and launch a model training container on the ECS cluster if the cluster's number of running tasks is below a set threshold. The function will also insert a row into the DynamoDB table indicating the model's training is in progress. A `modelId` will be generated by the function that is the concatenation of the given model's name and a random UUID.

When model training is complete, the model and its associated files will be uploaded to the S3 bucket by the container prior to exiting. The model's metadata in the DynamoDB table will be updated to reflect that training is complete.

### Serving a Model

To serve a model, change to the `serve` directory. Edit `variables.tf` to set the name of the model to serve and then run `terraform init` and `terraform apply`.

This will launch a service and task on the ECS cluster to serve the given given model. The model can then be used by referencing the output DNS name of the load balancer:

```
curl -X POST http://$ALB:8080/ner --data "George Washington was president of the United States." -H "Content-type: text/plain"
```

The response will be a JSON-encoded list of JSON entities (`George Washington` and `United States`) from the text. (The actual output will vary based on the model's training and input text.)

> Note: if you receive a `503 Service Temporarily Unavailable` response, be patient and try again in a few moments.

## GPU

For training and serving on a GPU:

1. Use a GPU-capable EC2 instance type for the ECS cluster.
1. Install the appropriate CUDA runtime on the EC2 instance(s).

## License

This project is licensed under the Apache License, version 2.0.




### References:
1. [From Training to Serving: Machine Learning Models with Terraform](https://www.youtube.com/watch?v=FK-XAyw-QX0&t=610s)

2. [nvidia Deep Learning Frameworks Doumentation](https://docs.nvidia.com/deeplearning/frameworks/user-guide/index.html) 

3. [!Available nvidia/cuda image at docker hub](https://hub.docker.com/r/nvidia/cuda)

4. [oficial site with instructions: Nvidia/nvidia-docker github](https://github.com/NVIDIA/nvidia-docker)

5. [!Available FLAIR_VERSION](https://github.com/flairNLP/flair)

6. [Resolve memoryerror installing torch to the docker file](https://github.com/pytorch/pytorch/issues/25164)

7. [increase memory on Amazon Linux Machine](https://aws.amazon.com/premiumsupport/knowledge-center/ec2-memory-swap-file/)

8. [add and edit a swap file](https://www.youtube.com/watch?v=tGrzyFdUPFk)

9. [Create Lambda Functions to invoke Endpoint](https://www.youtube.com/watch?v=mCpedQixwUg) 

10. [Installing Maven file](https://softchief.com/2017/11/07/installing-maven-using-yum-on-ec2-instance-amazon-linux/)