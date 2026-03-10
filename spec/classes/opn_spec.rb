# frozen_string_literal: true

require 'spec_helper'

describe 'opn' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      # Provide the custom fact so opn::config can build the provider
      # config file path (mirrors the rspec-puppet confdir).
      let(:facts) do
        os_facts.merge('opn_puppet_confdir' => Puppet[:confdir])
      end
      let(:params) { { 'devices' => {} } }

      context 'with default (empty) params' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('opn::config') }
      end

      context 'with a device creates config resources' do
        let(:params) do
          {
            'devices' => {
              'opnsense01' => {
                'url'        => 'https://opnsense01/api',
                'api_key'    => 'k',
                'api_secret' => 's',
              },
            },
          }
        end

        let(:config_dir) do
          (os_facts[:os]['family'] == 'FreeBSD') ? '/usr/local/etc/puppet/opn' : '/etc/puppet/opn'
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates the provider config file' do
          is_expected.to contain_file("#{Puppet[:confdir]}/opn_provider.yaml").with(
            ensure: 'file',
            mode: '0644',
          )
        end

        it 'creates the config directory' do
          is_expected.to contain_file(config_dir).with(ensure: 'directory')
        end

        it 'creates the per-device YAML credential file' do
          is_expected.to contain_file("#{config_dir}/opnsense01.yaml").with(
            ensure: 'file',
            mode: '0600',
            show_diff: false,
          )
        end
      end

      context 'with a device and firewall_rule' do
        let(:params) do
          {
            'devices' => {
              'opnsense01' => {
                'url'        => 'https://opnsense01/api',
                'api_key'    => 'k',
                'api_secret' => 's',
              },
            },
            'firewall_rules' => {
              'Allow HTTP' => {
                'config' => {
                  'action'   => 'pass',
                  'protocol' => 'tcp',
                },
              },
            },
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates a firewall rule resource with correct title' do
          is_expected.to contain_opn_firewall_rule('Allow HTTP@opnsense01').with(
            ensure: 'present',
          )
        end
      end

      context 'with a plugin' do
        let(:params) do
          {
            'devices' => {
              'opnsense01' => {
                'url'        => 'https://opnsense01/api',
                'api_key'    => 'k',
                'api_secret' => 's',
              },
            },
            'plugins' => {
              'os-haproxy' => {},
            },
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates a plugin resource' do
          is_expected.to contain_opn_plugin('os-haproxy@opnsense01').with(
            ensure: 'present',
          )
        end
      end

      context 'with singleton haproxy_settings' do
        let(:params) do
          {
            'devices' => {
              'opnsense01' => {
                'url'        => 'https://opnsense01/api',
                'api_key'    => 'k',
                'api_secret' => 's',
              },
            },
            'haproxy_settings' => {
              'opnsense01' => {
                'config' => {
                  'general' => { 'enabled' => '1' },
                },
              },
            },
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates haproxy_settings keyed by device' do
          is_expected.to contain_opn_haproxy_settings('opnsense01').with(
            ensure: 'present',
          )
        end
      end

      context 'with manage_resources enabled' do
        let(:params) do
          {
            'devices' => {
              'opnsense01' => {
                'url'        => 'https://opnsense01/api',
                'api_key'    => 'k',
                'api_secret' => 's',
              },
            },
            'manage_resources' => true,
          }
        end

        it { is_expected.to compile.with_all_deps }
      end

      context 'with snapshot and active' do
        let(:params) do
          {
            'devices' => {
              'opnsense01' => {
                'url'        => 'https://opnsense01/api',
                'api_key'    => 'k',
                'api_secret' => 's',
              },
            },
            'snapshots' => {
              'stable' => {
                'config' => {
                  'active' => true,
                  'note'   => 'test',
                },
              },
            },
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates a snapshot resource' do
          is_expected.to contain_opn_snapshot('stable@opnsense01').with(
            ensure: 'present',
          )
        end
      end

      context 'with additional_devices' do
        let(:config_dir) do
          (os_facts[:os]['family'] == 'FreeBSD') ? '/usr/local/etc/puppet/opn' : '/etc/puppet/opn'
        end

        let(:params) do
          {
            'devices' => {
              'opnsense01' => {
                'url'        => 'https://opnsense01/api',
                'api_key'    => 'k',
                'api_secret' => 's',
              },
            },
            'additional_devices' => {
              'opnsense-remote01' => {
                'url'        => 'https://opnsense-remote01/api',
                'api_key'    => 'rk',
                'api_secret' => 'rs',
              },
            },
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'declares opn::device_config for the additional device' do
          is_expected.to contain_opn__device_config('opnsense-remote01').with(
            config_dir: config_dir,
          )
        end

        it 'creates the credential file for the additional device' do
          is_expected.to contain_file("#{config_dir}/opnsense-remote01.yaml").with(
            ensure: 'file',
            mode: '0600',
            show_diff: false,
          )
        end

        it 'creates a credential file for the regular device' do
          is_expected.to contain_opn__device_config('opnsense01').with(
            config_dir: config_dir,
          )
        end
      end

      context 'with additional_devices does not affect default device iteration' do
        let(:params) do
          {
            'devices' => {
              'opnsense01' => {
                'url'        => 'https://opnsense01/api',
                'api_key'    => 'k',
                'api_secret' => 's',
              },
            },
            'additional_devices' => {
              'opnsense-remote01' => {
                'url'        => 'https://opnsense-remote01/api',
                'api_key'    => 'rk',
                'api_secret' => 'rs',
              },
            },
            'firewall_rules' => {
              'Allow HTTP' => {
                'config' => {
                  'action'   => 'pass',
                  'protocol' => 'tcp',
                },
              },
            },
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates a firewall rule only for regular devices' do
          is_expected.to contain_opn_firewall_rule('Allow HTTP@opnsense01')
        end

        it 'does not create a firewall rule for additional devices' do
          is_expected.not_to contain_opn_firewall_rule('Allow HTTP@opnsense-remote01')
        end
      end

      context 'with overlapping devices and additional_devices' do
        let(:params) do
          {
            'devices' => {
              'opnsense01' => {
                'url'        => 'https://opnsense01/api',
                'api_key'    => 'k',
                'api_secret' => 's',
              },
            },
            'additional_devices' => {
              'opnsense01' => {
                'url'        => 'https://opnsense01/api',
                'api_key'    => 'k2',
                'api_secret' => 's2',
              },
            },
          }
        end

        it 'fails with overlap error' do
          is_expected.to compile.and_raise_error(
            %r{additional_devices contains device names already present in devices: opnsense01},
          )
        end
      end
    end
  end
end
