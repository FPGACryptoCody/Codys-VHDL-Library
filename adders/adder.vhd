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
use ieee.numeric_std.all;     -- For unsigned & signed

entity adder_2input is
generic(
   -- Pipes
      G_NUM_IN_PIPES    : natural:=1;     -- Number of input pipelines
      G_NUM_OUT_PIPES   : natural:=1;     -- Number of output pipelines
   -- Parameters
      G_USE_RESET       : std_logic:='1'; -- '1' use reset logic, '0' remove reset logic
      G_IS_SIGNED       : std_logic:='1'  -- '1' inputs/outputs are signed binary, '0' inputs/outputs are unsigned binary
   );
port ( 
      CLK   : in std_logic;                     -- System Clock
      SRST  : in std_logic;                     -- Synchronous Reset

      DINA  : in std_logic_vector(0 downto 0);  -- First Data Input
      DINB  : in std_logic_vector(0 downto 0);  -- Second Data Input

      DOUT  : out std_logic_vector(1 downto 0)  -- Data Output
    );
end adder_2input;

architecture behavioral of adder_2input is

-- Signals & Types 
   type pipe_in is array (0 to G_NUM_IN_PIPES) of std_logic_vector(DINA'length -1 downto 0); -- Same as input width
   signal dina_int, dinb_int : pipe_in;   -- Input flops
   type pipe_out is array (0 to G_NUM_OUT_PIPES) of std_logic_vector(DINA'length downto 0);  -- Addition operation is 1-bit growth
   signal dout_int : pipe_out;            -- Output flops

begin
    
----------------------------------------------
-- Input Pipelines
-- Desc: Optional Input Pipelining
----------------------------------------------  
   dina_int(0)  <= DINA;
   dinb_int(0)  <= DINB;
   process(CLK)
   begin
      if(rising_edge(CLK)) then
         if(SRST = '1' and G_USE_RESET = '1') then -- Reset all input pipelines to 0
            for i in 1 to G_NUM_IN_PIPES loop -- Loop for the number of pipelines desired
               dina_int(i) <= (others=>'0');
               dinb_int(i) <= (others=>'0');
            end loop;
         else
            for i in 1 to G_NUM_IN_PIPES loop -- Loop for the number of pipelines desired
               dina_int(i) <= dina_int(i-1); 
               dinb_int(i) <= dinb_int(i-1); 
               end loop;
         end if;
      end if;
   end process;
----------------------------------------------
-- Addition Operation
-- Signed and Unsigned addition operators
----------------------------------------------  
   g_Signed_Unsigned: if(G_IS_SIGNED = '1') generate
      dout_int(0) <= std_logic_vector(resize(unsigned(dina_int(G_NUM_IN_PIPES)),DINA'length+1) + resize(unsigned(dinb_int(G_NUM_IN_PIPES)),DINA'length+1));
   else generate
      dout_int(0) <= std_logic_vector(resize(signed(dina_int(G_NUM_IN_PIPES)),DINA'length+1) + resize(signed(dinb_int(G_NUM_IN_PIPES)),DINA'length+1));
   end generate g_Signed_Unsigned;
----------------------------------------------
-- Output Pipelines
-- Desc: Optional Output Pipelining
----------------------------------------------  
   process(CLK)
   begin
      if(rising_edge(CLK)) then
         if(SRST = '1' and G_USE_RESET = '1') then -- Reset all input pipelines to 0
            for i in 1 to G_NUM_OUT_PIPES loop -- Loop for the number of pipelines desired
               dout_int(i)<= (others=>'0');
            end loop;
         else
            for i in 1 to G_NUM_OUT_PIPES loop -- Loop for the number of pipelines desired
               dout_int(i) <= dout_int(i-1);
            end loop;
         end if;
      end if;
   end process;

   DOUT <= dout_int(G_NUM_OUT_PIPES);

end behavioral;
