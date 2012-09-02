library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity REG16 is
	port(
			-- Busses for Avalon.
			CLK		: in std_logic;									-- Clock.
			RST		: in std_logic;									-- Reset.
			ADDR		: in std_logic_vector( 1 downto 0 );		-- Register address.
			WR_EN		: in std_logic;									-- Write enable.
			RD_EN		: in std_logic;									-- Read enable.
			WR_DATA	: in std_logic_vector( 15 downto 0 );		-- Write data.
			BYTE_EN	: in std_logic_vector( 1 downto 0 );		-- Byte enable.
			RD_DATA	: out std_logic_vector( 15 downto 0 ) );	-- Read data.
end REG16;

architecture RTL of REG16 is
	-- Registers.
	signal REG_0		: std_logic_vector( 15 downto 0 )	:= ( others => '0' );
	signal REG_1		: std_logic_vector( 15 downto 0 )	:= ( others => '0' );
	signal REG_2		: std_logic_vector( 15 downto 0 )	:= ( others => '0' );
	signal REG_3		: std_logic_vector( 15 downto 0 )	:= ( others => '0' );
begin

	-- For register 0.
	process ( CLK, RST ) begin
		-- Reset
		if( RST = '1' ) then
			REG_0 <= ( others => '0' );
			REG_1 <= ( others => '0' );
			REG_2 <= ( others => '0' );
			REG_3 <= ( others => '0' );
		elsif( CLK'event and CLK = '1' ) then
			if( WR_EN = '1' and ADDR = "00" ) then
				-- Lower data.
				if( BYTE_EN( 0 ) = '1' ) then
					REG_0( 7 downto 0 ) <= WR_DATA( 7 downto 0 );
				end if;
				-- Higher data.
				if( BYTE_EN( 1 ) = '1' ) then
					REG_0( 15 downto 8 ) <= WR_DATA( 15 downto 8 );
				end if;
			elsif( WR_EN = '1' and ADDR = "01" ) then
				-- Lower data.
				if( BYTE_EN( 0 ) = '1' ) then
					REG_1( 7 downto 0 ) <= WR_DATA( 7 downto 0 );
				end if;
				-- Higher data.
				if( BYTE_EN( 1 ) = '1' ) then
					REG_1( 15 downto 8 ) <= WR_DATA( 15 downto 8 );
				end if;
			elsif( WR_EN = '1' and ADDR = "10" ) then
				-- Lower data.
				if( BYTE_EN( 0 ) = '1' ) then
					REG_2( 7 downto 0 ) <= WR_DATA( 7 downto 0 );
				end if;
				-- Higher data.
				if( BYTE_EN( 1 ) = '1' ) then
					REG_2( 15 downto 8 ) <= WR_DATA( 15 downto 8 );
				end if;
			elsif( WR_EN = '1' and ADDR = "11" ) then
				-- Lower data.
				if( BYTE_EN( 0 ) = '1' ) then
					REG_3( 7 downto 0 ) <= WR_DATA( 7 downto 0 );
				end if;
				-- Higher data.
				if( BYTE_EN( 1 ) = '1' ) then
					REG_3( 15 downto 8 ) <= WR_DATA( 15 downto 8 );
				end if;
			end if;
		end if;
	end process;
	
	-- Readout
	with ( ADDR ) select RD_DATA <=
		REG_0 when "00",
		REG_1 when "01",
		REG_2 when "10",
		REG_3 when "11",
		( others => '0' ) when others;

end RTL;