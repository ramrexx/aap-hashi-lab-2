# Please modify the instance_count, but PLEASE don't go higher than 2 VMs in this lab.
instance_count = 2
#
#
aap_workflow_job_template = {
  name = "WF-Launched by TFE"
  organization = "Default"
}
#
aap_inventory = {
  name = "Terraform Inventory"
  organization = "Default"
}
#
# End of terraform.tfvars file
