import { Construct } from 'constructs';
import { App, TerraformStack, TerraformOutput,S3Backend } from 'cdktf';
import {
    AwsProvider
} from '@cdktf/provider-aws/lib/provider';
import {Subnet} from "@cdktf/provider-aws/lib/subnet";
import {Vpc} from "@cdktf/provider-aws/lib/vpc"
import {IamRole} from "@cdktf/provider-aws/lib/iam-role"
import {
    EksCluster,
    EksClusterConfig,
} from "@cdktf/provider-aws/lib/eks-cluster"
import {
    EksNodeGroup,
    EksNodeGroupConfig,
} from "@cdktf/provider-aws/lib/eks-node-group"
import {SecurityGroup} from "@cdktf/provider-aws/lib/security-group";

import {IamRolePolicyAttachment} from "@cdktf/provider-aws/lib/iam-role-policy-attachment";
import {VpcDhcpOptions} from "@cdktf/provider-aws/lib/vpc-dhcp-options";
import {VpcDhcpOptionsAssociation} from "@cdktf/provider-aws/lib/vpc-dhcp-options-association";
class EksClusterStack extends TerraformStack {
    constructor(scope: Construct, name: string) {
        super(scope, name);
        const regionStr = "ap-southeast-2"
        const clusterName = "phiro-cluster";
        // Remote state
        new S3Backend(this, {
            bucket: "phiroict-state-bucket-training",
            key: "kubernetes-training-state.state",
            region: regionStr,
        });
        // Define your AWS provider, set your region here
        new AwsProvider(this, 'aws', {
            region:regionStr, // Update with your desired AWS region
        });


        // This is the initial role for the cluster, it needs an attachment for the resource creation as that would be
        // done by the cluster and not by the terraform / cdktf runner.
        const clusterRole = new IamRole(this, "clusterrole",{
            assumeRolePolicy: `
            {
                "Version":"2012-10-17",
                "Statement": [ 
                {
                    "Action": "sts:AssumeRole",
                    "Effect":"Allow",
                    "Principal": {
                        "Service": [
                            "eks-fargate-pods.amazonaws.com",
                            "eks.amazonaws.com"
                        ]
                    }
                }
                ]
             }
            `,
            name: "clusterrole"
        });

        // You need the managed ELK cluster role attached to the role you have, so it can create the resources. Note that
        // if you apply the policy as a file it will be too large (more than 2048 chars). So you need the existing policy.
        // Also, the role needs the name of the role and not the arn which would be more in line with the rest of the stack.
        // When you apply the arn it will complain about illegal characters, the hint is that it complains about the name.
        new IamRolePolicyAttachment(this, "elkclusterattachment", {
            policyArn: "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
            role: clusterRole.name
        });

        // The nodes need ec2 access rights to create nodes, this is separate from the ELK cluster.
        const nodeRole = new IamRole(this, "noderole",{
            assumeRolePolicy: "    {\n" +
                "      \"Version\": \"2012-10-17\",\n" +
                "      \"Statement\": [\n" +
                "        {\n" +
                "          \"Effect\": \"Allow\",\n" +
                "          \"Principal\": {\n" +
                "            \"Service\": \"ec2.amazonaws.com\"\n" +
                "          },\n" +
                "          \"Action\": \"sts:AssumeRole\"\n" +
                "        }\n" +
                "      ]\n" +
                "    }\n" +
                "\n"


        });

        new IamRolePolicyAttachment(this, "elknodeattachment", {
            policyArn: "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
            role: nodeRole.name
        });

        new IamRolePolicyAttachment(this, "elknodeattachment2", {
            policyArn: "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
            role: nodeRole.name
        });

        const vpc_options = new VpcDhcpOptions(this, "vpc-options", {
            domainNameServers: ["AmazonProvidedDNS"],
            domainName: "ap-southeast-2.compute.internal"
        });

        // Create your own vpc to place the eks cluster in, not needed but for a basic security it is a good place to start.
        const vpc = new Vpc(this, "vpc", {
            cidrBlock:"10.10.0.0/16",
            enableDnsHostnames: true,
            tags:{
                Name: "eks-vpc"
            },

        });

        new VpcDhcpOptionsAssociation(this, "vpc-dhcp-assoc", {
            dhcpOptionsId: vpc_options.id,
            vpcId: vpc.id
        });


        // Standard access for the Kubernetes cluster, restrict later.
        const sg_subnets = new SecurityGroup(this, "sgs", {
            vpcId: vpc.id,
            name: "eks-ingress",
            ingress:[
                {
                    protocol: "tcp",
                    fromPort: 22,
                    toPort: 22,
                    cidrBlocks: ["0.0.0.0/0"]
                },
                {
                    protocol: "tcp",
                    fromPort: 80,
                    toPort: 80,
                    cidrBlocks: ["0.0.0.0/0"]
                },
                {
                    protocol: "tcp",
                    fromPort: 443,
                    toPort: 443,
                    cidrBlocks: ["0.0.0.0/0"]
                },
                {
                    protocol: "tcp",
                    fromPort: 6443,
                    toPort: 6443,
                    cidrBlocks: ["0.0.0.0/0"]
                }
            ],
            egress: [{
                protocol: "-1",
                fromPort:0,
                toPort:0,
                cidrBlocks:["0.0.0.0/0"]
            }]
        });

        const subnet1 = new Subnet(this, "subnet1", {
            vpcId: vpc.id,
            cidrBlock: "10.10.1.0/24",
            enableDns64: false,
            availabilityZone: "ap-southeast-2a",


        });
        const subnet2 = new Subnet(this, "subnet2", {
            vpcId: vpc.id,
            cidrBlock: "10.10.2.0/24",
            enableDns64: false,
            availabilityZone: "ap-southeast-2b"
        });

        // Create EKS cluster configuration
        const eksClusterConfig: EksClusterConfig = {
            name: clusterName, // Update with your desired cluster name
            roleArn: clusterRole.arn, // Replace with your EKS cluster role ARN
            version: '1.27', // Update with your desired EKS version

            vpcConfig:
                {
                    subnetIds: [subnet1.id, subnet2.id], // Replace with your subnet IDs
                    securityGroupIds: [sg_subnets.id], // Replace with your security group ID
                    endpointPrivateAccess: true
                }
            ,
        };

        // Create EKS cluster
        const eksCluster = new EksCluster(this, clusterName, eksClusterConfig);

        // Create EKS node group configuration
        const eksNodeGroupConfig: EksNodeGroupConfig = {
            nodeRoleArn: nodeRole.arn,
            scalingConfig: {desiredSize:2, minSize:1, maxSize:3},
            clusterName: eksCluster.name,
            instanceTypes: ['t3.medium'], // Update with your desired EC2 instance type
            subnetIds:  [subnet1.id, subnet2.id], // Replace with your subnet IDs
            tags: {
                "kubernetes.io/cluster/phiro-cluster" : "owned"
            }
        };

        // Create EKS node group
        new EksNodeGroup(this, 'eks-node-group', eksNodeGroupConfig);

        // Output the EKS cluster name
        new TerraformOutput(this, 'eks-cluster-name', {
            value: eksCluster.name,
        });
        new TerraformOutput(this, "cluster_id", {
            value: eksCluster.clusterId,
            description: "EKS cluster ID",
        });

    }
}

const app = new App();
new EksClusterStack(app, 'eks-cluster-stack');
app.synth();
