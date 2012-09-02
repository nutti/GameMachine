library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

entity VGA is
	port(
			CLK		: in std_logic;									-- Clock.
			RST		: in std_logic;									-- Reset.
			ADDR		: in std_logic_vector( 11 downto 0 );		-- Address.
			BYTE_EN	: in std_logic_vector( 3 downto 0 );
			WR_EN		: in std_logic;									-- Write enable.
			RD_EN		: in std_logic;									-- Read enable.
			WR_DATA	: in std_logic_vector( 31 downto 0 );		-- Write data.
			RD_DATA	: out std_logic_vector( 31 downto 0 );		-- Read data.
			VGA_R		: buffer std_logic_vector( 3 downto 0 );	-- VGA ( Red ).
			VGA_G		: buffer std_logic_vector( 3 downto 0 );	-- VGA ( Green ).
			VGA_B		: buffer std_logic_vector( 3 downto 0 );	-- VGA ( Blue ).
			VGA_H		: out std_logic;									-- VGA ( Horizontal ).
			VGA_V		: out std_logic );								-- VGA ( Vertical ).
end VGA;

architecture RTL of VGA is

	-- Signals.
	
	-- Signals for HV_COUNTER.
	signal H_COUNT		: std_logic_vector( 9 downto 0 );		-- Horizontal count.
	signal V_COUNT		: std_logic_vector( 9 downto 0 );		-- Vertical count.
	signal PIXEL_CLK	: std_logic;									-- Pixel clock.
	
	-- Signals used for VRAM.
	signal VRAM_DATA_OUT		: std_logic_vector( 31 downto 0 );		-- VRAM output data.
	signal VRAM_RD_ADDR		: std_logic_vector( 11 downto 0 );		-- Read address used for VRAM.
	signal VRAM_ADDR			: std_logic_vector( 11 downto 0 );		-- PIXEL_CLK based VRAM address.
	signal VRAM_ADDR_INT		: integer;
	
	-- Signals for CGROM.
	signal V_PIXEL_COUNT		: std_logic_vector( 2 downto 0 );		-- Vertical count for 1 pixel.
	signal H_PIXEL_COUNT		: std_logic_vector( 2 downto 0 );		-- Horizontal count for 1 pixel.
	signal CGROM_DATA_OUT	: std_logic_vector( 7 downto 0 );		-- CGROM output data.
	
	-- Signals for character count.
	signal V_CHAR_COUNT		: std_logic_vector( 5 downto 0 );		-- Vertical count for 1 character.
	signal H_CHAR_COUNT		: std_logic_vector( 6 downto 0 );		-- Horizontal count for 1 character.
	
	-- Signals for shift register.
	signal SHIFT_REG			: std_logic_vector( 7 downto 0 );		-- Shift register.
	signal LOAD_SHIFT_REG	: std_logic;									-- Load shift register.
	
	-- RGB data.
	signal RGB					: std_logic_vector( 11 downto 0 );
	
	-- Enable signal for display.
	signal H_DISP_EN			: std_logic;									-- Horizontal display enable signal.
	signal V_DISP_EN			: std_logic;									-- Vertical display enable signal.
	
	
	-- Components.
	
	-- HV_COUNTER.
	component HV_COUNTER
	port(
			CLK			: in std_logic;										-- Clock.
			RST			: in std_logic;										-- Reset.
			PIXEL_CLK	: buffer std_logic;									-- Pixel clock.
			H_VGA_SYNC	: buffer std_logic;									-- VGA synchronous signal ( Horizontal ).
			V_VGA_SYNC	: buffer std_logic;									-- VGA synchronous signal ( Vertical ).
			H_COUNT		: buffer std_logic_vector( 9 downto 0 );		-- Horizontal count.
			V_COUNT		: buffer std_logic_vector( 9 downto 0 ) );	-- Vertical count.
	end component;
	
	-- VRAM.
	component VRAM
	port(
			byteena_a		: in std_logic_vector( 3 downto 0 );
			clock				: in std_logic;
			data				: in std_logic_vector( 31 downto 0 );
			rdaddress		: in std_logic_vector( 11 downto 0 );
			wraddress		: in std_logic_vector( 11 downto 0 );
			wren				: in std_logic;
			q					: out std_logic_vector( 31 downto 0 ) );
	end component;
	
	-- CGROM
	component CGROM
	port(
			address		: in std_logic_vector( 9 downto 0 );
			clock			: in std_logic;
			q				: out std_logic_vector( 7 downto 0) );
	end component;
	

begin

	-- Components.
	INS_HV_COUNTER : HV_COUNTER
	port map(
		CLK			=> CLK,
		RST			=> RST,
		PIXEL_CLK	=> PIXEL_CLK,
		H_VGA_SYNC	=> VGA_H,
		V_VGA_SYNC	=> VGA_V,
		H_COUNT		=> H_COUNT,
		V_COUNT		=> V_COUNT );
		
	INS_VRAM : VRAM
	port map(
		byteena_a	=> BYTE_EN,
		clock			=> CLK,
		data			=> WR_DATA,
		rdaddress	=> VRAM_RD_ADDR,
		wraddress	=> ADDR,
		wren			=> WR_EN,
		q				=> VRAM_DATA_OUT );
		
	INS_CGROM : CGROM
	port map(
		address		=> VRAM_DATA_OUT( 6 downto 0 ) & V_PIXEL_COUNT,
		clock			=> PIXEL_CLK,
		q				=> CGROM_DATA_OUT );
	

	-- Data for VRAM.
	VRAM_RD_ADDR <=	ADDR when RD_EN = '1' else
							VRAM_ADDR;
	RD_DATA <= VRAM_DATA_OUT;
	
	-- Separate each counters.
	H_CHAR_COUNT <= H_COUNT( 9 downto 3 );
	V_CHAR_COUNT <= V_COUNT( 8 downto 3 );
	H_PIXEL_COUNT <= H_COUNT( 2 downto 0 );
	V_PIXEL_COUNT <= V_COUNT( 2 downto 0 );
	
	-- Make VRAM address.
	VRAM_ADDR_INT <= CONV_INTEGER( V_CHAR_COUNT ) * 80 + CONV_INTEGER( H_CHAR_COUNT );
	VRAM_ADDR <= CONV_STD_LOGIC_VECTOR( VRAM_ADDR_INT, 12 );
	--VRAM_ADDR <= ( V_CHAR_COUNT sll 6 ) + ( V_CHAR_COUNT sll 4 ) + H_CHAR_COUNT;
	
	-- Load signal for CGROM.
	LOAD_SHIFT_REG <=	'1' when H_PIXEL_COUNT = "110" and H_COUNT < "1010000000" else
							'0';
	
	-- Shift register.
	process ( PIXEL_CLK, RST ) begin
		if( RST = '1' ) then
			SHIFT_REG <= ( others => '0' );
		elsif( PIXEL_CLK'event and PIXEL_CLK = '1' ) then
			if( LOAD_SHIFT_REG = '1' ) then
				SHIFT_REG <= CGROM_DATA_OUT;
			else
				SHIFT_REG <= SHIFT_REG( 6 downto 0 ) & '0';
			end if;
		end if;
	end process;
	
	-- Output RGB data.
	process( PIXEL_CLK, RST ) begin
		if( RST = '1' ) then
			RGB <= ( others => '0' );
		elsif( PIXEL_CLK'event and PIXEL_CLK = '1' ) then
			if( LOAD_SHIFT_REG = '1' ) then
				-- RGB data is [27-16] in VRAM.
				RGB <= VRAM_DATA_OUT( 27 downto 16 );
			end if;
		end if;
	end process;
	
	-- Output display enable signal.
	
	process( PIXEL_CLK, RST ) begin
		if( RST = '1' ) then
			VGA_R <= ( others => '0' );
			VGA_G <= ( others => '0' );
			VGA_B <= ( others => '0' );
		elsif( PIXEL_CLK'event and PIXEL_CLK = '1' ) then
			if( H_DISP_EN = '1' and V_DISP_EN = '1' and SHIFT_REG( 7 ) = '1' ) then
				VGA_R <= RGB( 11 downto 8 );
				VGA_G <= RGB( 7 downto 4 );
				VGA_B <= RGB( 3 downto 0 );
			end if;
		end if;
	end process;

end RTL;