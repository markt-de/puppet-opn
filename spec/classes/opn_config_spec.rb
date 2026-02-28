# frozen_string_literal: true

require 'spec_helper'

describe 'opn::config' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with defaults' do
        let(:params) do
          {
            'config_dir' => '/etc/puppet/opn',
            'devices'    => {},
            'owner'      => 'root',
            'group'      => 'root',
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates the provider config file' do
          is_expected.to contain_file("#{Puppet[:confdir]}/opn_provider.yaml").with(
            ensure: 'file',
            owner: 'root',
            group: 'root',
            mode: '0644',
          )
        end

        it 'creates the config directory' do
          is_expected.to contain_file('/etc/puppet/opn').with(
            ensure: 'directory',
            owner: 'root',
            group: 'root',
            mode: '0700',
          )
        end
      end

      context 'with devices' do
        let(:params) do
          {
            'config_dir' => '/etc/puppet/opn',
            'devices'    => {
              'fw01' => {
                'url'        => 'https://fw01.example.com/api',
                'api_key'    => 'mykey',
                'api_secret' => 'mysecret',
              },
            },
            'owner' => 'root',
            'group' => 'root',
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates per-device YAML file with mode 0600' do
          is_expected.to contain_file('/etc/puppet/opn/fw01.yaml').with(
            ensure: 'file',
            owner: 'root',
            group: 'root',
            mode: '0600',
            show_diff: false,
          )
        end

        it 'requires the config directory' do
          is_expected.to contain_file('/etc/puppet/opn/fw01.yaml').that_requires(
            'File[/etc/puppet/opn]',
          )
        end
      end
    end
  end
end
