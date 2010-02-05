
# ruby requirements
require 'pathname'
require 'fileutils'


require 'net/http'
# hack to disable SSL warnings issued by the right_http_connection gem
class Net::HTTP
  alias_method :old_initialize, :initialize
  def initialize(*args)
    old_initialize(*args)
    @ssl_context = OpenSSL::SSL::SSLContext.new
    @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
end


# gem requirements
require 'right_aws'

# hack to supress annoying log messages from right_aws gem
module Tunl
	class SilentLogger
		def self.info(msg)
		end
		def self.error(msg)
			puts "RIGHT AWS ERROR : #{msg}"
		end
		def self.warn(msg)
			puts "RIGHT AWS WARN: #{msg}"
		end
	end
end

module Tunl
	class Base
		
		def root
			@root ||= Pathname.new(File.expand_path("~/.tunl"))
		end
		
		def config
			@config ||= YAML.load(File.read(root.join('tunl.yml')))
		end
		
		def ec2
			@ec2 ||= RightAws::Ec2.new(config['aws_access_key'],config['aws_secret_key'], :logger => SilentLogger)
		end
		
		def key_pair_filepath(name)
			root.join("tunl_key_pair_#{name}")
		end
		
		def create_key_pair(name)
			log "create", "key pair tunl_#{name}"
			filepath = key_pair_filepath(name)
			key_pair = ec2.create_key_pair("tunl_#{name}")
			File.open(filepath, 'w') { |f| f.write(key_pair[:aws_material]) }
			FileUtils.chmod 0400, filepath
		rescue RightAws::AwsError => e
	    if e.message =~ /already exists/
	      # WARNING : this could be dangerous.
	      delete_key_pair(name)
	      retry
	    else
	      raise e
	    end
		end
		
		def delete_key_pair(name)
			log "delete", "key Pair tunl_#{name}"
			# delete key pair from amazon
			ec2.delete_key_pair("tunl_#{name}")
			# delete local file
			filepath = key_pair_filepath(name)
			if File.exists?(filepath)
				FileUtils.rm_f(filepath)
			end
		end
		
		def setup_key_pair(name)
			if ! File.exists?(key_pair_filepath(name))
				create_key_pair(name)
			end
		end
		
		def create_security_group(name)
			log "create", "security group tunl_#{name}"
			ec2.create_security_group("tunl_#{name}", 'created by tunl gem')
		rescue RightAws::AwsError => e
			if e.message =~ /already exists/
				return true
			else
				raise e
			end
		end
		
		def authorize_security_group(name)
			[ 22, 80 ].each do |port|
				begin
					ec2.authorize_security_group_IP_ingress("tunl_#{name}", port, port)
				rescue RightAws::AwsError => e
					if e.message =~ /already been authorized/
						# do nothing
					else
						raise e
					end
				end
			end
		end
		
		def delete_security_group(name)
			log "delete", "security group tunl_#{name}"
			ec2.delete_security_group("tunl_#{name}")
		end
		
		def find_security_group(name)
			ec2.describe_security_groups.find { |item| item[:aws_group_name]=="tunl_#{name}" }
		end
		
		def setup_security_group(name)
			# returns the names of all existing security groups prefixed with tunl_
			group = find_security_group(name)
			if group.nil?
				create_security_group(name)
				authorize_security_group(name)
			end
		end
		
		def find_instance(name)
			ec2.describe_instances.find { |item| item[:aws_groups].include?("tunl_#{name}") and (item[:aws_state].include?("pending") or item[:aws_state].include?("running")) }
		end
		
		def create_instance(name)
			# launch instance with:
			#  os - ubuntu hardy 32 bit
			#  security_group: tunl_name
			#  key_pair: tunl_name
			log "launch", "instance ..."
			instances = ec2.launch_instances('ami-ed46a784',
				:key_name => "tunl_#{name}",
				:group_ids => "tunl_#{name}",
				:instance_type => 'm1.small',
				:availability_zone => 'us-east-1a',
				:user_data => %Q{#!/bin/sh
					echo "starting" > /tmp/user_data_status.txt
					echo "GatewayPorts clientspecified" >> /etc/ssh/sshd_config
					/etc/init.d/ssh restart
					echo "finished" > /tmp/user_data_status.txt
				})
			log "", "#{instances.first[:aws_instance_id]}"	
		end
		
		def wait_for_instance(name)
			log "", "waiting for dns ..."
			while true
				break if ( find_instance(name) and find_instance(name)[:dns_name].size>0 )
				sleep(2)
			end
			log "", "done: #{find_instance(name)[:dns_name]}"
			require 'socket'     
			dns_name = find_instance(name)[:dns_name]
			log "", "waiting for ssh"
			loop do
				begin
					Timeout::timeout(4) do
						TCPSocket.new(dns_name, 22)
						log "", "done!"
						log ""
						return
					end
				rescue SocketError, Timeout::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH
					sleep(2)
				end
			end
		end
		
		def delete_instance(name)
			instance = find_instance(name)
		 	log "delete", "instance tunl_#{name} with id #{instance[:aws_instance_id]}"
			ec2.terminate_instances(instance[:aws_instance_id])
		end
		
		def setup_instance(name)
			instance = find_instance(name)
			if instance.nil?
				create_instance(name)
			else
				log "connect", "instance #{instance[:aws_instance_id]}"
			end
			wait_for_instance(name)
		end
		
		def find_all_instances
			ec2.describe_instances.find_all { |item| item[:aws_groups].first.include?('tunl_') and ['running', 'pending'].include?(item[:aws_state]) }
		end
		
		def log(action,message='')
			$stdout.printf("%-3s %-8s %-12s\n", '', action, message)
		end
		
	end 
end
