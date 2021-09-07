--|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
-- Title: Inferred Multiplier
-- Created by: Cody Emerson
-- Date: 6/30/2021
-- Target: Xilinx Ultrascale
--|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
-- Description: Infer a signed or unsigned multiplier
--|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity multiplier is
   generic(
      G_IN_PIPES      : natural:= 2;    -- Pipe delays on A and B. 
      G_OUT_PIPES     : natural:= 2;    -- Pipe delays on P_OUT
      G_USE_RST       : std_logic:='0'; -- '1' enable resets, '0' disable resets
      G_IS_SYNC_RST   : std_logic:='1'; -- '1' use synchronous reset, '0' use asynchronous reset
      G_A_IS_SIGNED   : std_logic:='0'; -- '1' A_IN is signed, '0' A_IN is unsigned
      G_B_IS_SIGNED   : std_logic:='0'  -- '1' B_IN is signed, '0' B_IN is unsigned
   );
   port(
      CLK             : in  std_logic;
      RST             : in  std_logic;

      A_IN            : in  std_logic_vector; -- A Input
      B_IN            : in  std_logic_vector; -- B Input
      P_OUT           : out std_logic_vector  -- A*B output, A_IN'len + B_IN'len - 1 downto 0)
   );
end multiplier;

architecture behavioral of multiplier is

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
   ); end component pipe;

-- Signals
   -- Input flops
   signal a_in_piped          : std_logic_vector(A_IN'range);
   signal b_in_piped          : std_logic_vector(B_IN'range);

   -- Multiply
   function a_multiply_length return natural is
      begin
         if (G_A_IS_SIGNED = '1' or G_B_IS_SIGNED = '1') then
            return natural(A_IN'length);
         else
            return natural(A_IN'length -1);
         end if;
   end function a_multiply_length;

   function b_multiply_length return natural is
      begin
         if (G_A_IS_SIGNED = '1' or G_B_IS_SIGNED = '1') then
            return natural(B_IN'length);
         else
            return natural(B_IN'length-1);
         end if;
   end function b_multiply_length;

   signal a_signed_mult       : signed(a_multiply_length downto 0);
   signal b_signed_mult       : signed(b_multiply_length downto 0);

   signal a_unsigned_mult     : unsigned(A_IN'length -1 downto 0);
   signal b_unsigned_mult     : unsigned(B_IN'length -1 downto 0);   

   signal product_signed      : signed(a_signed_mult'length + b_signed_mult'length - 1 downto 0);
   signal product_unsigned    : unsigned(a_signed_mult'length + b_signed_mult'length - 1 downto 0);

   -- Output flops
   signal product             : std_logic_vector(a_signed_mult'length + b_signed_mult'length - 1 downto 0);

begin
----------------------------------------------
-- Input Pipelines
-- Desc: Optional Input Pipelining
----------------------------------------------  
   pipe_a : pipe
   generic map(G_RANK => G_IN_PIPES, G_USE_RST => G_USE_RST, G_IS_SYNC_RST => G_IS_SYNC_RST)
   port map(CLK => CLK,RST => RST, D => A_IN,Q => a_in_piped);

   pipe_b : pipe
   generic map(G_RANK => G_IN_PIPES, G_USE_RST => G_USE_RST, G_IS_SYNC_RST => G_IS_SYNC_RST)
   port map(CLK => CLK,RST => RST, D => B_IN,Q => b_in_piped);

----------------------------------------------
-- Signed conversations
-- Desc: If either of the inputs are signed, convert any unsigned inputs to signed
---------------------------------------------- 
   -- Convert Inputs to signed type
   gen_a_signed : if (G_A_IS_SIGNED = '0' and G_B_IS_SIGNED = '1') generate
      a_signed_mult   <= signed('0' & a_in_piped);                      -- sign bit is '0'
   else generate
      a_signed_mult   <= signed(a_in_piped);                            -- No need to extend
   end generate;

   -- Convert Inputs to signed type
   gen_b_signed : if (G_A_IS_SIGNED = '1' and G_B_IS_SIGNED = '0') generate
      b_signed_mult   <= signed('0' & b_in_piped);                      -- sign bit is '0'
   else generate
      b_signed_mult   <= signed(b_in_piped);                            -- No need to extend
   end generate;

----------------------------------------------
-- Unsigned assignments
-- Desc: Create unsigned vectors
---------------------------------------------- 
   a_unsigned_mult <= unsigned(a_in_piped);
   b_unsigned_mult <= unsigned(b_in_piped);

----------------------------------------------
-- Multiplication
-- Desc: multiply a by b
---------------------------------------------- 
   p_multiply: process(a_signed_mult, b_signed_mult)
   begin
      product_signed   <= a_signed_mult * b_signed_mult;
      product_unsigned <= a_unsigned_mult * b_unsigned_mult;
   end process p_multiply;

----------------------------------------------
-- Unsigned/Signed Decision
-- Desc: Select the signed or unsigned output based off generics
---------------------------------------------- 
   gen_signed_unsigned: if(G_A_IS_SIGNED = '1' or G_B_IS_SIGNED = '1') generate
      product <=  std_logic_vector(product_signed((A_IN'length + B_IN'length -1) downto 0));
   else generate
      product <=  std_logic_vector(product_unsigned((A_IN'length + B_IN'length -1) downto 0));
   end generate;

----------------------------------------------
-- Output Pipelines
-- Desc: Optional Output Pipelining
---------------------------------------------- 
   -- Delay the output by G_OUT_PIPES
   pipe_product : pipe
   generic map(G_RANK => G_OUT_PIPES, G_USE_RST => G_USE_RST, G_IS_SYNC_RST => G_IS_SYNC_RST)
   port map(CLK => CLK,RST => RST, D => product,Q => P_OUT);

end behavioral;