import sys
import yaml


path = "stack/kustomize/base/01-deployment.yaml"
name = "app-gateway"
image = "phiroict/training_k8s_rust_gateway:version"
if len(sys.argv) > 3:
    path = sys.argv[1]
    name = sys.argv[2]
    image = sys.argv[3]
version_path = image.split(":")[-1]
image_version = open(version_path, 'r').readline().strip()
image = image.split(":")[0] + ":" + image_version

print("Start to inject the build number into the stack path: {}, name: {}, image: {}".format(path,name,image))
configuration = None
with open(path, 'r') as reader:
    out = []
    configuration = yaml.load_all(reader, yaml.Loader)
    for doc in configuration:
        print("Scanning doc type: {}".format(doc['kind']))
        if doc['kind'] == 'Deployment':
            current_name = doc["spec"]["template"]["spec"]["containers"][0]["name"]
            if current_name == name:
                doc["spec"]["template"]["spec"]["containers"][0]["image"] = image
        out.append(doc)
    with open(path, "w") as writer:
        yaml.dump_all(out, writer, Dumper=yaml.Dumper)

print("Image injection complete.")
with open(path, 'r') as reader:
    file_contents = "\n".join(reader.readlines())
    print("DEBUG: File contents:\n{}".format(file_contents))