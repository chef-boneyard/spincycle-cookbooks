name "spincycle-jenkins"

# Where to find external cookbooks:
default_source :community

# run_list: chef-client will run these recipes in the order specified.
run_list "spincycle-jenkins::default"

# Specify a custom source for a single cookbook:
cookbook "spincycle-jenkins", path: "cookbooks/spincycle-jenkins"
