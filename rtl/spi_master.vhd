-- ======================================================================
-- spi_master.vhd - SPI Master controller, SPI mode 0 (CPOL = 0, CPHA = 0)
-- Lab 3, variant 9 (SPI, VHDL). Kuznietsov H. D., KI-409
--
-- Generates SCLK from the system clock (f_sclk = f_clk / (2 * CLK_DIV)),
-- drives SS_N and controls the transmitter (spi_tx) and receiver (spi_rx).
--   * MOSI changes on the falling SCLK edge (first bit before the first
--     edge);
--   * MISO is sampled on the rising SCLK edge;
--   * one transfer = DATA_W bits, full duplex.
--
-- FSM: IDLE --start--> START --(half period)--> TRANSFER
--      TRANSFER --(DATA_W bits)--> STOP --> IDLE
-- ======================================================================
library ieee;
use ieee.std_logic_1164.all;

entity spi_master is
  generic (
    -- system clocks per SCLK half period
    CLK_DIV : positive := 4;
    DATA_W  : positive := 8                      -- word length, bits
  );
  port (
    clk     : in  std_logic;                     -- system clock
    -- synchronous reset, active high
    rst     : in  std_logic;
    -- 1-cycle pulse: begin a transfer (ignored when busy)
    start   : in  std_logic;
    -- word to send to the slave
    tx_data : in  std_logic_vector(DATA_W-1 downto 0);
    -- word received from the slave (valid with done)
    rx_data : out std_logic_vector(DATA_W-1 downto 0);
    -- 1 while a transfer is in progress
    busy    : out std_logic;
    -- 1-cycle pulse at the end of a transfer
    done    : out std_logic;
    -- SPI bus
    -- serial clock, idle low (CPOL = 0)
    sclk    : out std_logic;
    mosi    : out std_logic;                     -- master out, slave in
    miso    : in  std_logic;                     -- master in, slave out
    ss_n    : out std_logic                      -- slave select, active low
  );
end entity spi_master;

architecture rtl of spi_master is
  type state_t is (S_IDLE, S_START, S_TRANSFER, S_STOP);
  signal state     : state_t := S_IDLE;           -- current FSM state

  -- SCLK half-period divider
  signal div_cnt   : integer range 0 to CLK_DIV-1 := 0;
  -- bits sampled in this transfer
  signal bit_cnt   : integer range 0 to DATA_W := 0;
  signal sclk_r    : std_logic := '0';            -- registered SCLK
  signal ss_r      : std_logic := '1';            -- registered SS_N
  signal done_r    : std_logic := '0';            -- registered DONE pulse
  -- latched result
  signal rx_data_r : std_logic_vector(DATA_W-1 downto 0) := (others => '0');

  -- end of an SCLK half period
  signal tick      : std_logic;
  -- load transmitter / clear receiver
  signal load_tx   : std_logic;
  -- SCLK goes 0 -> 1 on this clock: sample MISO
  signal rise_en   : std_logic;
  -- SCLK goes 1 -> 0 on this clock: shift MOSI
  signal fall_en   : std_logic;
  -- receiver output
  signal rx_word   : std_logic_vector(DATA_W-1 downto 0);
begin
  -- ---------------- control strobes (combinational) ----------------
  tick    <= '1' when div_cnt = CLK_DIV-1 else '0';
  load_tx <= '1' when state = S_IDLE and start = '1' else '0';
  rise_en <= '1' when state = S_TRANSFER and tick = '1' and sclk_r = '0'
             else '0';
  -- no shift after the last bit: the transfer ends on that falling edge
  fall_en <= '1' when state = S_TRANSFER and tick = '1' and sclk_r = '1'
                      and bit_cnt /= DATA_W
             else '0';

  -- ---------------- FSM, divider and bit counter ----------------
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state     <= S_IDLE;
        div_cnt   <= 0;
        bit_cnt   <= 0;
        sclk_r    <= '0';
        ss_r      <= '1';
        done_r    <= '0';
        rx_data_r <= (others => '0');
      else
        -- DONE is a single-cycle pulse
        done_r <= '0';
        case state is
          -- bus idle: SS_N high, SCLK low
          when S_IDLE =>
            sclk_r  <= '0';
            ss_r    <= '1';
            div_cnt <= 0;
            bit_cnt <= 0;
            if start = '1' then
              -- select the slave, first bit is on MOSI
              ss_r  <= '0';
              state <= S_START;
            end if;

          -- half period of setup time before the first edge
          when S_START =>
            if tick = '1' then
              div_cnt <= 0;
              state   <= S_TRANSFER;
            else
              div_cnt <= div_cnt + 1;
            end if;

          -- toggle SCLK every half period
          when S_TRANSFER =>
            if tick = '1' then
              div_cnt <= 0;
              -- rising edge: receiver samples MISO
              if sclk_r = '0' then
                sclk_r  <= '1';
                bit_cnt <= bit_cnt + 1;
              -- falling edge: transmitter shifts MOSI
              else
                sclk_r <= '0';
                if bit_cnt = DATA_W then
                  state <= S_STOP;                -- all bits done
                end if;
              end if;
            else
              div_cnt <= div_cnt + 1;
            end if;

          -- hold time, then release the slave
          when S_STOP =>
            if tick = '1' then
              div_cnt   <= 0;
              ss_r      <= '1';
              -- result is valid together with DONE
              rx_data_r <= rx_word;
              done_r    <= '1';
              state     <= S_IDLE;
            else
              div_cnt <= div_cnt + 1;
            end if;
        end case;
      end if;
    end if;
  end process;

  -- ---------------- transmitter and receiver ----------------
  u_tx : entity work.spi_tx
    generic map (DATA_W => DATA_W)
    port map (clk => clk, rst => rst, load => load_tx, shift_en => fall_en,
              tx_data => tx_data, mosi => mosi);

  u_rx : entity work.spi_rx
    generic map (DATA_W => DATA_W)
    port map (clk => clk, rst => rst, clear => load_tx, sample_en => rise_en,
              miso => miso, rx_data => rx_word);

  -- ---------------- outputs ----------------
  sclk    <= sclk_r;
  ss_n    <= ss_r;
  done    <= done_r;
  busy    <= '0' when state = S_IDLE else '1';
  rx_data <= rx_data_r;
end architecture rtl;
