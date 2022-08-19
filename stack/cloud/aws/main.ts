import { Construct } from "constructs";
import {App, TerraformStack, S3Backend, TerraformOutput} from "cdktf";
import { AwsProvider } from "@cdktf/provider-aws";
import {InternetGateway, NatGateway, Subnet, Vpc} from './.gen/providers/aws/vpc'
import {EksCluster, EksNodeGroup} from "./.gen/providers/aws/eks";
import {Eip} from "./.gen/providers/aws/ec2";
import {IamRole, IamRolePolicyAttachment} from "./.gen/providers/aws/iam";


class MyStack extends TerraformStack {
  constructor(scope: Construct, id: string) {
    super(scope, id);
    const region = "ap-southeast-2"
    new S3Backend(this, {
      bucket: "phiroict-state-bucket-training",
      key: "kubernetes-training-state.state",
      region: region,
    });
    new AwsProvider(this, "AWS", {
      region: region,
    });


    const vpc = new Vpc(this, "kubernetes-vpc", {
      cidrBlock: "10.120.0.0/16",
      tags: {
        Name: "k8s_training_vpc"
      }
    });

    const subnet1 = new Subnet(this, "subnet1", {
      vpcId: vpc.id,
      cidrBlock: "10.120.1.0/24",
      availabilityZone: "ap-southeast-2a"

    });

    const subnet2 = new Subnet(this, "subnet2", {
      vpcId: vpc.id,
      cidrBlock: "10.120.2.0/24",
      availabilityZone: "ap-southeast-2b"

    });

    const pubip = new Eip(this, 'kube_public', {
      vpc: true
    });

    const pubip2 = new Eip(this, 'kube_public2', {
      vpc: true
    });


    new InternetGateway(this, "inet", {
      vpcId: vpc.id,
    })

    new NatGateway(this , "subnet1_nat", {
      subnetId: subnet1.id,
      allocationId: pubip.id,

    });

    new NatGateway(this , "subnet2_nat", {
      subnetId: subnet2.id,
      allocationId: pubip2.id
    });

    const iam_role = new IamRole(this, 'k8s_role', {
      name: "k8s_role",
      assumeRolePolicy: "{\n" +
          "  \"Version\": \"2012-10-17\",\n" +
          "  \"Statement\": [\n" +
          "    {\n" +
          "      \"Effect\": \"Allow\",\n" +
          "      \"Principal\": {\n" +
          "        \"Service\": \"eks.amazonaws.com\"\n" +
          "      },\n" +
          "      \"Action\": \"sts:AssumeRole\"\n" +
          "    }\n" +
          "  ]\n" +
          "}"
    });


    new IamRolePolicyAttachment(this, 'attachment_policy_cluster', {
      policyArn: "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
      role: iam_role.id
    });



    const eks = new EksCluster (this, "kuberenetes-eks", {
      name: "training-cluster",
      version: "1.23",
      roleArn: iam_role.arn,
      vpcConfig: {
        subnetIds: [subnet1.id, subnet2.id]
      }

    });

    new EksNodeGroup(this, 'k8s_nodegroup', {
      clusterName: eks.name,
      nodeRoleArn: "arn:aws:iam::aws:policy/aws-service-role/AWSServiceRoleForAmazonEKSNodegroup",
      scalingConfig: {
        desiredSize: 3,
        maxSize:3,
        minSize:1

      },
      subnetIds: [subnet1.id, subnet2.id],



    });

    new TerraformOutput(this, "cluster_url", {
      value: eks.endpoint
    })


  }
}

const app = new App();
new MyStack(app, "aws_instance");



app.synth();
