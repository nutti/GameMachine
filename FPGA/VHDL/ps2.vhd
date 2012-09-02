library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

entity PS2 is
	port(
			CLK		: in std_logic;								-- Clock.
			RST		: in std_logic;								-- Reset.
			ADDR		: in std_logic_vector( 1 downto 0 );	-- 0:status, 1:read data, 2:write data
			WR_EN		: in std_logic;								-- Write enable.
			WR_DATA	: in std_logic_vector( 7 downto 0 );	-- Write data.
			RD_DATA	: out std_logic_vector( 7 downto 0 );	-- Read data.
			PS2_CLK	: inout std_logic;							-- PS2 clock.
			PS2_DATA	: inout std_logic;							-- PS2 data. (serial line)
			LOG_CLK	: buffer std_logic );
end PS2;

architecture RTL of PS2 is
	-- Registers.
	signal SHIFT_REG		: std_logic_vector( 9 downto 0 );		-- 10-bit shift register.
	signal PS2_RD_DATA	: std_logic_vector( 7 downto 0 );		-- PS2 data.
	signal EMPTY			: std_logic;
	signal VALID			: std_logic;
	-- Types and signals for state machine.
	type PS2_INTERFACE_STATE is (	HALT,					-- Halt.
											FALL_CLK,			-- Fall PS2 clock.
											SEND_START_BIT,		-- Send start bit.
											SEND_DATA,			-- Send PS2 data.
											WAIT_CLK_FALLEN,	-- Wait until PS2 clock is fallen.
											RECEIVE_DATA,		-- Receive PS2 data.
											VALIDATE_PS2 );	-- Set PS2VALID flag.
	signal CUR_STATE		: PS2_INTERFACE_STATE		:= HALT;		-- Current state.
	signal NEXT_STATE		: PS2_INTERFACE_STATE		:= HALT;		-- Next state.
	-- Signals for generating 100us.
	signal BIT_PATTERN_100U					: std_logic_vector( 12 downto 0 )	:= "1001110000111";		-- Bit pattern for 100us (Actually 100us - 1bit).
	signal ELASPED_100US						: std_logic									:= '0';						-- Elapsed 100us?
	signal COUNTER								: std_logic_vector( 12 downto 0 )	:= ( others => '0' );	-- 13-bit counter.
	-- Signals for detecting the falling edge of PS2 clock.
	signal REG									: std_logic_vector( 2 downto 0 )		:= ( others => '0' );	-- Buffer.
	signal DETECT_PS2CLK_FALL_EDGE		: std_logic									:= '0';						-- Does detect falling edge of PS2?
	-- Counter for bit position.
	signal IO_BIT_POSITION					: std_logic_vector( 3 downto 0 )		:= ( others => '0' );	-- Bit position for send/receive data.
	-- Signals for the debug.
	signal LOG_COUNT							: std_logic_vector( 4 downto 0 )		:= ( others => '0' );
begin

	-- Readout shift register.
	RD_DATA	<=	"000000" & EMPTY & VALID when ADDR = "00" else	-- Read status.
					PS2_RD_DATA;												-- Read PS2 data.

	-- Send PS2 clock.
	-- This description prevents hazard from PS2 clock.
	process ( CLK, RST ) begin
		if( RST = '1' ) then
			PS2_CLK	<= 'Z';
		elsif( CLK'event and CLK = '1' ) then
			if( CUR_STATE = FALL_CLK or CUR_STATE = SEND_START_BIT ) then
				PS2_CLK	<= '0';
			else
				PS2_CLK	<= 'Z';
			end if;
		end if;
	end process;
	
	-- Output data for PS2.
	PS2_DATA <=	SHIFT_REG( 0 ) when CUR_STATE = SEND_DATA or CUR_STATE = SEND_START_BIT else
					'Z';
					
	-- Measure 100us.
	ELASPED_100US <=	'1' when COUNTER = BIT_PATTERN_100U else
							'0';
	process ( CLK, RST ) begin
		if( RST = '1' ) then
			COUNTER <= ( others => '0' );
		elsif( CLK'event and CLK = '1' ) then
			if( CUR_STATE = HALT or ELASPED_100US = '1' ) then
				COUNTER <= ( others => '0' );
			else
				COUNTER <= COUNTER + '1';
			end if;
		end if;
	end process;
	
	-- Detect fall edge of PS2 clock with synchronized.
	process ( CLK, RST ) begin
		if( RST = '1' ) then
			REG	<= ( others => '0' );
		elsif( CLK'event and CLK = '1' ) then
			REG	<= REG( 1 downto 0 ) & PS2_CLK;
		end if;
	end process;
	DETECT_PS2CLK_FALL_EDGE <= REG( 2 ) and not REG( 1 );
	
	-- Update bit position for send/receive data.
	process ( CLK, RST ) begin
		if( RST = '1' ) then
			IO_BIT_POSITION	<= ( others => '0' );
		elsif( CLK'event and CLK = '1' ) then
			if( CUR_STATE = HALT ) then
				IO_BIT_POSITION	<= ( others => '0' );
			elsif( ( CUR_STATE = SEND_DATA or CUR_STATE = RECEIVE_DATA ) and DETECT_PS2CLK_FALL_EDGE = '1' ) then
				IO_BIT_POSITION	<= IO_BIT_POSITION + '1';
			end if;
		end if;
	end process;
	
	-- State machine.
	process ( CLK, RST ) begin
		if( RST = '1' ) then
			CUR_STATE <= HALT;
		elsif( CLK'event and CLK = '1' ) then
			CUR_STATE <= NEXT_STATE;
		end if;
	end process;
	
	-- Update state.
	process ( CLK, RST ) begin
		case ( CUR_STATE ) is
			-- Not operation.
			when HALT =>
				if( ( ADDR = "10" ) and WR_EN = '1' ) then
					NEXT_STATE <= FALL_CLK;
				elsif( PS2_DATA = '0' and DETECT_PS2CLK_FALL_EDGE = '1' ) then
					NEXT_STATE <= RECEIVE_DATA;
				else
					NEXT_STATE <= HALT;
				end if;
			-- Wait falling edge of PS2 clock.
			when FALL_CLK =>
				if( ELASPED_100US = '1' ) then
					NEXT_STATE <= SEND_START_BIT;
				else
					NEXT_STATE <= FALL_CLK;
				end if;
			-- Send start bit.
			when SEND_START_BIT =>
				if( ELASPED_100US = '1' ) then
					NEXT_STATE <= SEND_DATA;
				else
					NEXT_STATE <= SEND_START_BIT;
				end if;
			-- Send PS2 data.
			when SEND_DATA =>
				if( IO_BIT_POSITION = "1001" and DETECT_PS2CLK_FALL_EDGE = '1' ) then
					NEXT_STATE <= WAIT_CLK_FALLEN;
				else
					NEXT_STATE <= SEND_DATA;
				end if;
			-- Wait until PS2 clock is fallen.
			when WAIT_CLK_FALLEN =>
				if( DETECT_PS2CLK_FALL_EDGE = '1' ) then
					NEXT_STATE <= HALT;
				else
					NEXT_STATE <= WAIT_CLK_FALLEN;
				end if;
			-- Receive PS2 data.
			when RECEIVE_DATA =>
				if( IO_BIT_POSITION = "0111" and DETECT_PS2CLK_FALL_EDGE = '1' ) then
					NEXT_STATE <= VALIDATE_PS2;
				else
					NEXT_STATE <= RECEIVE_DATA;
				end if;
			-- Set PS2VALID flag.
			when VALIDATE_PS2 =>
				if( DETECT_PS2CLK_FALL_EDGE = '1' ) then
					NEXT_STATE <= WAIT_CLK_FALLEN;
				else
					NEXT_STATE <= VALIDATE_PS2;
				end if;
			when others =>
				NEXT_STATE <= HALT;
		end case;
	end process;
	
	-- Set empty flag.
	process ( CLK, RST ) begin
		if( RST = '1' ) then
			EMPTY <= '1';
		elsif( CLK'event and CLK = '1' ) then
			if( CUR_STATE = HALT ) then
				EMPTY <= '1';
			else
				EMPTY <= '0';
			end if;
		end if;
	end process;
	
	-- Set valid flag.
	process ( CLK, RST ) begin
		if( RST = '1' ) then
			VALID <= '1';
		elsif( ADDR = "00" and WR_EN = '1' ) then
			VALID <= WR_DATA( 0 );
		elsif( CUR_STATE = VALIDATE_PS2 and DETECT_PS2CLK_FALL_EDGE = '1' ) then
			VALID <= '1';
		end if;
	end process;
	
	-- Shift register.
	process ( CLK, RST ) begin
		if( RST = '1' ) then
			SHIFT_REG( 9 downto 0 ) <= ( others => '0' );
		elsif( CLK'event and CLK = '1' ) then
			if( ( ADDR = "10" ) and WR_EN = '1' ) then
				SHIFT_REG( 9 downto 0 ) <= NOT XNOR_REDUCE( WR_DATA ) & WR_DATA & '0';
			elsif( ( CUR_STATE = SEND_DATA ) and ( DETECT_PS2CLK_FALL_EDGE = '1' ) ) then
				SHIFT_REG( 9 downto 0 ) <= '1' & SHIFT_REG( 9 downto 1 );
			elsif( ( CUR_STATE = RECEIVE_DATA ) and ( DETECT_PS2CLK_FALL_EDGE = '1' ) ) then
				SHIFT_REG( 9 downto 0 ) <= PS2_DATA & SHIFT_REG( 9 downto 1 );
			end if;
		end if;
	end process;
	 
	-- Received data.
	process ( CLK, RST ) begin
		if( RST = '1' ) then
			PS2_RD_DATA <= ( others => '0' );
		elsif( CUR_STATE = VALIDATE_PS2 and DETECT_PS2CLK_FALL_EDGE = '1' ) then
			PS2_RD_DATA <= SHIFT_REG( 9 downto 2 );
		end if;
	end process;
	
	-- For debug.
	process ( CLK, RST ) begin
		if( RST = '1' ) then
			LOG_COUNT	<= ( others => '0' );
		elsif( CLK'event and CLK = '1' ) then
			if( LOG_COUNT = "11000" ) then
				LOG_COUNT <= ( others => '0' );
			else
				LOG_COUNT <= LOG_COUNT + '1';
			end if;
		end if;
	end process;
	
	process ( CLK, RST ) begin
		if( RST = '1' ) then
			LOG_CLK <= '0';
		elsif( CLK'event and CLK= '1' ) then
			if( LOG_COUNT = "11000" ) then
				LOG_CLK <= not LOG_CLK;
			end if;
		end if;
	end process;
	
end RTL;