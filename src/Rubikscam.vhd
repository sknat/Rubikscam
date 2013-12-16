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
    
    LEDR	  : out std_logic_vector(17 downto 0);

    GPIO_1     : inout std_logic_vector(15 downto 0); -- depuis CMOS
	 GPIO_0     : inout std_logic_vector(15 downto 0) -- depuis CMOS
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
	KEY       : in std_logic_vector(3 downto 0);
	CMOS_DATA : in std_logic_vector(9 downto 0);
	CAM_X 	 : in integer range 0 to ((640*2)-1);
	CAM_Y 	 : in integer range 0 to ((480*2)-1);
   CMD      : out std_logic_vector (5 downto 0)
	);
end component;

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
	 SCREEN_Y : out integer range 0 to 479;
	 VALID_OUT : out std_logic
    );
end component;

signal CLOCK_25 : std_logic;
signal CLOCK_25d : std_logic;
signal CLOCK_50d : std_logic;
signal CMOS_DATA_m : std_logic_vector(9 downto 0);
signal screen_x : integer range 0 to 639 := 0;
signal screen_y : integer range 0 to 479 := 0;
signal vga_data_r : std_logic_vector(9 downto 0);
signal vga_data_g : std_logic_vector(9 downto 0);
signal vga_data_b : std_logic_vector(9 downto 0);
signal vga_in_blank : std_logic;
signal cam_x : integer range 0 to ((640*2)-1);
signal cam_y : integer range 0 to ((480*2)-1);
signal rw : std_logic := '0';

signal engine_out_x : integer range 0 to 639;
signal engine_out_y : integer range 0 to 479;
signal engine_valid_out : std_logic;

signal dqr : std_logic_vector(15 downto 0);
signal dqw : std_logic_vector(15 downto 0);
signal sram_data_write_driver : std_logic := '0';
signal sram_data_read_driver : std_logic := '0';

signal filled_sram : std_logic := '1';
signal fill_address : integer range 0 to 262143 := 0;

signal CMD : std_logic_vector (5 downto 0);
signal SRAM_WE_N_cp : std_logic;
begin

--PLL instance declaration

pll_inst : PLL_25 PORT MAP (inclk0  => CLOCK_50, c0 => CLOCK_50d, c1 => CLOCK_25, c2 => CLOCK_25d);

--3D engine instance declaration

engine_inst : ENGINE PORT MAP (CLOCK_25 => CLOCK_25d, 
SCREEN_X => engine_out_x, SCREEN_Y => engine_out_y, VALID_OUT => engine_valid_out);
--VGA output instance declaration

vga_inst : VGA_OUT PORT MAP (CLOCK_25=>CLOCK_25d, 
SCREEN_X => screen_x,SCREEN_Y => screen_y,
VGA_DATA_R => vga_data_r, VGA_DATA_G => vga_data_g,VGA_DATA_B => vga_data_b, 
VGA_CLK=>VGA_CLK, VGA_HS=>VGA_HS, VGA_VS=>VGA_VS,VGA_BLANK=>vga_in_blank,VGA_SYNC=>VGA_SYNC,
VGA_R => VGA_R, VGA_G => VGA_G, VGA_B => VGA_B);

--CMOS driver instance declaration

CMOS_LA_inst : CMOS_LA PORT MAP (CLOCK_25 => CLOCK_25, 
KEY => KEY, SW => SW, GPIO_1 => GPIO_1,
CMOS_DATA => CMOS_DATA_m, CAM_X => cam_x, CAM_Y => cam_y);

--Motion sensing instance declaration

MOTION_SENSING_inst : MOTION_SENSING PORT MAP (CLOCK_25 => CLOCK_25, CLOCK_50 => CLOCK_50, 
KEY => KEY, CMOS_DATA => CMOS_DATA_m, CAM_X => cam_x, CAM_Y => cam_y, CMD => CMD);

--test--
SRAM_WE_N <= SRAM_WE_N_cp;
LEDR(5 downto 0) <= CMD;
LEDR(17) <= engine_valid_out;
LEDR(16) <= SRAM_WE_N_cp;
LEDR(15) <= sram_data_read_driver;
LEDR(14) <= sram_data_write_driver;

--programme--

process (CLOCK_50d)
begin
	if rising_edge(CLOCK_50d) then
		rw <= not rw;
		
		--Reading from sram
		if rw = '0' and vga_in_blank = '1' then
			SRAM_WE_N_cp <= '1';
			sram_data_write_driver <= '0';-- after 2ns; --wait for the write to be effective
			sram_data_read_driver <= '1' after 10ns;
			
			SRAM_ADDR(9 downto 0) <= std_logic_vector(to_unsigned(screen_x,10));
			SRAM_ADDR(17 downto 10) <= std_logic_vector(to_unsigned(screen_y/2,8));
			if screen_y mod 2 = 0 then 
				vga_data_r(9 downto 7) <= dqr(15 downto 13);
				vga_data_g(9 downto 8) <= dqr(12 downto 11);
				vga_data_b(9 downto 7) <= dqr(10 downto 8);
			else
				vga_data_r(9 downto 7) <= dqr(7 downto 5);
				vga_data_g(9 downto 8) <= dqr(4 downto 3);
				vga_data_b(9 downto 7) <= dqr(2 downto 0);
			end if;
				vga_data_r(6 downto 0) <= (others=>'0');
				vga_data_g(7 downto 0) <= (others=>'0');
				vga_data_b(6 downto 0) <= (others=>'0');
		end if;		
		--Writing to sram
		----------------------------------------------------------
		--Set the valid address and data--
		if rw = '1' then
			if filled_sram = '0' then
			-- fill the screen in memory with black
				if fill_address < 262143 then
					fill_address <= fill_address + 1; 
				else
					fill_address <= 0;
					filled_sram <= '1';
				end if;
				
				SRAM_ADDR <= std_logic_vector(to_unsigned(fill_address,18));
				dqw <= "0000000000000000";

			elsif engine_valid_out = '1' then
				-- draw in memory the point given by the 3D engine
				--SRAM_ADDR <= std_logic_vector(to_unsigned( (engine_out_x/2) + 320 * (engine_out_y/2) ,18));
				SRAM_ADDR(9 downto 0) <= std_logic_vector(to_unsigned(10,10));
				SRAM_ADDR(17 downto 10) <= std_logic_vector(to_unsigned(10/2,8));
				
				dqw <= "1110000000011000"; -- pixel color for the point to be drawn.
			end if;
			SRAM_WE_N_cp <= '0';
			sram_data_write_driver <= '1';
			sram_data_read_driver <= '0';
		end if;
	
	end if;
end process;

-- inout driver for SRAM data
dqr <= SRAM_DQ when (sram_data_read_driver = '1') else dqr;
SRAM_DQ <= dqw when (sram_data_write_driver = '1') else "ZZZZZZZZZZZZZZZZ" ;
		

--For logicport analysis of the camera
GPIO_0 <= GPIO_1;
--Memory
SRAM_UB_N <= '0';
SRAM_LB_N <= '0';
SRAM_OE_N <= '0';
SRAM_CE_N <= '0';
--
VGA_BLANK <= vga_in_blank;

end Rubikscam_arch;
