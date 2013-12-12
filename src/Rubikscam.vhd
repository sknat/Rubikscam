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
		c0		: OUT STD_LOGIC ;
		c1		: OUT STD_LOGIC ;
		c2		: OUT STD_LOGIC 
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
    CLOCK_50  : in std_logic;
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

begin

pll_inst : PLL_25 PORT MAP (inclk0  => CLOCK_50, c0 => CLOCK_25, c1 => CLOCK_100);
engine_inst : ENGINE PORT MAP (CLOCK_25 => CLOCK_25, SCREEN_X => engine_out_x, SCREEN_Y => engine_out_y);
vga_inst : VGA_OUT PORT MAP (SCREEN_X => screen_x,SCREEN_Y => screen_y,VGA_DATA_R => vga_data_r,
VGA_DATA_G => vga_data_g,VGA_DATA_B => vga_data_b, CLOCK_25=>CLOCK_25,VGA_CLK=>VGA_CLK,VGA_HS=>VGA_HS,
VGA_VS=>VGA_VS,VGA_BLANK=>VGA_BLANK,VGA_SYNC=>VGA_SYNC,VGA_R=>VGA_R,VGA_G=>VGA_G,VGA_B=>VGA_B);

CMOS_LA_inst : CMOS_LA PORT MAP (CLOCK_25 => CLOCK_25, CLOCK_50 => CLOCK_50, KEY => KEY, SW => SW, GPIO_1 => GPIO_1, 
CMOS_DATA => CMOS_DATA_m, CAM_X=>cam_x,CAM_Y=>cam_y);

process (CLOCK_100)
begin
	if rising_edge(CLOCK_100) then
		if rw = 0 then 
			--read
			SRAM_ADDR <= std_logic_vector(to_unsigned( (screen_x/2) + 320 * (screen_y/2)  ,18));
			SRAM_OE_N <= '0';
			SRAM_WE_N <= '1';
			vga_data_b <= dqr(9 downto 0);
			vga_data_r <= dqr(9 downto 0);
			vga_data_g <= dqr(9 downto 0);
			rw<=1;
		elsif rw = 1 then
			--write
			SRAM_OE_N <= '1';
			SRAM_WE_N <= '1';
			SRAM_ADDR <= std_logic_vector(to_unsigned( (engine_out_x/2) + 320 * (engine_out_y/2) ,18));

			dqw(9 downto 0) <= "1111111111";
			dqw(15 downto 10) <= "000000";
			
			rw<=2;
		elsif rw = 2 then
			SRAM_WE_N <= '0';
			rw<=3;
		elsif rw = 3 then
			SRAM_WE_N <= '1';
			rw<=0;
		end if;
	end if;
end process;


dqr <= SRAM_DQ;
SRAM_DQ <= dqw when (rw > 0) else "ZZZZZZZZZZZZZZZZ";
		

--For logicport
GPIO_0 <= GPIO_1;
--Memory
SRAM_CE_N <= '0';
SRAM_UB_N <= '0';
SRAM_LB_N <= '0';

end Rubikscam_arch;
