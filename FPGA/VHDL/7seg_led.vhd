library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity SEG7_LED is
	port(
			-- Busses for Avalon.
			CLK		: in std_logic;								-- Clock.
			RST		: in std_logic;								-- Reset.
			ADDR		: in std_logic;								-- Address. ( Read or Write? )
			WR			: in std_logic;								-- Write enable.
			RD			: in std_logic;								-- Read enable.
			WR_DATA	: in std_logic_vector( 7 downto 0 );	-- Write data.
			RD_DATA	: out std_logic_vector( 7 downto 0 );	-- Read data.
			-- Ports.
			SW			: in std_logic_vector( 3 downto 0 );	-- Switch.
			nHEX		: buffer std_logic_vector( 7 downto 0 )	-- 7 segment LED.
			);
end SEG7_LED;

architecture RTL of SEG7_LED is
begin

	process ( CLK, RST ) begin
		if( CLK'event and CLK = '1' ) then
			if( RST = '1' ) then
				nHEX <= ( others => '1' );	-- Switch off.
			elsif( WR = '1' and ADDR = '0' ) then
				nHEX <= WR_DATA;
			end if;
		end if;
	end process;
	
	RD_DATA <=	( others => '0' ) when RD = '0' else
					nHEX when ADDR = '0' else
					"0000" & SW;

end RTL;