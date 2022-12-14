import {Construct} from "constructs";
/*Provider bindings are generated by running cdktf get.
See https://cdk.tf/provider-generation for more details.*/
import * as kubernetes from "./.gen/providers/kubernetes";
import * as aws from "./.gen/providers/aws";
import * as Eks from "./.gen/modules/eks";
import * as Vpc from "./.gen/modules/vpc";
import {App, S3Backend, TerraformOutput, TerraformStack, TerraformVariable, Fn} from "cdktf";
import {AwsProvider} from "./.gen/providers/aws";

class MyStack extends TerraformStack {
    constructor(scope: Construct, id: string) {
        super(scope, id);
        const regionStr = "ap-southeast-2"
        new S3Backend(this, {
            bucket: "phiroict-state-bucket-training",
            key: "kubernetes-training-state.state",
            region: regionStr,
        });

        new AwsProvider(this, "AWS", {
            region: regionStr,
        });


        const region = new TerraformVariable(this, "region", {
            default: "ap-southeast-2",
            description: "AWS region",
        });
        const cdktfTerraformOutputRegion = new TerraformOutput(this, "region_1", {
            value: region.value,
            description: "AWS region",
        });

        /*This allows the Terraform resource name to match the original name. You can remove the call if you don't need them to match.*/
        cdktfTerraformOutputRegion.overrideLogicalId("region");

        const dataAwsAvailabilityZonesAvailable =
            new aws.datasources.DataAwsAvailabilityZones(this, "available", {});

        const clusterName = `training-eks-phiro-test`;

        new TerraformOutput(this, "cluster_name", {
            value: clusterName,
            description: "Kubernetes Cluster Name",
        });

        const vpc = new Vpc.Vpc(this, "vpc", {
            azs: dataAwsAvailabilityZonesAvailable.names.slice(0,3),
            cidr: "10.10.0.0/16",
            enableDnsHostnames: true,
            enableNatGateway: true,
            name: "training-k8s-vpc",
            privateSubnets: ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"],
            publicSubnets: ["10.10.4.0/24", "10.10.5.0/24", "10.10.6.0/24"],
            singleNatGateway: true,
        });
        const awsSecurityGroupNodeGroupOne = new aws.vpc.SecurityGroup(
            this,
            "node_group_one",
            {
                ingress: [
                    {
                        cidrBlocks: ["10.10.0.0/8"],
                        fromPort: 22,
                        protocol: "tcp",
                        toPort: 22,
                    },
                ],
                namePrefix: "node_group_one",
                vpcId: vpc.vpcIdOutput,
            }
        );
        const awsSecurityGroupNodeGroupTwo = new aws.vpc.SecurityGroup(
            this,
            "node_group_two",
            {
                ingress: [
                    {
                        cidrBlocks: ["192.168.0.0/16"],
                        fromPort: 22,
                        protocol: "tcp",
                        toPort: 22,
                    },
                ],
                namePrefix: "node_group_two",
                vpcId: vpc.vpcIdOutput,
            }
        );
        const eks = new Eks.Eks(this, "eks", {
            clusterName: clusterName,
            clusterVersion: "1.23",
            eksManagedNodeGroupDefaults: [
                {
                    amiType: "AL2_x86_64",
                    attachClusterPrimarySecurityGroup: true,
                    createSecurityGroup: false,
                },
            ],
            eksManagedNodeGroups: [
                {
                    one: [
                        {
                            desiredSize: 2,
                            instanceTypes: ["t3.small"],
                            maxSize: 3,
                            minSize: 1,
                            name: "node-group-1",
                            preBootstrapUserData: "echo 'foo bar'\n",
                            vpcSecurityGroupIds: [awsSecurityGroupNodeGroupOne.id],
                        },
                    ],
                    two: [
                        {
                            desiredSize: 1,
                            instanceTypes: ["t3.medium"],
                            maxSize: 2,
                            minSize: 1,
                            name: "node-group-2",
                            preBootstrapUserData: "echo 'foo bar'\n",
                            vpcSecurityGroupIds: [awsSecurityGroupNodeGroupTwo.id],
                        },
                    ],
                },
            ],
            subnetIds: [vpc.privateSubnetsOutput],
            vpcId: vpc.vpcIdOutput,
        });
        new kubernetes.KubernetesProvider(this, "kubernetes", {
            clusterCaCertificate: Fn.base64decode(eks.clusterCertificateAuthorityDataOutput),
            host: eks.clusterEndpointOutput,
        });
        new TerraformOutput(this, "cluster_endpoint", {
            value: eks.clusterEndpointOutput,
            description: "Endpoint for EKS control plane",
        });
        new TerraformOutput(this, "cluster_id", {
            value: eks.clusterIdOutput,
            description: "EKS cluster ID",
        });
        new TerraformOutput(this, "cluster_security_group_id", {
            value: eks.clusterSecurityGroupIdOutput,
            description: "Security group ids attached to the cluster control plane",
        });

    }
}

const app = new App();
new MyStack(app, "aws_instance");
app.synth();
