library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

entity HV_COUNTER is
	port(
			CLK			: in std_logic;										-- Clock.
			RST			: in std_logic;										-- Reset.
			PIXEL_CLK	: buffer std_logic;									-- Pixel clock.
			H_VGA_SYNC	: buffer std_logic;									-- VGA synchronous signal ( Horizontal ).
			V_VGA_SYNC	: buffer std_logic;									-- VGA synchronous signal ( Vertical ).
			H_COUNT		: buffer std_logic_vector( 9 downto 0 );		-- Horizontal count.
			V_COUNT		: buffer std_logic_vector( 9 downto 0 ) );	-- Vertical count.
end HV_COUNTER;

architecture RTL of HV_COUNTER is

	signal H_COUNT_MAX		: std_logic_vector( 9 downto 0 )		:= "1100100000";		-- Max horizontal count.
	signal V_COUNT_MAX		: std_logic_vector( 9 downto 0 )		:= "1000001101";		-- Max vertical count.
	
	signal H_SYNC_START			: std_logic_vector( 9 downto 0 )		:= "1010010111";		-- Horizontal start pixel.
	signal H_SYNC_END				: std_logic_vector( 9 downto 0 )		:= "1011110111";		-- Horizontal end pixel.
	signal V_SYNC_START			: std_logic_vector( 9 downto 0 )		:= "0111000001";		-- Vertical start pixel.
	signal V_SYNC_END				: std_logic_vector( 9 downto 0 )		:= "0111000011";		-- Vertical end pixel.
	
begin

	-- Generate PIXEL_CLK.
	process ( CLK, RST ) begin
		if( RST = '1' ) then
			PIXEL_CLK <= '0';
		elsif( CLK'event and CLK = '1' ) then
			PIXEL_CLK <= not PIXEL_CLK;
		end if;
	end process;
	
	-- Horizontal counter.
	process ( PIXEL_CLK, RST ) begin
		if( RST = '1' ) then
			H_COUNT <= ( others => '0' );
		elsif( PIXEL_CLK'event and PIXEL_CLK = '1' ) then
			if( H_COUNT = H_COUNT_MAX - 1 ) then
				H_COUNT <= ( others => '0' );
			else
				H_COUNT <= H_COUNT + '1';
			end if;
		end if;
	end process;
	
	-- Vertical counter.
	process ( PIXEL_CLK, RST ) begin
		if( RST = '1' ) then
			V_COUNT <= ( others => '0' );
		elsif( PIXEL_CLK'event and PIXEL_CLK = '1' ) then
			if( V_COUNT = V_COUNT_MAX - 1 ) then
				V_COUNT <= ( others => '0' );
			else
				V_COUNT <= V_COUNT + '1';
			end if;
		end if;
	end process;
	
	-- Horizontal synchronous signal.
	process ( PIXEL_CLK, RST ) begin
		if( RST = '1' ) then
			H_VGA_SYNC <= '1';
		elsif( PIXEL_CLK'event and PIXEL_CLK = '1' ) then
			if( H_COUNT = H_SYNC_START ) then
				H_VGA_SYNC <= '0';
			elsif( H_COUNT = H_SYNC_END ) then
				H_VGA_SYNC <= '1';
			end if;
		end if;
	end process;
	
	-- Vertical synchronous signal.
	process ( PIXEL_CLK, RST ) begin
		if( RST = '1' ) then
			V_VGA_SYNC <= '1';
		elsif( PIXEL_CLK'event and PIXEL_CLK = '1' ) then
			if( V_COUNT = V_SYNC_START ) then
				V_VGA_SYNC <= '0';
			elsif( V_COUNT = V_SYNC_END ) then
				V_VGA_SYNC <= '1';
			end if;
		end if;
	end process;

end RTL;