   library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

entity Pong is
    port (
	 -- CLOCK
    CLOCK_25  : in std_logic;
	 -- material ports
	 KEY    : in std_logic_vector( 3 downto 0);
	 LEDR	  : out std_logic_vector(17 downto 0);
	 LEDG	  : out std_logic_vector(8 downto 0);
	 -- program used ports
	 SCREEN_X : in integer range 0 to 639;
	 SCREEN_Y : in integer range 0 to 479;
	 VALID_IN : in std_logic;
	 R : out std_logic_vector(9 downto 0);
	 G : out std_logic_vector(9 downto 0);
	 B : out std_logic_vector(9 downto 0)
    );
end Pong;

architecture Pong_arch of Pong is

constant mx_x : natural := 640;
constant mx_y : natural := 480;
constant wd : natural := 10;
constant ball_r : natural := 4;
signal p_down_x : integer range 0 to 639;
signal p_down_sz : integer range 0 to 639;
signal p_up_x : integer range 0 to 639;
signal p_up_sz : integer range 0 to 639;
signal ball_x : integer range 0 to 639;
signal ball_y : integer range 0 to 479;
signal ball_vx : integer range -10 to 10;
signal ball_vy : integer range -10 to 10;

constant mx_lv : natural := 5;
signal p_up_lives : integer range 0 to mx_lv;
signal p_down_lives : integer range 0 to mx_lv;

constant mx_jmp : natural := 100000;
constant min_jmp : natural := 1000;
signal cr_mx_jmp : integer range min_jmp to mx_jmp;
signal jmp : integer range min_jmp to mx_jmp;

begin

LEDR(0) <= '1' when (p_up_lives > 0) else '0';
LEDR(1) <= '1' when (p_up_lives > 1) else '0';
LEDR(2) <= '1' when (p_up_lives > 2) else '0';
LEDR(3) <= '1' when (p_up_lives > 3) else '0';
LEDR(4) <= '1' when (p_up_lives > 4) else '0';

LEDG(0) <= '1' when (p_down_lives > 0) else '0';
LEDG(1) <= '1' when (p_down_lives > 1) else '0';
LEDG(2) <= '1' when (p_down_lives > 2) else '0';
LEDG(3) <= '1' when (p_down_lives > 3) else '0';
LEDG(4) <= '1' when (p_down_lives > 4) else '0';



process (CLOCK_25)
begin
	if rising_edge(CLOCK_25) then
		if KEY(0) = '0' then 
				ball_vx <= (jmp mod 20) - 10; 
				ball_vy <= ((jmp mod 40) - 20)/2; 
				p_down_lives <= mx_lv;
				p_up_lives <= mx_lv;
		end if;		
	
		if p_up_lives = 0 then p_down_lives <= mx_lv; end if;
		if p_down_lives = 0 then p_up_lives <= mx_lv; end if;
		if p_up_lives = 0 or p_down_lives = 0 then 
				ball_x <= mx_x / 2 - ball_r / 2;
				ball_y <= mx_y / 2 - ball_r / 2;
				ball_vx <= 0;
				ball_vy <= 0;
		end if;		
				
		if jmp < cr_mx_jmp then jmp <= jmp+1; else jmp <= min_jmp; end if;
		
		if jmp = min_jmp then
			if ball_y < wd then 
				--up looses
				p_up_lives <= p_up_lives - 1;
				ball_x <= p_up_x + p_up_sz / 2;
				ball_y <= 2 * wd; 
				ball_vx <= (jmp mod 20) - 10; 
				ball_vy <= (jmp mod 10);
			elsif ball_y > mx_y - wd then
				--down looses
				p_down_lives <= p_down_lives - 1;
				ball_x <= p_down_x + p_down_sz / 2;
				ball_y <= mx_y - 2 * wd;
				ball_vx <= (jmp mod 20) - 10; 
				ball_vy <= (-1) * (jmp mod 10);
			else
				-- wall collision
				if ball_x + ball_vx < wd then ball_vx <= (-1) * ball_vx; end if;
				if ball_x + ball_vx > mx_x - wd then ball_vx <= (-1) * ball_vx; end if;
				-- up paddle collision
				if ball_y + ball_vy < wd  and ball_x + ball_vx >= p_up_x and ball_x + ball_vx < p_up_x + p_up_sz then ball_vy <= (-1) * ball_vy; end if;
				-- down paddle collision
				if ball_y + ball_vy > mx_y - wd and ball_x + ball_vx >= p_down_x and ball_x + ball_vx < p_down_x + p_down_sz then ball_vy <= (-1) * ball_vy; end if;
				
				ball_x <= ball_x + ball_vx;
				ball_y <= ball_y + ball_vy;
			end if;			
		end if;
		
		if VALID_IN = '1' then
			if SCREEN_X < wd or SCREEN_X > mx_x - wd then 
				R <= "1111111111"; 
				G <= "1111111111"; 
				B <= "1111111111"; 
			end if;--left and right walls 
			if SCREEN_X >= p_down_x and SCREEN_X < p_down_x + p_down_sz and SCREEN_Y > mx_y - wd and SCREEN_Y <= mx_y then 
				R <= "1111111111"; 
				G <= "1111111111"; 
				B <= "1111111111"; 
			end if;--down paddle 
			if SCREEN_X >= p_up_x and SCREEN_X < p_up_x + p_up_sz and SCREEN_Y < wd and SCREEN_Y >= 0 then 
				R <= "1111111111"; 
				G <= "1111111111"; 
				B <= "1111111111"; 
			end if;--up paddle
			if SCREEN_X >= ball_x and SCREEN_X < ball_x + ball_r and SCREEN_Y >= ball_y and SCREEN_Y < ball_y + ball_r then 
				R <= "1111111111"; 
				G <= "1111111111"; 
				B <= "1111111111";  
			end if;--ball sprite			
		end if;	
		
		
	end if;
end process;

end Pong_arch;
