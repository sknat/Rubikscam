library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity I2C_CMOS_Config is
    port (
    clk        : in std_logic;
    rst_n      : in std_logic;
    exposition : in std_logic_vector(15 downto 0);
    I2C_SCLK   : out std_logic;
    I2C_SDAT   : inout std_logic
    );
end I2C_CMOS_Config;

architecture I2C_CMOS_Config_arch of I2C_CMOS_Config is

-- LUT Data Number
-- Registers are 16 bits.
-- All are configured with 8 bits words.
-- So you need two 8 bits Words by register
constant LUT_SIZE  : integer := 24; -- size
signal   LUT_INDEX : integer range 0 to LUT_SIZE := 0;
signal   LUT_DATA  : std_logic_vector(15 downto 0);

-- Clock Setting
constant CLK_Freq : integer := 50000000; -- 50    MHz
constant I2C_Freq : integer :=  3125000; -- 3.125 MHz

signal mI2C_CLK_DIV        : integer range 0 to (CLK_Freq/I2C_Freq) := 0;
signal mI2C_DATA           : std_logic_vector(23 downto 0);
signal mI2C_CTRL_CLK       : std_logic := '0';
signal mI2C_CTRL_CLK_ena   : std_logic;
signal mI2C_CTRL_CLK_ena_d : std_logic;
signal mI2C_GO             : std_logic;
signal mI2C_END            : std_logic;
signal mI2C_ACK            : std_logic;

-- declaration of states
type STATE_TYPE is (st0_send_data,
                    st10_wait_ack,
                    st20_next_data
                    );
signal mSetup_ST : STATE_TYPE := st0_send_data;

component I2C_Controller is
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
end component;

begin

process(LUT_INDEX, exposition)
begin
    case(LUT_INDEX) is
    when 0      => LUT_DATA <= x"2000";   -- Mirror Row and Columns
    when 1      => LUT_DATA <= x"F101";   -- Add 0x20, Data 0x

    when 2      => LUT_DATA <= x"09" & exposition(15 downto 8); -- exposition
    when 3      => LUT_DATA <= x"F1" & exposition( 7 downto 0); -- Add 0x09

    when 4      => LUT_DATA <= x"2B00";   -- Green 1 Gain
    when 5      => LUT_DATA <= x"F1B0";   -- Add 0x2B, Data 0x00B0

    when 6      => LUT_DATA <= x"2C00";   -- Blue Gain
    when 7      => LUT_DATA <= x"F1CF";   -- Add 0x2C, Data 0x00CF

    when 8      => LUT_DATA <= x"2D00";   -- Red Gain
    when 9      => LUT_DATA <= x"F1CF";   -- Add 0x2D, Data 0x00CF

    when 10     => LUT_DATA <= x"2E00";   -- Green 2 Gain
    when 11     => LUT_DATA <= x"F1B0";   -- Add 0x2E, Data 0x00B0

    when 12     => LUT_DATA <= x"0101";   -- Row_Start
    when 13     => LUT_DATA <= x"F11C";   -- Add 0x01, Data 0x000C

    when 14     => LUT_DATA <= x"0201";   -- Column_Start
    when 15     => LUT_DATA <= x"F15E";   -- Add 0x02, Data 0x001E

    when 16     => LUT_DATA <= x"0301";   -- Row_Width
    when 17     => LUT_DATA <= x"F1E0";   -- Add 0x03, Data 0x0400

    when 18     => LUT_DATA <= x"0402";   -- Column_Width
    when 19     => LUT_DATA <= x"F180";   -- Add 0x04, Data 0x0500

    when 20     => LUT_DATA <= x"0500";   -- H_Blanking
    when 21     => LUT_DATA <= x"F188";   -- Add 0x05, Data 0x0088

    when 22     => LUT_DATA <= x"0600";   -- V_Blanking
    when 23     => LUT_DATA <= x"F119";   -- Add 0x06, Data 0x0019

    when 24     => LUT_DATA <= x"0000";
    when others => LUT_DATA <= x"0000";
    end case;
end process;

-- I2C Control Clock
process(clk)
begin
    if rising_edge(clk) then
        if rst_n = '0' then
        mI2C_CLK_DIV    <=  0;
        else
            if ( mI2C_CLK_DIV < (CLK_Freq/I2C_Freq) ) then
            mI2C_CLK_DIV    <=  mI2C_CLK_DIV + 1;
            else
            mI2C_CLK_DIV    <=  0;
            end if;
        end if;
    end if;
end process;

mI2C_CTRL_CLK       <= '0' when ( mI2C_CLK_DIV < (CLK_Freq/I2C_Freq)/2 ) else '1';
mI2C_CTRL_CLK_ena   <= '1' when ( mI2C_CLK_DIV = (CLK_Freq/I2C_Freq)/2) else '0';

I2C_Controller_inst : I2C_Controller
port map(
         rst_n      => rst_n,
         clk        => clk,
         CLK_ena    => mI2C_CTRL_CLK_ena,
         CLK_20k    => mI2C_CTRL_CLK,
         GO         => mI2C_GO,
         I2C_DATA   => mI2C_DATA,

         ACK        => mI2C_ACK,
         FIN        => mI2C_END,
         I2C_SCLK   => I2C_SCLK,
         I2C_SDAT   => I2C_SDAT
         );

--////////////////////////////////////////////////////////////////////
--//////////////////////  Config Control  ////////////////////////////

process(clk)
begin
    if rising_edge(clk) then
        if rst_n = '0' then
        LUT_INDEX   <=  0;
        mSetup_ST   <=  st0_send_data;
        mI2C_GO     <=  '0';
        else
        if mI2C_CTRL_CLK_ena = '1' then
            if (LUT_INDEX < LUT_SIZE) then
            case (mSetup_ST)is
            when st0_send_data =>
                                 mI2C_DATA  <=  x"BA" & std_logic_vector(LUT_DATA);
                                 mI2C_GO    <=  '1';
                                 mSetup_ST  <=  st10_wait_ack;

            when st10_wait_ack =>
                    if mI2C_END = '1' then
                        if mI2C_ACK = '0' then
                                mSetup_ST   <=  st20_next_data;
                        else
                            mSetup_ST   <=  st0_send_data;
                            mI2C_GO     <=  '0';
                        end if;
                    end if;

            when st20_next_data =>
                                LUT_INDEX   <=  LUT_INDEX + 1;
                                mSetup_ST   <=  st0_send_data;

            when others =>      mSetup_ST   <= st0_send_data;
            end case;
            end if;
        end if;
        end if;
    end if;
end process;

end I2C_CMOS_Config_arch;