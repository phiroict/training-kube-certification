import { Construct } from 'constructs';
import { App, TerraformStack, S3Backend } from 'cdktf';
import {
    AwsProvider
} from '@cdktf/provider-aws/lib/provider';
import {Vpc} from "/Users/phiro/IdeaProjects/training-kube-certification/stack/cloud/aws/.gen/modules/vpc";
import {DataAwsAvailabilityZones} from "/Users/phiro/IdeaProjects/training-kube-certification/stack/cloud/aws/.gen/providers/aws/data-aws-availability-zones";
import {Eks} from "/Users/phiro/IdeaProjects/training-kube-certification/stack/cloud/aws/.gen/modules/eks";
import {DataAwsIamPolicy} from "@cdktf/provider-aws/lib/data-aws-iam-policy";
import {Irsa} from "/Users/phiro/IdeaProjects/training-kube-certification/stack/cloud/aws/.gen/modules/irsa";
import {EksAddon} from "@cdktf/provider-aws/lib/eks-addon";

class EksClusterStack extends TerraformStack {
    constructor(scope: Construct, name: string) {
        super(scope, name);
        const regionStr = "ap-southeast-2"
//        const clusterName = "phiro-cluster";
        // Remote state
        new S3Backend(this, {
            bucket: "phiroict-state-bucket-training",
            key: "kubernetes-training-state.state",
            region: regionStr,
        });
        // Define your AWS provider, set your region here
        new AwsProvider(this, 'aws', {
            region: regionStr, // Update with your desired AWS region
        });

        const azs_avail = new DataAwsAvailabilityZones(this, "azs",{

        });

        const vpc = new Vpc(this,
            "vpc-eks",
            {
                name: "vpc-eks",
                cidr: "10.10.0.0/16",
                azs: azs_avail.names,
                privateSubnets: ["10.10.1.0/24","10.10.2.0/24","10.10.3.0/24"],
                publicSubnets: ["10.10.61.0/24","10.10.62.0/24","10.10.63.0/24"],
                enableNatGateway: true,
                singleNatGateway: true,
                enableDnsHostnames: true,
                publicSubnetTags: {
                    "kubernetes.io/cluster/phiro-cluster": "shared",
                    "kubernetes.io/role/elb": "1"
                },
                privateSubnetTags: {
                    "kubernetes.io/cluster/phiro-cluster": "shared",
                    "kubernetes.io/role/elb-internal": "1"
                }
            });

        const eks = new Eks(this, "phiro-cluster",{
            clusterVersion: "1.27",
            clusterName: "phiro-cluster",
            vpcId: vpc.vpcIdOutput,
            subnetIds: vpc.privateSubnets,

            clusterEndpointPublicAccess: true,
            eksManagedNodeGroupDefaults: {amiType: "AL2_x86_64"},
            eksManagedNodeGroups: {
                one: {
                    name: "node-group-1",
                    instanceTypes: ["t3.small"],
                    minSize: 1,
                    maxSize: 3,
                    desiredSize: 1

                },
                two: {
                    name: "node-group-2",
                    instanceTypes: ["t3.small"],
                    minSize: 1,
                    maxSize: 3,
                    desiredSize: 1

                }
            }
        });

        const iamPolicy = new DataAwsIamPolicy(this, "iam-policy",{
            arn: "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
        });

        const irsa = new Irsa(this, "risa-ebs-csi", {
            createRole: true,
            roleName: `AmazonEKSTFEBSCSIRole-${eks.clusterName}`,
            providerUrl: eks.oidcProviderOutput,
            rolePolicyArns: [iamPolicy.arn],
            oidcFullyQualifiedSubjects : ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
        });

        new EksAddon(this, "addon", {
            addonName: "aws-ebs-csi-driver",
            clusterName: eks.clusterNameOutput,
            addonVersion: "v1.11.2-eksbuild.1",
            serviceAccountRoleArn: irsa.iamRoleArnOutput,
            tags: {
                "eks_addon":"ebs-csi",
                "terraform": "true"
            }

        });





    }

}

const app = new App();
new EksClusterStack(app, 'eks-cluster-stack');
app.synth();
