--|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
-- Title: 2-input adder
-- Created by: Cody Emerson
-- Date: 6/15/2021
-- Target: Xilinx Ultrascale
--|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
-- Description: Add 2 binary numbers of arbitrary length. Configure
--  the G_IS_SIGNED generic to select signed or unsigned inputs.
--    
--|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; -- For unsigned & signed

entity adder_2input is
generic(
   -- Pipes
      G_NUM_IN_PIPES    : natural:=1;     -- Number of input pipelines
      G_NUM_OUT_PIPES   : natural:=1;     -- Number of output pipelines
      G_USE_RST         : std_logic:='0'; -- '1' use reset logic, '0' remove reset logic
      G_IS_SYNC_RST     : std_logic:='1'; -- '1' use synchronous reset, '0' use asynchronous reset
      -- Parameters
      G_IS_SIGNED       : std_logic:='0'; -- '1' inputs/outputs are signed binary, '0' inputs/outputs are unsigned binary
      G_IS_SUBTRATCTION : std_logic:='0'  -- '1' Add, '0' subtract
   );
port ( 
      CLK   : in std_logic;                     -- System Clock
      RST   : in std_logic;                     -- Synchronous Reset

      DINA  : in std_logic_vector;              -- First Data Input
      DINB  : in std_logic_vector;              -- Second Data Input

      DOUT  : out std_logic_vector              -- Data Output
    );
end adder_2input;

architecture behavioral of adder_2input is

-- Components
   component pipe is
   generic(
      G_RANK        : integer:=1;         -- Number of pipeline stages 
      G_IS_DELAY    : string:="FALSE";    -- "TRUE" use this block as a pipeline, "FALSE" use this block as a delay
      G_USE_RST     : std_logic:='0';     -- '1' synthesize resets, '0' do not synthesize resets
      G_IS_SYNC_RST : std_logic:='1'      -- '1' use synchronous reset, '0' use asynchronous reset
   );
   port (
      CLK        : in  std_logic;         -- System Clock
      RST        : in  std_logic;         -- Reset, Can be async or sync        
      D          : in  std_logic_vector;  -- Input Data
      Q          : out std_logic_vector   -- Output Data
   );
   end component pipe;
-- Functions
   function add_length return natural is
      begin
         if (DINA'length > DINB'length) then
            return natural(DINA'length);
         else
            return natural(DINB'length);
         end if;
   end function add_length;

-- Signals 
   signal dina_int : std_logic_vector(DINA'range);
   signal dinb_int : std_logic_vector(DINB'range);
   signal dout_int : std_logic_vector(add_length downto 0); -- 1-bit growth

begin
    
----------------------------------------------
-- Input Pipelines
-- Desc: Optional Input Pipelining
----------------------------------------------  
   pipe_DINA : pipe generic map(G_RANK => G_NUM_IN_PIPES, G_USE_RST => G_USE_RST, G_IS_SYNC_RST => G_IS_SYNC_RST) 
   port map(CLK => CLK,RST => RST, D => DINA, Q => dina_int);

   pipe_DINB : pipe generic map(G_RANK => G_NUM_IN_PIPES, G_USE_RST => G_USE_RST, G_IS_SYNC_RST => G_IS_SYNC_RST) 
   port map(CLK => CLK,RST => RST, D => DINB, Q => dinb_int);
----------------------------------------------
-- Addition/Subtraction Operation
-- Signed and Unsigned addition operators
----------------------------------------------  
   g_Signed_Unsigned: if(G_IS_SIGNED = '0' and G_IS_SUBTRATCTION = '0') generate
      dout_int <= std_logic_vector(resize(unsigned(dina_int),add_length+1) + resize(unsigned(dinb_int),add_length+1));
   elsif(G_IS_SUBTRATCTION = '0') generate
      dout_int <= std_logic_vector(resize(signed(dina_int),add_length+1) + resize(signed(dinb_int),add_length+1));
   elsif(G_IS_SIGNED = '0' and G_IS_SUBTRATCTION = '1') generate
      dout_int <= std_logic_vector(resize(unsigned(dina_int),add_length+1) - resize(unsigned(dinb_int),add_length+1));
   else generate
      dout_int <= std_logic_vector(resize(signed(dina_int),add_length+1) - resize(signed(dinb_int),add_length+1));
   end generate g_Signed_Unsigned;
----------------------------------------------
-- Output Pipelines
-- Desc: Optional Output Pipelining
----------------------------------------------  
   pipe_DOUT : pipe generic map(G_RANK => G_NUM_OUT_PIPES, G_USE_RST => G_USE_RST, G_IS_SYNC_RST => G_IS_SYNC_RST) 
   port map(CLK => CLK,RST => RST, D => dout_int, Q => DOUT);

end behavioral;
