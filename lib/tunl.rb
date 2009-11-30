require 'davcro'

module Tunl
	class TunnelNode < Davcro::EC2::NodeRecord
		tablename 'tunnels'
		security_group 'tunnels', :open_ports => [ 22, 80 ] 
		image_id 'ami-ed46a784'
	end 
end
