# frozen_string_literal: true

require 'spec_helper'

describe 'opn::client' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default (empty) params' do
        it { is_expected.to compile.with_all_deps }
      end

      context 'with a firewall alias' do
        let(:params) do
          {
            'firewall_aliases' => {
              'webserver_ips' => {
                'devices' => ['opnsense01'],
                'config'  => {
                  'type'        => 'host',
                  'content'     => '10.0.0.1',
                  'description' => 'Web server IPs',
                  'enabled'     => '1',
                },
              },
            },
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'exports a firewall alias with correct title and tag' do
          expect(exported_resources).to contain_opn_firewall_alias('webserver_ips@opnsense01').with(
            ensure: 'present',
            config: {
              'type'        => 'host',
              'content'     => '10.0.0.1',
              'description' => 'Web server IPs',
              'enabled'     => '1',
            },
            tag: 'opnsense01',
          )
        end
      end

      context 'with a plugin (no config)' do
        let(:params) do
          {
            'plugins' => {
              'os-haproxy' => {
                'devices' => ['opnsense01'],
              },
            },
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'exports a plugin resource without config' do
          expect(exported_resources).to contain_opn_plugin('os-haproxy@opnsense01').with(
            ensure: 'present',
            tag: 'opnsense01',
          )
        end
      end

      context 'with a snapshot and active' do
        let(:params) do
          {
            'snapshots' => {
              'pre-upgrade' => {
                'devices' => ['opnsense01'],
                'config'  => {
                  'active' => true,
                  'note'   => 'Before upgrade',
                },
              },
            },
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'exports a snapshot with active property' do
          expect(exported_resources).to contain_opn_snapshot('pre-upgrade@opnsense01').with(
            ensure: 'present',
            active: true,
            config: { 'active' => true, 'note' => 'Before upgrade' },
            tag: 'opnsense01',
          )
        end
      end

      context 'with multiple devices' do
        let(:params) do
          {
            'haproxy_servers' => {
              'web01' => {
                'devices' => ['opnsense01', 'opnsense02'],
                'config'  => {
                  'address' => '10.0.0.1',
                  'port'    => '80',
                  'enabled' => '1',
                },
              },
            },
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'exports to the first device' do
          expect(exported_resources).to contain_opn_haproxy_server('web01@opnsense01').with(
            ensure: 'present',
            tag: 'opnsense01',
          )
        end

        it 'exports to the second device' do
          expect(exported_resources).to contain_opn_haproxy_server('web01@opnsense02').with(
            ensure: 'present',
            tag: 'opnsense02',
          )
        end
      end
    end
  end
end
