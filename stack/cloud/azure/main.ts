import { Construct } from "constructs";
import { App, TerraformStack, AzurermBackend } from "cdktf";
import {
  AzurermProvider, KubernetesCluster, LogAnalyticsWorkspace, ResourceGroup, UserAssignedIdentity,

} from "./.gen/providers/azurerm"

class MyStack extends TerraformStack {
  constructor(scope: Construct, name: string) {
    super(scope, name);

    const resource_group = "training_k8s_rs";

    new AzurermBackend(this, {
      resourceGroupName: "example-resource-group",
      storageAccountName: "myremotestateset",
      containerName: "tfstate",
      key: "training_k8s.tfstate",
    });
    new AzurermProvider(this, "AzureRm", {
      features: {
        resourceGroup: {
          preventDeletionIfContainsResources: false
        }
      }
    });

    // define resources here
    const rg = new ResourceGroup(this, "rg-training-aks", {
      name: resource_group,
      location: "eastus"
    });

    new UserAssignedIdentity(this, "kubernetes_identity", {
      location: rg.location,
      name: "aks_user_identity",
      resourceGroupName: rg.name
    });
    const workspace = new LogAnalyticsWorkspace(this, "aks_workspace", {
      location: rg.location,
      name: "phiroictaksworkspace",
      resourceGroupName: rg.name,
      retentionInDays: 30
    });
    new KubernetesCluster(this, "kubernetes-cluster", {
      defaultNodePool: {
        name: "default",
        nodeCount: 3,
        vmSize: "Standard_D3_v2"
      },
      location: rg.location,
      resourceGroupName: rg.name,
      name: "PhiRo-Training-Cluster",
      identity: {
        type: "SystemAssigned"
      },
      tags: {
        Environment: "non-prod",
        Owner: "PhiRoICT",
        ExpiresAt: "20230901"
      },
      dnsPrefix: "phiroict-cluster",
      omsAgent: {
        logAnalyticsWorkspaceId: workspace.id
      },
      linuxProfile: {
        adminUsername: "ubuntu",
        sshKey: {
          keyData: process.env["MTF_AKS_PUB_KEY"] || ""
        }
      },
      networkProfile: {
        networkPlugin: "azure",
        loadBalancerSku: "standard"
      }
    });
  }
}

const app = new App();
new MyStack(app, "azure");
app.synth();
