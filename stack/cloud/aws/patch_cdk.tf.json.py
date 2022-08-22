import json

patch_path = "cdktf.out/stacks/aws_instance/cdk.tf.json"
to_patch_json_path = "module/eks/subnet_ids"

with open(patch_path, "r") as reader:
    config = json.load(reader)
json_path = to_patch_json_path.split("/")
value = config[json_path[0]][json_path[1]][json_path[2]]
config[json_path[0]][json_path[1]][json_path[2]] = "${module.vpc.private_subnets}"
print ("value of the grabbed value is {}".format(value))
print ("patching")
with open(patch_path, "w") as writer:
    json.dump(config, fp=writer, indent=2)
