library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

entity CMOS_LA is
    port (
	 -- CLOCK
    CLOCK_50  : in std_logic;
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
end CMOS_LA;

architecture CMOS_LA_arch of CMOS_LA is
-- configuration du CMOS par le bus I2C
component I2C_CMOS_Config is
    port (
    clk        : in std_logic;
    rst_n      : in std_logic;
    exposition : in std_logic_vector(15 downto 0);
    I2C_SCLK   : out std_logic;
    I2C_SDAT   : inout std_logic
    );
end component;

constant seuil     : std_logic_vector(9 downto 0) := "1000000000" ;
signal cam_pos_x : integer range 0 to ((640*2)-1) := 0;
signal cam_pos_y : integer range 0 to ((480*2)-1) := 0;

signal CMOS_SDAT   : std_logic;
signal CMOS_SCLK   : std_logic;
signal CMOS_FVAL   : std_logic;
signal CMOS_LVAL   : std_logic;
signal CMOS_PIXCLK : std_logic;

signal rst_n      : std_logic;
signal exposition : std_logic_vector(15 downto 0);

signal FVAL : std_logic;
signal LVAL : std_logic;
signal LVAL_1 : std_logic;
signal LVAL_2 : std_logic;
signal FVAL_1 : std_logic;
signal FVAL_2 : std_logic;

begin

rst_n <= KEY(0);
exposition <= SW(15 downto 0);

-- from CMOS
CMOS_DATA   <= GPIO_1(9 downto 0);
CMOS_PIXCLK <= GPIO_1(10);
CMOS_LVAL   <= GPIO_1(12);
CMOS_FVAL   <= GPIO_1(13);

-- to CMOS
GPIO_1(11) <= CLOCK_25; -- 25MHz

I2C_CMOS_Config_inst : I2C_CMOS_Config
port map (
          clk        => CLOCK_50,
          rst_n      => rst_n,
          exposition => exposition,
          I2C_SCLK   => GPIO_1(14), -- !!!! inout vers/depuis CMOS
          I2C_SDAT   => GPIO_1(15)  -- !!!! inout vers/depuis CMOS
          );

process (CMOS_PIXCLK)
begin
	if rising_edge(CMOS_PIXCLK) then
	--generate square signal on each frame valid / line valid signal
		FVAL_1 <= CMOS_FVAL;
		FVAL_2 <= FVAL_1;
		LVAL_1 <= CMOS_LVAL;
		LVAL_2 <= LVAL_1;
		
		if FVAL = '1' then 
			--beginning a frame
			cam_pos_y <= 0;
		elsif cam_pos_y < ((480*2)-1) then 
			cam_pos_y <= cam_pos_y + 1; 
		end if;
		
		if LVAL = '1' then 
			--beginning a line
			cam_pos_x <= 0; 
		elsif cam_pos_x < ((640*2)-1) then 
			--in a line
			cam_pos_x <= cam_pos_x + 1;
		end if;
		
	end if;
end process;

FVAL <= FVAL_1 and (not FVAL_2);
LVAL <= LVAL_1 and (not LVAL_2);
	
CAM_X <= cam_pos_x;
CAM_Y <= cam_pos_y;

end CMOS_LA_arch;
