import sys
import yaml


path = "stack/kustomize/base/01-deployment.yaml"
name = "app-gateway"
image = "phiroict/training_k8s_rust_gateway:20220813.11.0"
if len(sys.argv) > 3:
    path = sys.argv[1]
    name = sys.argv[2]
    image = sys.argv[3]

configuration = None
with open(path, 'r') as reader:
    out = []
    configuration = yaml.load_all(reader, yaml.Loader)
    for doc in configuration:
        if doc['kind'] == 'Deployment':
            current_name = doc["spec"]["template"]["spec"]["containers"][0]["name"]
            if current_name == name:
                doc["spec"]["template"]["spec"]["containers"][0]["image"] = image
        out.append(doc)
    with open(path, "w") as writer:
        yaml.dump_all(out, writer, Dumper=yaml.Dumper)
        writer.close()

