require File.dirname(__FILE__) + '/../lib/tunl'

require 'test/unit'

class TestTunl < Test::Unit::TestCase
	
	def setup
		@tunl = Tunl::Base.new
	end
	
	def test_create
		@tunl.setup_security_group("test")
		@tunl.setup_key_pair("test")
		@tunl.setup_instance("test")
		
	end            
	
	def test_delete
		@tunl.delete_instance("test")
		@tunl.delete_security_group("test")
		@tunl.delete_key_pair("test")
	end  
	
end
