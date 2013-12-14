library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

entity Rubikscam is
    port (
    CLOCK_50  : in std_logic;
    KEY       : in std_logic_vector( 3 downto 0);
    SW        : in std_logic_vector(15 downto 0);

	 SRAM_ADDR : out std_logic_vector(17 downto 0);
	 SRAM_DQ   : inout std_logic_vector(15 downto 0);
	 SRAM_WE_N : out std_logic;
	 SRAM_OE_N : out std_logic;
	 SRAM_UB_N : out std_logic;
	 SRAM_LB_N : out std_logic;
	 SRAM_CE_N : out std_logic;
	 
    VGA_CLK   : out std_logic; --Clock
    VGA_HS    : out std_logic; --H_SYNC
    VGA_VS    : out std_logic; --V_SYNC
    VGA_BLANK : out std_logic; --BLANK
    VGA_SYNC  : out std_logic; --SYNC
    VGA_R     : out std_logic_vector(9 downto 0); --Red[9:0]
    VGA_G     : out std_logic_vector(9 downto 0); --Green[9:0]
    VGA_B     : out std_logic_vector(9 downto 0); --Blue[9:0]
    
    LEDR	  : out std_logic_vector(16 downto 0);

    GPIO_1     : inout std_logic_vector(15 downto 0); -- depuis CMOS
	GPIO_0     : out std_logic_vector(15 downto 0) -- depuis CMOS
    );
end Rubikscam;

architecture Rubikscam_arch of Rubikscam is
----------------------------------------------------------------------------------------
-- PLL 25MHZ component declaration
----------------------------------------------------------------------------------------
component PLL_25 IS
	PORT
	(
		inclk0	: IN STD_LOGIC  := '0';
		c0		: OUT STD_LOGIC ; --100MHZ
		c1		: OUT STD_LOGIC ; --25MHZ
		c2		: OUT STD_LOGIC  -- 25Mhz + 10ns
	);
END component;
----------------------------------------------------------------------------------------
-- VGA output device declaration
----------------------------------------------------------------------------------------
component VGA_OUT is
    port (
	 -- CLOCK
    CLOCK_25  : in std_logic;
	 -- material ports
    VGA_CLK   : out std_logic; --Clock
    VGA_HS    : out std_logic; --H_SYNC
    VGA_VS    : out std_logic; --V_SYNC
    VGA_BLANK : out std_logic; --BLANK
    VGA_SYNC  : out std_logic; --SYNC
    VGA_R     : out std_logic_vector(9 downto 0); --Red[9:0]
    VGA_G     : out std_logic_vector(9 downto 0); --Green[9:0]
    VGA_B     : out std_logic_vector(9 downto 0); --Blue[9:0]
	 -- program used ports
	 SCREEN_X  : out integer range 0 to 639 := 0;
	 SCREEN_Y  : out integer range 0 to 479 := 0;
	 VGA_DATA_R : in std_logic_vector(9 downto 0);
	 VGA_DATA_G : in std_logic_vector(9 downto 0);
	 VGA_DATA_B : in std_logic_vector(9 downto 0)
    );
end component;
----------------------------------------------------------------------------------------
-- Camera dialog declaration
----------------------------------------------------------------------------------------
component CMOS_LA is
    port (
	 -- CLOCK
    CLOCK_25  : in std_logic;
	 -- material ports
    KEY       : in std_logic_vector( 3 downto 0);
    SW        : in std_logic_vector(15 downto 0);
    GPIO_1    : inout std_logic_vector(15 downto 0); -- direct link to CMOS (ie camera)
	 -- program used ports
	 CMOS_DATA : out std_logic_vector(9 downto 0); -- outgoing data from camera
	 CAM_X : out integer range 0 to ((640*2)-1);
	 CAM_Y : out integer range 0 to ((480*2)-1)
    );
end component;
----------------------------------------------------------------------------------------
-- motion sensing controler
----------------------------------------------------------------------------------------

component MOTION_SENSING is 
	port (
	CLOCK_25  : in std_logic;
	CLOCK_50  : in std_logic;
	KEY       : in std_logic_vector( 3 downto 0);
	CMOS_DATA : in std_logic_vector(9 downto 0);
	CAM_X 	 : in integer range 0 to ((640*2)-1);
	CAM_Y 	 : in integer range 0 to ((480*2)-1);
    CMD      : out std_logic_vector 
	);


----------------------------------------------------------------------------------------
-- 3D Engine
----------------------------------------------------------------------------------------

component ENGINE is
    port (
	 -- CLOCK
    CLOCK_25  : in std_logic;
	 -- material ports
	 -- program used ports
	 SCREEN_X : out integer range 0 to 639;
	 SCREEN_Y : out integer range 0 to 479
    );
end component;

signal CLOCK_25 : std_logic;
signal CLOCK_25d : std_logic;
signal CLOCK_100 : std_logic;
signal CMOS_DATA_m : std_logic_vector(9 downto 0);
signal screen_x : integer range 0 to 639 := 0;
signal screen_y : integer range 0 to 479 := 0;
signal vga_data_r : std_logic_vector(9 downto 0);
signal vga_data_g : std_logic_vector(9 downto 0);
signal vga_data_b : std_logic_vector(9 downto 0);
signal cam_x : integer range 0 to ((640*2)-1);
signal cam_y : integer range 0 to ((480*2)-1);
signal rw : integer range 0 to 3 := 0;

signal engine_out_x : integer range 0 to 639;
signal engine_out_y : integer range 0 to 479;

signal dqr : std_logic_vector(15 downto 0);
signal dqw : std_logic_vector(15 downto 0);

signal filled_sram : std_logic := '0';
signal fill_address : integer range 0 to 262143 := 0;
begin

--PLL instance declaration

pll_inst : PLL_25 PORT MAP (inclk0  => CLOCK_50, c0 => CLOCK_100, c1 => CLOCK_25, c2 => CLOCK_25d);

--3D engine instance declaration

engine_inst : ENGINE PORT MAP (CLOCK_25 => CLOCK_25d, 
SCREEN_X => engine_out_x, SCREEN_Y => engine_out_y);

--VGA output instance declaration

vga_inst : VGA_OUT PORT MAP (CLOCK_25=>CLOCK_25d, 
SCREEN_X => screen_x,SCREEN_Y => screen_y,
VGA_DATA_R => vga_data_r, VGA_DATA_G => vga_data_g,VGA_DATA_B => vga_data_b, 
VGA_CLK=>VGA_CLK, VGA_HS=>VGA_HS, VGA_VS=>VGA_VS,VGA_BLANK=>VGA_BLANK,VGA_SYNC=>VGA_SYNC,
VGA_R => VGA_R, VGA_G => VGA_G, VGA_B => VGA_B);

--CMOS driver instance declaration

CMOS_LA_inst : CMOS_LA PORT MAP (CLOCK_25 => CLOCK_25, 
KEY => KEY, SW => SW, GPIO_1 => GPIO_1,
CMOS_DATA => CMOS_DATA_m, CAM_X => cam_x, CAM_Y => cam_y);

--Motion sensing instance declaration

MOTION_SENSING_inst : MOTION_SENSING PORT MAP (CLOCK_25 => CLOCK_25, CLOCK_50 => CLOCK_50, KEY => KEY, CMOS_DATA => CMOS_DATA, CAM_X => CAM_X, CAM_Y => CAM_Y, CMD => CMD);

--test--
process (CLOCK_25) 
begin
	if rising_edge(CLOCK_25) then
		LEDR(to_integer(unsigned(CMD)) = 1;
	end if;
end process;

--programme--

process (CLOCK_100)
begin
	if rising_edge(CLOCK_100) then
		if rw < 3 then rw <= rw + 1; else rw <= 0; end if;
		
		if rw = 1 then 
			--read
			SRAM_UB_N <= '0';
			SRAM_LB_N <= '0';
			--SRAM_WE_N <= '1';
			SRAM_ADDR <= std_logic_vector(to_unsigned( (screen_x/2) + 320 * (screen_y/2)  ,18));
			vga_data_b <= dqr(9 downto 0);
			vga_data_r <= dqr(9 downto 0);
			vga_data_g <= dqr(9 downto 0);
		end if;
		
		-------------------------------------------------------------------------
		if rw = 2 then 
			SRAM_WE_N <= '0';
			SRAM_UB_N <= '0';
			SRAM_LB_N <= '0';
		
			if filled_sram = '0' then
				-- fill the screen in memory with black
				if fill_address < 262143 then
					fill_address <= fill_address + 1; 
				else
					fill_address <= 0;
					filled_sram <= '0';
				end if;
				SRAM_ADDR <= std_logic_vector(to_unsigned(fill_address,18));
				dqw <= "0000000000000000";
			else
				-- draw in memory the point given by the 3D engine
				SRAM_ADDR <= std_logic_vector(to_unsigned( (engine_out_x/2) + 320 * (engine_out_y/2) ,18));
				dqw(9 downto 0) <= "1111111111"; -- pixel color for the point to be drawn.
				dqw(15 downto 10) <= "000000";
			end if;
		end if;
		-------------------------------------------------------------------------
		
		
		if rw = 0 then 
			SRAM_WE_N <= '1';
			SRAM_UB_N <= '1';
			SRAM_LB_N <= '1';
		end if;
	
	
	end if;
end process;

dqr <= SRAM_DQ;
SRAM_DQ <= dqw when (rw = 3 and rw = 2) else "ZZZZZZZZZZZZZZZZ" ;
		

--For logicport
GPIO_0 <= GPIO_1;
--Memory
SRAM_OE_N <= '0';
SRAM_CE_N <= '0';

end Rubikscam_arch;
