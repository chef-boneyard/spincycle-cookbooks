class Chef::Resource::CbTest < Chef::Resource::LWRPBase
  self.resource_name = :cb_test
  provides :cb_test if Chef::Resource.respond_to?(:provides)

  actions :create
  default_action :create

  attribute :name, kind_of: String, name_attribute: true
  attribute :repo, kind_of: String, default: nil
  attribute :config, kind_of: Hash, default: {}
end

class Chef::Provider::TestMachine < Chef::Provider::LWRPBase
	provides :cb_test if Chef::Provider.respond_to?(:provides)

	use_inline_resources

	def whyrun_supported?
		true
	end

	action :create do
		directory "/var/lib/jenkins/config/#{new_resource.name}" do 
			owner "jenkins"
			recursive true
		end

		file "/var/lib/jenkins/config/#{new_resource.name}/.kitchen.local.yml" do 
			owner "jenkins"
			content new_resource.config.to_yaml
		end

		xml = ::File.join(Chef::Config[:file_cache_path], "#{new_resource.name}-config.xml")

		template xml do
			variables name: new_resource.name, repo: new_resource.repo
			source "config.xml.erb"
		end

		jenkins_job new_resource.name do
			config xml
		end
	end

end
