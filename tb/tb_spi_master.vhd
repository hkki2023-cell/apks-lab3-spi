-- ======================================================================
-- tb_spi_master.vhd - self-checking testbench for spi_master (SPI mode 0)
-- Lab 3, variant 9 (SPI, VHDL). Kuznietsov H. D., KI-409
--
--  * clock 50 MHz and synchronous reset;
--  * a behavioural SPI slave model (mode 0) answers every transfer with its
--    own byte on MISO and captures what the master sends on MOSI;
--  * every transfer checks both directions:
--      master rx_data = byte sent by the slave   (receiver check)
--      slave captured = byte sent by the master  (transmitter check)
-- Requires VHDL-2008 (std.env.finish, to_hstring).
-- ======================================================================
library ieee;
use ieee.std_logic_1164.all;

entity tb_spi_master is
end entity tb_spi_master;

architecture sim of tb_spi_master is
  constant CLK_PERIOD : time     := 20 ns;       -- 50 MHz system clock
  -- SCLK = 50 MHz / (2*4) = 6.25 MHz
  constant CLK_DIV    : positive := 4;
  constant DATA_W     : positive := 8;

  type byte_arr is array (natural range <>) of std_logic_vector(7 downto 0);
  -- test vectors: what the master sends and what the slave answers
  constant M_TX : byte_arr := (x"A5", x"3C", x"FF", x"00", x"81");
  constant S_TX : byte_arr := (x"5A", x"C3", x"00", x"FF", x"7E");

  signal clk     : std_logic := '0';
  signal rst     : std_logic := '1';
  signal start   : std_logic := '0';
  signal tx_data : std_logic_vector(7 downto 0) := (others => '0');
  signal rx_data : std_logic_vector(7 downto 0);
  signal busy    : std_logic;
  signal done    : std_logic;
  signal sclk    : std_logic;
  signal mosi    : std_logic;
  signal miso    : std_logic := 'Z';
  signal ss_n    : std_logic;

  -- receiver errors (checked by the stimulus process)
  signal err_master : natural := 0;
  -- transmitter errors (checked by the slave model)
  signal err_slave  : natural := 0;
  -- last byte captured by the slave
  signal slave_rx   : std_logic_vector(7 downto 0) := (others => '0');
begin
  -- ---------------- device under test ----------------
  dut : entity work.spi_master
    generic map (CLK_DIV => CLK_DIV, DATA_W => DATA_W)
    port map (clk => clk, rst => rst, start => start, tx_data => tx_data,
              rx_data => rx_data, busy => busy, done => done,
              sclk => sclk, mosi => mosi, miso => miso, ss_n => ss_n);

  -- ---------------- clock ----------------
  clk <= not clk after CLK_PERIOD / 2;

  -- ---------------- SPI slave model, mode 0 ----------------
  slave : process
    -- slave output shift register
    variable sh  : std_logic_vector(7 downto 0);
    -- slave input shift register
    variable cap : std_logic_vector(7 downto 0);
  begin
    for i in S_TX'range loop
      wait until ss_n = '0';                       -- transfer begins
      sh   := S_TX(i);
      cap  := (others => '0');
      -- first bit before the first SCLK edge
      miso <= sh(7);
      loop
        wait until rising_edge(sclk) or ss_n = '1';
        exit when ss_n = '1';
        -- sample MOSI on the rising edge
        cap := cap(6 downto 0) & mosi;
        wait until falling_edge(sclk) or ss_n = '1';
        exit when ss_n = '1';
        sh   := sh(6 downto 0) & '0';
        -- next bit on the falling edge
        miso <= sh(7);
      end loop;
      -- release MISO when deselected
      miso     <= 'Z';
      slave_rx <= cap;
      if cap /= M_TX(i) then
        report "TX ERROR #" & integer'image(i) &
               ": slave got 0x" & to_hstring(cap) &
               ", expected 0x" & to_hstring(M_TX(i)) severity error;
        err_slave <= err_slave + 1;
      else
        report "TX OK    #" & integer'image(i) &
               ": slave got 0x" & to_hstring(cap);
      end if;
    end loop;
    wait;
  end process;

  -- ---------------- stimulus and receiver check ----------------
  stim : process
  begin
    rst <= '1';
    wait for 5 * CLK_PERIOD;
    wait until rising_edge(clk);
    rst <= '0';
    wait for 4 * CLK_PERIOD;

    for i in M_TX'range loop
      wait until rising_edge(clk);
      tx_data <= M_TX(i);
      start   <= '1';                              -- one-cycle start pulse
      wait until rising_edge(clk);
      start   <= '0';
      wait until rising_edge(clk) and done = '1';  -- end of transfer
      if rx_data /= S_TX(i) then
        report "RX ERROR #" & integer'image(i) &
               ": master got 0x" & to_hstring(rx_data) &
               ", expected 0x" & to_hstring(S_TX(i)) severity error;
        err_master <= err_master + 1;
      else
        report "RX OK    #" & integer'image(i) &
               ": master got 0x" & to_hstring(rx_data);
      end if;
      wait for 6 * CLK_PERIOD;                     -- pause between transfers
    end loop;

    wait for 10 * CLK_PERIOD;
    if err_master + err_slave = 0 then
      report "TEST PASSED: " & integer'image(M_TX'length) &
             " transfers, 0 errors";
    else
      report "TEST FAILED: " & integer'image(err_master + err_slave) &
             " errors" severity error;
    end if;
    std.env.finish;
  end process;
end architecture sim;
