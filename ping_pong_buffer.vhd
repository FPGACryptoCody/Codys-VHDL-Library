-- Title: Ping Pong Buffer
-- Created by: Cody Emerson
-- Date: 9/11/2021
-- Target: Xilinx Ultrascale
--|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
-- Description: Ping-Pong Buffer.
--|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

library work;
use work.helper_functions.all;

entity ping_pong_buffer is
    generic(
        G_RAM_DEPTH     : natural := 512;
        G_RAM_WIDTH     : natural := 32;
        G_NUM_OUT_PIPES : natural:= 1;     -- Number of pipelines on outputs
        G_USE_RST       : std_logic:='0';  -- '1' enable SRST port, '0' disable SRST port
        G_IS_SYNC_RST   : std_logic:='1'   -- '1' use synchronous reset, '0' use asynchronous reset
    );
    port(
        CLK             : in  std_logic;
        RST             : in  std_logic;

        WR_OK           : out std_logic;
        WR_ENABLE       : in  std_logic;
        WR_ADDR         : in  std_logic_vector(ceil_log2(G_RAM_DEPTH) - 1 downto 0);
        WR_DATA         : in  std_logic_vector(G_RAM_WIDTH - 1 downto 0);
        WR_DONE         : in  std_logic;

        RD_OK           : out std_logic;
        RD_ADDR         : in  std_logic_vector(ceil_log2(G_RAM_DEPTH) - 1 downto 0);
        RD_DATA         : out std_logic_vector(G_RAM_WIDTH - 1 downto 0);
        RD_DONE         : in  std_logic
    );
end ping_pong_buffer;

architecture behavioral of ping_pong_buffer is

-- Components
   component pipe is
   generic(
      G_RANK        : integer:=1;         -- Number of pipeline stages 
      G_IS_DELAY    : string:="FALSE";    -- "TRUE" use this block as a pipeline, "FALSE" use this block as a delay
      G_USE_RST     : std_logic:='0';     -- '1' synthesize resets, '0' do not synthesize resets
      G_IS_SYNC_RST : std_logic:='1'      -- '1' use synchronous reset, '0' use asychronous reset
   );
   port (
      CLK        : in  std_logic;         -- System Clock
      RST        : in  std_logic;         -- Reset, Can be async or sync        
      D          : in  std_logic_vector;  -- Input Data
      Q          : out std_logic_vector   -- Output Data
   );
   end component pipe;

   component dualport_ram is
   generic (
       G_RAM_WIDTH       : positive := 18;           -- RAM width
       G_RAM_DEPTH       : positive := 1024;         -- RAM depth 
       G_TYPE            : string := "LOW_LATENCY";  -- "HIGH_PERFORMANCE" or "LOW_LATENCY"
       G_COEF_FILE       : string := ""              --  Path of RAM initialization file 
   );
   port (
       ADDRA             : in std_logic_vector((ceil_log2(G_RAM_DEPTH)-1) downto 0);  
       ADDRB             : in std_logic_vector((ceil_log2(G_RAM_DEPTH)-1) downto 0);  
       DINA              : in std_logic_vector(G_RAM_WIDTH-1 downto 0);              
       DINB              : in std_logic_vector(G_RAM_WIDTH-1 downto 0);              
       CLKA              : in std_logic;                                             
       CLKB              : in std_logic;                                             
       WEA               : in std_logic;                                             
       WEB               : in std_logic;                                             
       ENA               : in std_logic;                                             
       ENB               : in std_logic;                                             
       RSTA              : in std_logic;                                             
       RSTB              : in std_logic;                                             
       REGCEA            : in std_logic;                                              
       REGCEB            : in std_logic;                                              
       DOUTA             : out std_logic_vector(G_RAM_WIDTH-1 downto 0);              
       DOUTB             : out std_logic_vector(G_RAM_WIDTH-1 downto 0)               
   ); 
   end component dualport_ram;
-- Signals
   signal wr_indi         : std_logic;
   signal wr_buf_full     : std_logic;
   signal rd_indi         : std_logic;
   signal rd_buf_full     : std_logic;
   signal dout_int        : std_logic_vector(G_RAM_WIDTH - 1 downto 0);

begin

   WR_OK  <= not(wr_buf_full) when wr_indi = '0' else not(rd_buf_full);
   RD_OK  <= wr_buf_full when rd_indi = '0' else rd_buf_full;

   p_Buffer_Controls: process(CLK) is
   begin
      if(G_USE_RST = '1' and G_IS_SYNC_RST = '0' and RST = '1') then
          wr_indi <= '0';
          rd_indi <= '0';
          wr_buf_full <= '0';
          rd_buf_full <= '0';
      elsif(rising_edge(CLK)) then
         if(G_USE_RST = '1' and G_IS_SYNC_RST = '1' and RST = '1') then
            wr_indi <= '0';
            rd_indi <= '0';
            wr_buf_full <= '0';
            rd_buf_full <= '0';
         else
            if (wr_indi = '0' and WR_DONE = '1') then
               wr_buf_full <= '1';
            elsif (rd_indi = '0' and RD_DONE = '1') then
               wr_buf_full <= '0';
            end if;

            if (wr_indi = '1' and WR_DONE = '1') then
               rd_buf_full <= '1';
            elsif (rd_indi = '1' and RD_DONE = '1') then
               rd_buf_full <= '0';
            end if;

            if (WR_DONE = '1') then
               wr_indi <= not wr_indi;
            end if;

            if (RD_DONE = '1') then
               rd_indi <= not rd_indi;
            end if;
         end if;
      end if;
   end process p_Buffer_Controls;

----------------------------------------------
-- RAM
---------------------------------------------- 
    comp_RAM: dualport_ram
    generic map (
       G_RAM_WIDTH      => G_RAM_WIDTH,          -- : positive := 18;           
       G_RAM_DEPTH      => G_RAM_DEPTH*2,        -- : positive := 1024;          
       G_TYPE           => "LOW_LATENCY",        -- : string := "LOW_LATENCY";   
       G_COEF_FILE      => ""                    -- : string := ""               
    )
    port map(
        ADDRA           => wr_indi & WR_ADDR,    -- : in std_logic_vector((ceil_log2(G_RAM_DEPTH)-1) downto 0);  
        ADDRB           => rd_indi & RD_ADDR,    -- : in std_logic_vector((ceil_log2(G_RAM_DEPTH)-1) downto 0);  
        DINA            => WR_DATA,              -- : in std_logic_vector(G_RAM_WIDTH-1 downto 0);              
        DINB            => (others=>'0'),        -- : in std_logic_vector(G_RAM_WIDTH-1 downto 0);              
        CLKA            => CLK,                  -- : in std_logic;                                             
        CLKB            => CLK,                  -- : in std_logic;                                             
        WEA             => WR_ENABLE,            -- : in std_logic;                                             
        WEB             => '0',                  -- : in std_logic;                                             
        ENA             => '1',                  -- : in std_logic;                                             
        ENB             => '1',                  -- : in std_logic;                                             
        RSTA            => RST,                  -- : in std_logic;                                             
        RSTB            => RST,                  -- : in std_logic;                                             
        REGCEA          => '1',                  -- : in std_logic;                                              
        REGCEB          => '1',                  -- : in std_logic;                                              
        DOUTA           => open,                 -- : out std_logic_vector(G_RAM_WIDTH-1 downto 0);              
        DOUTB           => dout_int              -- : out std_logic_vector(G_RAM_WIDTH-1 downto 0)               
    ); -- dualport_ram;

----------------------------------------------
-- Output Pipelines
----------------------------------------------  
    pipe_DOUT: pipe generic map(G_RANK => G_NUM_OUT_PIPES, G_USE_RST => G_USE_RST, G_IS_SYNC_RST => G_IS_SYNC_RST) 
    port map(CLK => CLK,RST => RST,D => dout_int, Q => RD_DATA);   

end behavioral;