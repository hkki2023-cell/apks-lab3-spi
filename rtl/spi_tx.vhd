-- ======================================================================
-- spi_tx.vhd - SPI transmitter (MOSI shift register), SPI mode 0
-- Lab 3, variant 9 (SPI, VHDL). Kuznietsov H. D., KI-409
--
-- The register is loaded with the byte to send; its MSB drives MOSI at once,
-- so the first bit is valid before the first rising SCLK edge (CPHA = 0).
-- On every shift_en pulse (falling SCLK edge) the next bit appears on MOSI.
-- ======================================================================
library ieee;
use ieee.std_logic_1164.all;

entity spi_tx is
  generic (
    DATA_W : positive := 8                       -- word length, bits
  );
  port (
    clk      : in  std_logic;                    -- system clock
    -- synchronous reset, active high
    rst      : in  std_logic;
    -- 1 = load tx_data into the shift register
    load     : in  std_logic;
    -- 1 = shift left by one bit (falling SCLK)
    shift_en : in  std_logic;
    -- parallel data to send
    tx_data  : in  std_logic_vector(DATA_W-1 downto 0);
    mosi     : out std_logic                     -- serial output, MSB first
  );
end entity spi_tx;

architecture rtl of spi_tx is
  -- output shift register
  signal sh_reg : std_logic_vector(DATA_W-1 downto 0) := (others => '0');
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        sh_reg <= (others => '0');
      elsif load = '1' then
        -- new word, MSB goes out first
        sh_reg <= tx_data;
      elsif shift_en = '1' then
        -- next bit to MSB position
        sh_reg <= sh_reg(DATA_W-2 downto 0) & '0';
      end if;
    end if;
  end process;

  -- MOSI is always the current MSB
  mosi <= sh_reg(DATA_W-1);
end architecture rtl;
