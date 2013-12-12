library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity I2C_Controller is
    port(
         rst_n      : in std_logic;
         clk        : in std_logic;
         CLK_ena    : in std_logic;
         CLK_20k    : in std_logic;
         GO         : in std_logic;
         I2C_DATA   : in std_logic_vector(23 downto 0);

         ACK        : out std_logic;
         FIN        : out std_logic;
         I2C_SCLK   : out std_logic;
         I2C_SDAT   : inout std_logic
         );
end I2C_Controller;

architecture I2C_Controller_arch of I2C_Controller is

signal SDO  : std_logic;
signal DIR  : std_logic := '1';
signal SCLK : std_logic;
signal SCLK_out : std_logic;

signal SD         : std_logic_vector(23 downto 0);
signal SD_COUNTER : std_logic_vector( 5 downto 0);


signal ACK1,ACK2,ACK3 : std_logic;


begin

SCLK_out <= not CLK_20k when ((SD_COUNTER >= 4) and (SD_COUNTER <=30)) else '0';
I2C_SCLK <= SCLK or SCLK_out;

I2C_SDAT <= SDO when DIR = '1' else 'Z';

ACK <= ACK1 or ACK2 or ACK3;

-- I2C COUNTER
process(clk)
begin
    if rising_edge(clk) then
        if rst_n = '0' then
        SD_COUNTER <=  "111111";
        else
        if CLK_ena = '1' then
            if GO = '0' then
            SD_COUNTER <=  "000000";
            else
                if (SD_COUNTER < "111111") then
                SD_COUNTER <= SD_COUNTER + 1;
                end if;
            end if;
        end if;
        end if;
    end if;
end process;



process(clk, rst_n)
begin
        if rst_n = '0' then
                                SCLK <= '1';
                                SDO  <= '1';
                                ACK1 <= '1';
                                ACK2 <= '1';
                                ACK3 <= '1';
                                FIN  <= '1';
                                DIR  <= '1'; -- Write on I2C_SDAT
    elsif rising_edge(clk) then
        if CLK_ena = '1' then
        case(SD_COUNTER) is
        when "000000" =>
                                SCLK <= '1';
                                SDO  <= '1';
                                ACK1 <= '1';
                                ACK2 <= '1';
                                ACK3 <= '1';
                                FIN  <= '0';
                                DIR  <= '1'; -- Write on I2C_SDAT
-- start
        when "000001" =>        SD   <= I2C_DATA;
                                SDO  <= '0';
                                DIR  <= '1'; -- Write on I2C_SDAT

        when "000010" =>        SCLK <= '0';
                                DIR  <= '1'; -- Write on I2C_SDAT

-- Address
        when "000011" =>        SDO <= SD(23);
        when "000100" =>        SDO <= SD(22);
        when "000101" =>        SDO <= SD(21);
        when "000110" =>        SDO <= SD(20);
        when "000111" =>        SDO <= SD(19);
        when "001000" =>        SDO <= SD(18);
        when "001001" =>        SDO <= SD(17);
        when "001010" =>        SDO <= SD(16);
        when "001011" =>        SDO <= '1'; -- ACK
                                DIR <= '0'; -- Z on I2C_SDAT
--                                
-- Sub Address
        when "001100" =>		ACK1 <= I2C_SDAT;
                                SDO <= SD(15);
                                DIR  <= '1'; -- Write on I2C_SDAT
        when "001101" =>        SDO <= SD(14);
        when "001110" =>        SDO <= SD(13);
        when "001111" =>        SDO <= SD(12);
        when "010000" =>        SDO <= SD(11);
        when "010001" =>        SDO <= SD(10);
        when "010010" =>        SDO <= SD(9);
        when "010011" =>        SDO <= SD(8);
        when "010100" =>        SDO <= '1'; -- ACK
                                DIR <= '0'; -- Z on I2C_SDAT
                                
-- Data
        when "010101" =>		ACK2 <= I2C_SDAT;
                                SDO <= SD(7);
                                DIR  <= '1'; -- Write on I2C_SDAT
        when "010110" =>        SDO <= SD(6);
        when "010111" =>        SDO <= SD(5);
        when "011000" =>        SDO <= SD(4);
        when "011001" =>        SDO <= SD(3);
        when "011010" =>        SDO <= SD(2);
        when "011011" =>        SDO <= SD(1);
        when "011100" =>        SDO <= SD(0);
        when "011101" =>        SDO <= '1'; -- ACK
                                DIR <= '0'; -- Z on I2C_SDAT
                                
-- stop
        when "011110" =>		ACK3 <= I2C_SDAT;
                                SDO  <= '0';
                                SCLK <= '0';
                                DIR  <= '1'; -- Write on I2C_SDAT

        when "011111" =>        SCLK <= '1';
        when "100000" =>        SDO  <= '1';
                                FIN  <= '1';

        when others   =>
                                SCLK <= '1';
                                SDO  <= '1';
                                ACK1 <= '1';
                                ACK2 <= '1';
                                ACK3 <= '1';
                                FIN  <= '1';
        end case;
        end if;
    end if;
end process;

end I2C_Controller_arch;