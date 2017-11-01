# frozen_string_literal: true
property :options_file, String, default: lazy { default_property_for(:options_file) }
property :conf_file, String, default: lazy { default_property_for(:conf_file) }
property :bind_service, String, default: 'default'
property :ipv6_listen, [true, false], default: true
property :options, Array, default: []

property :query_log, String
property :query_log_versions, [String, Integer], default: 2
property :query_log_max_size, String, default: '1m'
property :query_log_options, Array, default: []

property :statistics_channel, Hash

include BindCookbook::Helpers

action :create do
  bind_service = with_run_context :root do
    find_resource!(:bind_service, new_resource.bind_service)
  end

  additional_config_files = ['named.rfc1912.zones', 'named.options']

  cookbook_file "#{bind_service.sysconfdir}/named.rfc1912.zones" do
    owner bind_service.run_user
    group bind_service.run_group
    mode 0o0644
    action :create
    cookbook 'bind'
  end

  %w(named.empty named.ca named.loopback named.localhost).each do |var_file|
    cookbook_file "#{bind_service.vardir}/#{var_file}" do
      owner bind_service.run_user
      group bind_service.run_group
      mode 0o0644
      action :create
      cookbook 'bind'
    end
  end

  rndc_key = default_property_for(:rndc_key_file)
  execute 'generate_rndc_key' do
    command "rndc-confgen -a -c #{rndc_key} -r /dev/urandom; chown #{bind_service.run_user}:#{bind_service.run_group} #{rndc_key}"
    creates rndc_key
  end

  with_run_context :root do
    template new_resource.options_file do
      owner bind_service.run_user
      group bind_service.run_group
      mode 0o644
      variables(
        vardir: bind_service.vardir,
        acls: [],
        ipv6_listen: new_resource.ipv6_listen,
        options: new_resource.options,
        query_log: new_resource.query_log,
        query_log_versions: new_resource.query_log_versions,
        query_log_max_size: new_resource.query_log_max_size,
        query_log_options: new_resource.query_log_options,
        statistics_channel: new_resource.statistics_channel
      )
      action :nothing
      delayed_action :create
      notifies :restart, 'bind_service[default]', :immediately
      cookbook 'bind'
      source 'named.options.erb'
    end

    template new_resource.conf_file do
      owner bind_service.run_user
      group bind_service.run_group
      mode 0o644
      variables(
        additional_config_files: additional_config_files,
        sysconfdir: bind_service.sysconfdir,
        primary_zones: [],
        secondary_zones: [],
        forward_zones: [],
        servers: [],
        keys: []
      )
      action :nothing
      delayed_action :create
      notifies :restart, 'bind_service[default]', :immediately
      cookbook 'bind'
      source 'named.conf.erb'
    end
  end
end
