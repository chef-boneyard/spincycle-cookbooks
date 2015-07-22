#
# Cookbook Name:: spincycle-jenkins
# Recipe:: default
#
# Copyright 2015 Chef, Inc
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

node.default['java']['jdk_version'] = 7
node.default['java']['install_flavor'] = 'oracle'
node.default['java']['oracle']['accept_oracle_download_terms'] = true

include_recipe 'java'
include_recipe 'apt'

package 'ntp'
package 'ntpdate'
package 'apt-transport-https'
package 'git'

apt_repository 'chef-stable' do
  uri 'https://packagecloud.io/chef/stable/ubuntu/'
  key 'https://packagecloud.io/gpg.key'
  distribution node['lsb']['codename']
  deb_src true
  trusted true
  components %w( main )
end

package 'chefdk'

include_recipe 'jenkins::master'

plugins = {
  'scm-api'                       => '0.2',
  'git-client'                    => '1.17.1',
  'git'                           => '2.3.5',
  'jquery'                        => '1.11.2-0',
  'jquery-ui'                     => '1.0.2',
  'github-api'                    => '1.67',
  'github-oauth'                  => '0.20',
  'copy-data-to-workspace-plugin' => '1.0',
  'postbuildscript'               => '0.17',
}

plugins.each_with_index do |(name, pv), index|
  jenkins_plugin name do
    version pv
    action :install
    install_deps false
    if index == (plugins.size - 1)
      notifies :restart, 'service[jenkins]', :immediately 
    end
  end
end

# %w(kitchen-ec2 kitchen-pester winrm-transport).each do |pkg|
#   execute "/opt/chefdk/embedded/bin/gem install #{pkg}" do
#     user "jenkins"
#   end
# end

directory '/var/lib/jenkins/.ssh' do
  owner 'jenkins'
  mode '0700'
end

file "/var/lib/jenkins/.ssh/#{node['ssh_key']}" do
  owner 'jenkins'
  mode '0600'
end

directory '/var/lib/jenkins/config' do
  owner 'jenkins'
end

default_kitchen_config = {
  "driver"=>{
    "name"=>"ec2",
    "security_group_ids"=>["sg-6c37a109"],
    "region"=>"us-west-1",
    "aws_ssh_key_id"=>"spincycle_jenkins",
    "retryable_tries"=>120,
    "instance_type"=>"m3.medium"
  },
  "provisioner"=>{"chef_omnibus_install_options"=>"-p -n", "require_chef_omnibus"=>"latest"},
  "transport"=>{"max_wait_until_ready" => 1200, "ssh_key"=>"/var/lib/jenkins/.ssh/spincycle_jenkins"}
}

data_bag("cookbooks").each do |cb|
  data = data_bag_item("cookbooks", cb)
  next if data.key?("disabled")
  cfg = default_kitchen_config.dup
  cfg["platforms"] = data["platforms"]

  cb_test cb do
    repo data["repo"]
    config cfg
  end
end
