library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

entity MOTION_SENSING is
	port (
	CLOCK_25  : in std_logic;
	CLOCK_50  : in std_logic;
	KEY       : in std_logic_vector(3 downto 0);
	CMOS_DATA : in std_logic_vector(9 downto 0);
	CAM_X 	 : in integer range 0 to ((640*2)-1);
	CAM_Y 	 : in integer range 0 to ((480*2)-1);
    CMD      : out std_logic_vector (5 downto 0)
	);
end MOTION_SENSING;

architecture MOTION_SENSING_arch of MOTION_SENSING is

subtype bit_on is integer range 0 to 320*320-1;
type somme_array is array(integer range 0 to 4, integer range 0 to 6) of bit_on;
signal somme : somme_array;
signal somme_traitement : somme_array;
signal main_s : integer range 0 to 320*320-1:=0;
signal flag : std_logic := '0';
signal x : integer range 0 to 7:=0;
signal main_gx : integer range 0 to 7:=0;
signal main_gx_prev : integer range 0 to 7:=0;
signal main_dx : integer range 0 to 7:=0;
signal main_dx_prev : integer range 0 to 7:=0;
signal y : integer range 0 to 5:=0;
signal main_gy : integer range 0 to 5:=0;
signal main_gy_prev : integer range 0 to 5:=0;
signal main_dy : integer range 0 to 5 :=0;
signal main_dy_prev : integer range 0 to 5:=0;
signal dplct_dx : integer range 0 to 100:=0;
signal dplct_dy : integer range 0 to 100:=0;
signal dplct_gx : integer range 0 to 100:=0;
signal dplct_gy : integer range 0 to 100:=0;
constant seuil : std_logic_vector(9 downto 0) := "0001000000";

-- boucle de traitement des données cam en temps réel
begin

process (CLOCK_25)
begin
	if rising_edge(CLOCK_25) then
		if KEY(0)='0' then
		
			if to_integer(unsigned(CMOS_DATA)) > to_integer(unsigned(seuil)) then
				
					if CAM_X/160 > 0 and CAM_Y/160 > 0 then
						somme(CAM_X/160-1, CAM_Y/160-1) <= somme(CAM_X/160-1, CAM_Y/160-1) + 1;
					end if;
					if CAM_X/160 < 7 and CAM_Y/160 > 0 then
						somme(CAM_X/160, CAM_Y/160-1) <= somme(CAM_X/160, CAM_Y/160-1) + 1;
					end if;
					if CAM_X/160 > 0 and CAM_Y/160 < 5 then
						somme(CAM_X/160-1, CAM_Y/160) <= somme(CAM_X/160-1, CAM_Y/160) + 1;
					end if;
					if CAM_X/160 < 7 and CAM_Y/160 < 5 then
						somme(CAM_X/160, CAM_Y/160) <= somme(CAM_X/160, CAM_Y/160) + 1;
					end if;

			end if;
			
			if CAM_X = 640*2-1 and CAM_Y = 480*2-1 then
				somme_traitement <= somme;
				somme <= ((others=>(others=>0)));
			end if;
			
			-- traitement du tableau
			
			-- main gauche
			
			if flag = '0' then
				if y < 5 then
					if x < 7 then
						if somme_traitement(x, y) > main_s then
							main_gx <= x;
							main_gy <= y;
							main_s <= somme_traitement(x, y);
						end if;
						x <= x+1;
					else 
						y <= y+1;
						x <= 0;
					end if;
				else
					main_s <= 0;
					x <= 0;
					y <= 0;
					flag <= '1';
				end if;


			-- trouve la main droite


			elsif flag = '1' then
				if y < 5 then
					if x < 7 then
						if not (x > main_gx - 2 and x < main_gx + 2 and y > main_gy - 2 and y < main_gy + 2) then
							if somme_traitement(x, y) > main_s then
								main_dx <= x;
								main_dy <= y;
								main_s <= somme_traitement(x, y);
							end if;
						end if;
						x <= x+1;
					else 
						y <= y+1;
						x <=0;
					end if;
				else
					main_s <= 0;
					x <= 0;
					y <= 0;				
					flag <= '0';
				end if;
				
				-- inversion des mains pour être sûr que la gauche est à gauche (resp. droite)
				if main_gx > main_dx then
					main_gx <= main_dx;
					main_gy <= main_dy;
					main_dx <= main_gx;
					main_dy <= main_gy;
				end if;
				-- incrémentation du déplacement
				dplct_gx <= dplct_gx + main_gx - main_gx_prev;
				dplct_gy <= dplct_gy + main_gy - main_gy_prev;
				dplct_dx <= dplct_dx + main_dx - main_dx_prev;
				dplct_dy <= dplct_dy + main_dy - main_dy_prev;
				main_gx_prev <= main_gx;
				main_gy_prev <= main_gy;
				main_dx_prev <= main_dx;
				main_dy_prev <= main_dy;

			end if;
		end if;
		
	end if;
end process;

-- envoi du dplct vers la commande et remise à zéro des param

process (CLOCK_50)
begin
	if rising_edge(CLOCK_50) then
		CMD(2 downto 0) <= std_logic_vector(to_unsigned(main_gx,3)); 
		CMD(5 downto 3) <= std_logic_vector(to_unsigned(main_dx,3));
	end if;
	
end process;
	
end MOTION_SENSING_arch;
