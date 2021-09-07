--|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
-- Title: Carry Save Adder
-- Created by: Cody Emerson
-- Date: 6/16/2021
-- Target: Xilinx Ultrascale
--|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
-- Description: Add 3 binary numbers of arbitrary length to give
-- a 2 output representation of the sum. Add the results to
-- Calculate the final sum
--    
--|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;     -- For unsigned & signed

entity adder_carry_save is
generic(
   -- Pipes
      G_NUM_IN_PIPES    : natural:=1;     -- Number of input pipelines
      G_NUM_OUT_PIPES   : natural:=1;     -- Number of output pipelines
   -- Parameters
      G_USE_RESET       : std_logic:='1'  -- '1' use reset logic, '0' remove reset logic
   );
port ( 
      CLK   : in std_logic;                     -- System Clock
      SRST  : in std_logic;                     -- Synchronous Reset

      DINA  : in std_logic_vector(0 downto 0);  -- First  Data Input
      DINB  : in std_logic_vector(0 downto 0);  -- Second Data Input
      DINC  : in std_logic_vector(0 downto 0);  -- Third  Data Input

      DOUT  : out std_logic_vector(1 downto 0); -- Output
      COUT  : out std_logic_vector(1 downto 0)  -- Carry Output
    );
end adder_carry_save;

architecture behavioral of adder_carry_save is

-- Signals & Types 
   type pipe_in is array (0 to G_NUM_IN_PIPES) of std_logic_vector(DINA'length -1 downto 0); -- Same as input width
   signal dina_int, dinb_int, dinc_int : pipe_in;   -- Input flops
   type pipe_out is array (0 to G_NUM_OUT_PIPES) of std_logic_vector(DINA'length -1 downto 0);  -- Addition operation is 1-bit growth
   signal dout_int, cout_int : pipe_out;            -- Output flops

-- Intermediate Signals
    signal dina_xor_dinb           : std_logic_vector(DINA'range);

    signal dinadinb                : std_logic_vector(DINA'range);
    signal dinadinc                : std_logic_vector(DINA'range);
    signal dinbdinc                : std_logic_vector(DINA'range);
    signal dinadinb_or_dinadinc    : std_logic_vector(DINA'range);

begin
----------------------------------------------
-- Input Pipelines
-- Desc: Optional Input Pipelining
----------------------------------------------  
   dina_int(0)  <= DINA;
   dinb_int(0)  <= DINB;
   dinc_int(0)  <= DINC;
   process(CLK)
   begin
      if(rising_edge(CLK)) then
         if(SRST = '1' and G_USE_RESET = '1') then -- Reset all input pipelines to 0
            for i in 1 to G_NUM_IN_PIPES loop -- Loop for the number of pipelines desired
               dina_int(i) <= (others=>'0');
               dinb_int(i) <= (others=>'0');
               dinc_int(i) <= (others=>'0');
            end loop;
         else
            for i in 1 to G_NUM_IN_PIPES loop -- Loop for the number of pipelines desired
               dina_int(i) <= dina_int(i-1); 
               dinb_int(i) <= dinb_int(i-1); 
               dinc_int(i) <= dinc_int(i-1); 
               end loop;
         end if;
      end if;
   end process;
----------------------------------------------
-- DOUT Calculation
-- DOUT = A xor B xor C
----------------------------------------------  
    dina_xor_dinb <= dina_int(G_NUM_IN_PIPES) xor dinb_int(G_NUM_IN_PIPES);
    dout_int(0) <= dina_xor_dinb xor dinc_int(G_NUM_IN_PIPES);
----------------------------------------------
-- COUT Calculation
-- COUT = AB + AC + BC (bitwise)
---------------------------------------------- 
    dinadinb <= dina_int(G_NUM_IN_PIPES) and dinb_int(G_NUM_IN_PIPES);
    dinadinc <= dina_int(G_NUM_IN_PIPES) and dinc_int(G_NUM_IN_PIPES);
    dinbdinc <= dinb_int(G_NUM_IN_PIPES) and dinc_int(G_NUM_IN_PIPES);

    dinadinb_or_dinadinc <= dinadinb or dinadinc;
    cout_int(0) <= dinadinb_or_dinadinc or dinbdinc;
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
               cout_int(i)<= (others=>'0');
            end loop;
         else
            for i in 1 to G_NUM_OUT_PIPES loop -- Loop for the number of pipelines desired
               dout_int(i) <= dout_int(i-1);
               cout_int(i)<= cout_int(i-1);
            end loop;
         end if;
      end if;
   end process;

   DOUT <= '0' & dout_int(G_NUM_OUT_PIPES);
   COUT <= cout_int(G_NUM_OUT_PIPES) & '0';

end behavioral;
