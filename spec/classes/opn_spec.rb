# frozen_string_literal: true

require 'spec_helper'

describe 'opn' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:params) { { 'devices' => {} } }

      context 'with default (empty) params' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('opn::config') }
      end

      context 'with a device creates config resources' do
        let(:params) do
          {
            'devices' => {
              'fw01' => {
                'url'        => 'https://fw01/api',
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

        it 'creates the config directory' do
          is_expected.to contain_file(config_dir).with(ensure: 'directory')
        end

        it 'creates the per-device YAML credential file' do
          is_expected.to contain_file("#{config_dir}/fw01.yaml").with(
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
              'fw01' => {
                'url'        => 'https://fw01/api',
                'api_key'    => 'k',
                'api_secret' => 's',
              },
            },
            'firewall_rules' => {
              'Allow HTTP' => {
                'action'   => 'pass',
                'protocol' => 'tcp',
              },
            },
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates a firewall rule resource with correct title' do
          is_expected.to contain_opn_firewall_rule('Allow HTTP@fw01').with(
            ensure: 'present',
          )
        end
      end

      context 'with a plugin' do
        let(:params) do
          {
            'devices' => {
              'fw01' => {
                'url'        => 'https://fw01/api',
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
          is_expected.to contain_opn_plugin('os-haproxy@fw01').with(
            ensure: 'present',
          )
        end
      end

      context 'with singleton haproxy_settings' do
        let(:params) do
          {
            'devices' => {
              'fw01' => {
                'url'        => 'https://fw01/api',
                'api_key'    => 'k',
                'api_secret' => 's',
              },
            },
            'haproxy_settings' => {
              'fw01' => {
                'general' => { 'enabled' => '1' },
              },
            },
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates haproxy_settings keyed by device' do
          is_expected.to contain_opn_haproxy_settings('fw01').with(
            ensure: 'present',
          )
        end
      end

      context 'with snapshot and active' do
        let(:params) do
          {
            'devices' => {
              'fw01' => {
                'url'        => 'https://fw01/api',
                'api_key'    => 'k',
                'api_secret' => 's',
              },
            },
            'snapshots' => {
              'stable' => {
                'active' => true,
                'note'   => 'test',
              },
            },
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates a snapshot resource' do
          is_expected.to contain_opn_snapshot('stable@fw01').with(
            ensure: 'present',
          )
        end
      end
    end
  end
end
