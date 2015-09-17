require 'chef/provisioning/aws_driver'
context = ChefDK::ProvisioningData.context

with_driver 'aws:default:us-west-2'

with_chef_server node['bootstrap_url'],
  client_name: node['bootstrap_client'],
  signing_key_filename: node['bootstrap_key']

aws_key_pair node['ssh_key'] do
  private_key_path ::File.expand_path("~/.ssh/#{node['ssh_key']}")
  allow_overwrite true
end

aws_security_group "spincycle" do
  inbound_rules "0.0.0.0/0" => [22, 3389, 5985, 5986, 8080]
end

machine context.node_name do
  machine_options bootstrap_options: {iam_instance_profile: { name: 'spincycle_provisioner'},
                                      key_name: node['ssh_key'],
                                      image_id: 'ami-5189a661',
                                      instance_type: 'm3.medium',
                                      security_group_ids: ["spincycle"]
  },
    transport_options: {ssh_options: { use_agent: true}},
    convergence_options: context.convergence_options
  action :setup
end

machine_execute 'make ssh dir' do
  command 'mkdir -p /home/ubuntu/.ssh && chown ubuntu: /home/ubuntu/.ssh && chmod 0700 /home/ubuntu/.ssh'
  machine context.node_name
end

%w(/home/ubuntu /var/lib/jenkins).each do |dir|
  machine_file "#{dir}/.ssh/#{node['ssh_key']}" do
    local_path ::File.expand_path("~/.ssh/#{node['ssh_key']}")
    mode "0600"
    owner 'ubuntu'
    machine context.node_name
  end
end

machine_file "/etc/chef/encrypted_data_bag_secret" do
  local_path ".chef/encrypted_data_bag_secret"
  mode "0600"
  owner "root"
  machine context.node_name
end

machine context.node_name do
  attributes ssh_key: node['ssh_key']
  converge true
  action context.action
end
