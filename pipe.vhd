--|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
-- Title: Inferred Multiplier
-- Created by: Cody Emerson
-- Date: 6/30/2021
-- Target: Xilinx Ultrascale
--|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
-- Description: Create a pipeline for timing purposes or a delay
-- for function alignment. 
--|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
library ieee;
use ieee.std_logic_1164.all;

entity pipe is
   generic(
      G_RANK     : integer:=1;            -- Number of pipeline stages 
      G_IS_DELAY : string:="FALSE";       -- "TRUE" use this block as a pipeline, "FALSE" use this block as a delay
      G_USE_RST  : std_logic:='0';        -- '1' synthesize resets, '0' do not synthesize resets
      G_SYNC_RST : std_logic:='1'         -- '1' use synchronous reset, '0' use asychronous reset
   );
   port (
      CLK        : in  std_logic;         -- System Clock
      RST        : in  std_logic;         -- Reset, Can be async or sync        
      D          : in  std_logic_vector;  -- Input Data
      Q          : out std_logic_vector   -- Output Data
   );
end pipe;

architecture behavioral of pipe is

-- Attributes
 -- This attribute prevents synthesizes from packing flip-flops into shift register look up tables
attribute shreg_extract : string;
-- Types
 -- Create an array of std_logic_vectors of input length
type array_type is array(G_RANK - 1 downto 0) of std_logic_vector(D'range);
-- Signals
signal pipe_array : array_type;
-- Attribute Assignments
 -- If using this block for pipelining, set to false
 -- If using this block for delay, set to true
attribute shreg_extract of pipe_array : signal is G_IS_DELAY;

begin

------------------------------------------------
-- Zero or Negative Case
-- Desc: Passthrough the data without flops for the negative or zero case
------------------------------------------------
gen_Pipes: if(G_RANK <= 0)  generate
   Q <= D; 
else generate

------------------------------------------------
-- Positive Cases
-- Desc: Create number of flip flops based of the value of G_RANK
------------------------------------------------
   p_pipeline: process(ALL)
   begin
      if(G_USE_RST = '1' and G_SYNC_RST = '0' and RST = '1') then
         for i in 0 to G_RANK - 1 loop
            pipe_array(i) <= (others=>'0');
         end loop;
      elsif(rising_edge(CLK)) then
         if(G_USE_RST = '1' and G_SYNC_RST = '1' and RST = '1') then
            for i in 0 to G_RANK - 1 loop
               pipe_array(i) <= (others=>'0');
            end loop;
         else
            pipe_array(0) <= D;
            for i in 0 to G_RANK - 2 loop
               pipe_array(i+1) <= pipe_array(i);
            end loop;
         end if;
      end if;
   end process p_pipeline;

   Q <= pipe_array(G_RANK - 1);

end generate gen_Pipes;

end behavioral;