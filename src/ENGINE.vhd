 library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

entity ENGINE is
    port (
	 -- CLOCK
    CLOCK_25  : in std_logic;
	 -- material ports
	 -- program used ports
	 SCREEN_X : out integer range 0 to 639;
	 SCREEN_Y : out integer range 0 to 479;
	 VALID_OUT : out std_logic	 
    );
end ENGINE;

architecture ENGINE_arch of ENGINE is

COMPONENT triangle_ram IS
	PORT
	(
		clock		: IN STD_LOGIC  := '1';
		data		: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
		rdaddress		: IN STD_LOGIC_VECTOR (9 DOWNTO 0);
		wraddress		: IN STD_LOGIC_VECTOR (9 DOWNTO 0);
		wren		: IN STD_LOGIC  := '0';
		q		: OUT STD_LOGIC_VECTOR (31 DOWNTO 0)
	);
END component;

signal ram_data		: STD_LOGIC_VECTOR (31 DOWNTO 0);
signal ram_rdaddress		: STD_LOGIC_VECTOR (9 DOWNTO 0);
signal ram_wraddress		: STD_LOGIC_VECTOR (9 DOWNTO 0);
signal ram_wren		: STD_LOGIC  := '0';
signal ram_q		: STD_LOGIC_VECTOR (31 DOWNTO 0);

signal current_point_address : integer range 0 to 1023 := 0;
signal point_reg_full : std_logic := '0';
type t_point_reg is array(2 downto 0) of std_logic_vector (31 downto 0); 
signal point_reg : t_point_reg;

signal result_screen_x : integer;
signal result_screen_y : integer;

begin


triangle_ram_inst : triangle_ram PORT MAP (clock => CLOCK_25, data => ram_data, rdaddress => ram_rdaddress,
wraddress => ram_wraddress, wren => ram_wren, q => ram_q);


process (CLOCK_25)
begin
	if rising_edge(CLOCK_25) then
		if current_point_address < 9*1 then --number of stored points
			current_point_address <= current_point_address + 1;
		else
			current_point_address <= 0;
		end if;
		
		if (current_point_address mod 3) = 2 then point_reg_full <= '1'; else point_reg_full <= '0'; end if;
		
		-- read corresponding data from memory
		ram_rdaddress <= std_logic_vector(to_unsigned(current_point_address,10));
		point_reg(2) <= ram_q;
		--shift data in shiftregister
		point_reg(0) <= point_reg(1);
		point_reg(1) <= point_reg(2);
		
		--processing the triangles as soon as the register is full
		if (current_point_address mod 3) = 2 then
			--projection on the plane x->reg(0) ; y->reg(1) ; z->reg(2)
			---------------------------------------------------------------TODO
			
			result_screen_x <= 640/2 + (to_integer(signed(point_reg(0)))-640/2) * (to_integer(signed(point_reg(2)))) /
		((to_integer(signed(point_reg(2)))) + 655360);
		
			result_screen_y <= 480/2 + (to_integer(signed(point_reg(1)))-480/2) * (to_integer(signed(point_reg(2)))) /
		((to_integer(signed(point_reg(2)))) + 655360);
			
			SCREEN_X <= 100;--to_integer(to_signed( result_screen_x ,32)(25 downto 16));
			SCREEN_Y <= 100;--to_integer(to_signed( result_screen_y ,32)(25 downto 16));

			
			
		end if;
		
	end if;	
	
end process;
VALID_OUT <= point_reg_full;

end ENGINE_arch;
