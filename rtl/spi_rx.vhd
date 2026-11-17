-- ======================================================================
-- spi_rx.vhd - SPI receiver (MISO shift register), SPI mode 0
-- Lab 3, variant 9 (SPI, VHDL). Kuznietsov H. D., KI-409
--
-- On every sample_en pulse (rising SCLK edge) the MISO bit is shifted in
-- from the right. After DATA_W pulses rx_data holds the received word,
-- MSB first.
-- ======================================================================
library ieee;
use ieee.std_logic_1164.all;

entity spi_rx is
  generic (
    DATA_W : positive := 8                       -- word length, bits
  );
  port (
    clk       : in  std_logic;                   -- system clock
    -- synchronous reset, active high
    rst       : in  std_logic;
    -- 1 = clear before a new transfer
    clear     : in  std_logic;
    -- 1 = sample MISO (rising SCLK)
    sample_en : in  std_logic;
    -- serial input from the slave
    miso      : in  std_logic;
    rx_data   : out std_logic_vector(DATA_W-1 downto 0)  -- received word
  );
end entity spi_rx;

architecture rtl of spi_rx is
  -- input shift register
  signal sh_reg : std_logic_vector(DATA_W-1 downto 0) := (others => '0');
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' or clear = '1' then
        sh_reg <= (others => '0');
      elsif sample_en = '1' then
        -- shift in from the LSB side
        sh_reg <= sh_reg(DATA_W-2 downto 0) & miso;
      end if;
    end if;
  end process;

  rx_data <= sh_reg;
end architecture rtl;
