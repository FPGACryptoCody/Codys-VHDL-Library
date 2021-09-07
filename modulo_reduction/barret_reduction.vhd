-- Title: Barret Reduction
-- Created by: Cody Emerson
-- Date: 6/21/2021
-- Target: Xilinx Ultrascale
--|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
-- Description: Calculate x mod n using Barret's Method
--|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity barret_reduction is
   generic(
      G_USE_STATIC_MODULUS    : std_logic:='1'; -- '1' use generics for reductions, '0' use ports for reductions
      G_NUM_IN_PIPES          : natural:=1; -- Number of pipelines on all inputs
      G_NUM_OUT_PIPES         : natural:=1; -- Number of pipelines on all outputs
      G_USE_RST               : std_logic:='0'; -- '1' enable SRST port, '0' disable SRST port
      G_IS_SYNC_RST           : std_logic:='1'; -- '1' use synchronous reset, '0' use asychronous reset
   -- Static or Dynamic modulus
      G_R                     : std_logic_vector:=x"1"; -- R multiplier for x*R
      G_K2                    : std_logic_vector:=x"1"; -- Divider for x*r/4*k
      G_MODULUS               : std_logic_vector:=x"3"; -- Modulus for reduction
   -- Tweaking Pipelines
      G_NUM_RMULT_IN_PIPES    : natural:=2; -- Number of pipelines on input of R multiplier
      G_NUM_RMULT_OUT_PIPES   : natural:=3; -- Number of pipelines on output of R multiplier
      G_NUM_MODMULT_IN_PIPES  : natural:=2; -- Number of pipelines on input of Modulus multiplier
      G_NUM_MODMULT_OUT_PIPES : natural:=3; -- Number of pipelines on output of Modulus multiplier
      G_NUM_TSUB_PIPES        : natural:=1  -- Number of pipelines on output of t subtractor
   );
	port(
		CLK            : in std_logic;          -- System Cock
      RST            : in std_logic;          -- Synchronous Reset
   -- Config 
      R              : in std_logic_vector;   -- R multiplier for x*R
      K2             : in std_logic_vector;   -- divider for x*r/(4*k)

      MODULUS        : in std_logic_vector;   -- Modulus      
      DIN            : in std_logic_vector;   -- Input, Can be any length
      ENA            : in std_logic;          -- Ena only drives the VLD output to indicate processing is complete
      DOUT           : out std_logic_vector;  -- Output, restricted to the length of the modulus, naturally
      VLD            : out std_logic          -- '1' when dout is valid, '0' otherwise
   );
end barret_reduction;

architecture behavioral of barret_reduction is

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

   component adder_2input is
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
      CLK   : in std_logic;               -- System Clock
      RST   : in std_logic;               -- Synchronous Reset

      DINA  : in std_logic_vector;        -- First Data Input
      DINB  : in std_logic_vector;        -- Second Data Input

      DOUT  : out std_logic_vector        -- Data Output
    );
   end component adder_2input;

   component multiplier is
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
   end component multiplier;

-- Signals
 -- Input Pipelines
   signal din_int      : std_logic_vector(DIN'range);
   signal din_delay      : std_logic_vector(DIN'range);
begin

----------------------------------------------
-- Input Pipelines
-- Desc: Optional Input Pipelining
----------------------------------------------  
pipe_DIN : pipe generic map(G_RANK => G_NUM_IN_PIPES, G_USE_RST => G_USE_RST, G_IS_SYNC_RST => G_IS_SYNC_RST) 
port map(CLK => CLK,RST => RST, D => DIN, Q => din_int);

pipe_DIN_Delay : pipe generic map(G_RANK => G_NUM_RMULT_IN_PIPES + G_NUM_RMULT_OUT_PIPES + G_NUM_MODMULT_IN_PIPES + G_NUM_MODMULT_OUT_PIPES,
                                  G_IS_DELAY => "TRUE", G_USE_RST => G_USE_RST, G_IS_SYNC_RST => G_IS_SYNC_RST) 
port map(CLK => CLK,RST => RST, D => din_int, Q => din_delay);

-- Create valid signal based of the total delay of the block
pipe_ENA_VLD : pipe generic map(G_RANK => G_NUM_IN_PIPES + G_NUM_OUT_PIPES + G_NUM_RMULT_IN_PIPES + G_NUM_RMULT_OUT_PIPES +
                                 G_NUM_MODMULT_IN_PIPES + G_NUM_MODMULT_OUT_PIPES + G_NUM_TSUB_PIPES, G_IS_DELAY => "TRUE", G_USE_RST => G_USE_RST, 
                                 G_IS_SYNC_RST => G_IS_SYNC_RST) 
port map(CLK => CLK,RST => RST, D(0) => ENA, Q(0) => VLD);

----------------------------------------------
-- Dynamic Block
-- Desc: Modulus and barret parameters are the input ports
----------------------------------------------  
block_Dynamic: block
-- Signals
 -- Input Pipelines
   signal r_int        : std_logic_vector(R'range);
   signal k2_int       : std_logic_vector(K2'range);
   signal modulus_int  : std_logic_vector(MODULUS'range);
   signal ena_int      : std_logic;
 -- R multiplier   
   signal mult_r       : std_logic_vector(DIN'length + R'length -1 downto 0);
 -- 4^k Divider  
   signal div_q_div2k  : std_logic_vector(mult_r'length -1 downto 0);
 -- Modulus Multiplier  
   signal mult_mod     : std_logic_vector(div_q_div2k'length+MODULUS'length-1 downto 0);
 -- Output  
   signal dout_int     : std_logic_vector(MODULUS'range);
-- Functions
   function t_length return natural is
      begin
         if (din_int'length > mult_mod'length) then
            return natural(din_int'length);
         else
            return natural(mult_mod'length);
         end if;
   end function t_length; 
 -- T subtractor  
   signal t            : std_logic_vector(t_length downto 0);

begin
gen_Dynamic: if(G_USE_STATIC_MODULUS = '0') generate
----------------------------------------------
-- Input Pipelines
-- Desc: Optional Input Pipelining
----------------------------------------------  
   pipe_R : pipe generic map(G_RANK => G_NUM_IN_PIPES, G_USE_RST => G_USE_RST, G_IS_SYNC_RST => G_IS_SYNC_RST) 
   port map(CLK => CLK,RST => RST, D => R , Q => r_int);

   pipe_K2 : pipe generic map(G_RANK => G_NUM_IN_PIPES, G_USE_RST => G_USE_RST, G_IS_SYNC_RST => G_IS_SYNC_RST) 
   port map(CLK => CLK,RST => RST, D => K2 , Q => k2_int);

   pipe_MODULUS: pipe generic map(G_RANK => G_NUM_IN_PIPES, G_USE_RST => G_USE_RST, G_IS_SYNC_RST => G_IS_SYNC_RST) 
   port map(CLK => CLK,RST => RST, D => MODULUS, Q => modulus_int);
  
-----------------------------------------------------------------------------------
-- din_r = DIN * R
-- Desc: Multiply DIN by R factor
----------------------------------------------------------------------------------- 
   comp_Mult_DIN_R: multiplier 
   generic map(
      G_IN_PIPES      => G_NUM_RMULT_IN_PIPES,  -- : natural:= 2;    -- Pipe delays on A and B. 
      G_OUT_PIPES     => G_NUM_RMULT_OUT_PIPES, -- : natural:= 2;    -- Pipe delays on P_OUT
      G_USE_RST       => G_USE_RST,             -- : std_logic:='0'; -- '1' enable resets, '0' disable resets
      G_IS_SYNC_RST   => G_IS_SYNC_RST,         -- : std_logic:='1'; -- '1' use synchronous reset, '0' use asynchronous reset
      G_A_IS_SIGNED   => '0',                   -- : std_logic:='0'; -- '1' A_IN is signed, '0' A_IN is unsigned
      G_B_IS_SIGNED   => '0'                    -- : std_logic:='0'  -- '1' B_IN is signed, '0' B_IN is unsigned
   )
   port map(
      CLK             => CLK,                   -- : in  std_logic;
      RST             => RST,                   -- : in  std_logic;

      A_IN            => din_int,               -- : in  std_logic_vector; -- A Input
      B_IN            => r_int,                 -- : in  std_logic_vector; -- B Input
      P_OUT           => mult_r                 -- : out std_logic_vector  -- A*B output, A_IN'len + B_IN'len - 1 downto 0)
   ); -- multiplier;

-------------------------------------------------------------------------------------
---- din_q_div2k = (DIN * R)/(4*k)
---- Desc: Right shit to divide by factor of 2
------------------------------------------------------------------------------------- 
   div_q_div2k <= std_logic_vector(resize(shift_right(unsigned(mult_r),to_integer(unsigned(k2_int))),mult_r'length));
-------------------------------------------------------------------------------------
---- din_r = ((DIN * R)/(2*k))*Q
---- Desc: Right shit to divide by factor of 2
------------------------------------------------------------------------------------- 
   comp_Mult_Q: multiplier 
   generic map(
      G_IN_PIPES      => G_NUM_MODMULT_IN_PIPES,  -- : natural:= 2;    -- Pipe delays on A and B. 
      G_OUT_PIPES     => G_NUM_MODMULT_OUT_PIPES, -- : natural:= 2;    -- Pipe delays on P_OUT
      G_USE_RST       => G_USE_RST,               -- : std_logic:='0'; -- '1' enable resets, '0' disable resets
      G_IS_SYNC_RST   => G_IS_SYNC_RST,           -- : std_logic:='1'; -- '1' use synchronous reset, '0' use asynchronous reset
      G_A_IS_SIGNED   => '0',                     -- : std_logic:='0'; -- '1' A_IN is signed, '0' A_IN is unsigned
      G_B_IS_SIGNED   => '0'                      -- : std_logic:='0'  -- '1' B_IN is signed, '0' B_IN is unsigned
   )
   port map(
      CLK             => CLK,                     -- : in  std_logic;
      RST             => RST,                     -- : in  std_logic;

      A_IN            => div_q_div2k,             -- : in  std_logic_vector; -- A Input
      B_IN            => modulus_int,             -- : in  std_logic_vector; -- B Input
      P_OUT           => mult_mod                 -- : out std_logic_vector  -- A*B output, A_IN'len + B_IN'len - 1 downto 0)
   ); -- multiplier;
   
-----------------------------------------------------------------------------------
-- t = DIN - ((DIN * R)/(2*k))*Q
-- Desc: 
----------------------------------------------------------------------------------- 
   comp_T_Subtractor: adder_2input 
   generic map(
   -- Pipes
      G_NUM_IN_PIPES    => 0,                 -- : natural:=1;     -- Number of input pipelines
      G_NUM_OUT_PIPES   => G_NUM_TSUB_PIPES,  -- : natural:=1;     -- Number of output pipelines
      G_USE_RST         => G_USE_RST,         -- : std_logic:='0'; -- '1' use reset logic, '0' remove reset logic
      G_IS_SYNC_RST     => G_IS_SYNC_RST,     -- : std_logic:='1'; -- '1' use synchronous reset, '0' use asynchronous reset
      -- Parameters
      G_IS_SIGNED       => '0',               -- : std_logic:='0'; -- '1' inputs/outputs are signed binary, '0' inputs/outputs are unsigned binary
      G_IS_SUBTRATCTION => '1'                -- : std_logic:='0'  -- '1' Add, '0' subtract
   )
   port map ( 
      CLK   => CLK,                           -- : in std_logic;                     -- System Clock
      RST   => RST,                           -- : in std_logic;                     -- Synchronous Reset

      DINA  => din_delay,                     -- : in std_logic_vector(0 downto 0);  -- First Data Input
      DINB  => mult_mod,                      -- : in std_logic_vector(0 downto 0);  -- Second Data Input

      DOUT  => t                              -- : out std_logic_vector(1 downto 0)  -- Data Output
    ); --adder_2input;t;

-----------------------------------------------------------------------------------
-- DOUT = t if t < q others t -q
-- Desc: 
----------------------------------------------------------------------------------- 
   p_OutMux: process(ALL)
   begin
      if(t < modulus_int) then
         dout_int <= t(MODULUS'length -1 downto 0);
      else
         dout_int <= std_logic_vector(resize(unsigned(t) - unsigned(modulus_int),MODULUS'length));
      end if;
   end process;

-------------------------------------------------------------------------------------
---- Optional Output Pipes
------------------------------------------------------------------------------------- 
   pipe_DOUT: pipe generic map(G_RANK => G_NUM_OUT_PIPES, G_USE_RST => G_USE_RST,G_IS_SYNC_RST => G_IS_SYNC_RST) 
   port map(CLK => CLK,RST => RST, D => dout_int, Q => DOUT);
end generate gen_Dynamic;
end block block_Dynamic;

block_Static: block
-- Signals
 -- Input Pipelines
   signal r_int        : std_logic_vector(G_R'range);
   signal k2_int       : std_logic_vector(G_K2'range);
   signal modulus_int  : std_logic_vector(G_MODULUS'range);
 -- R multiplier   
   signal mult_r       : std_logic_vector(DIN'length + G_R'length -1 downto 0);
 -- 4^k Divider  
   signal div_q_div2k  : std_logic_vector(mult_r'length -1 downto 0);
 -- Modulus Multiplier  
   signal mult_mod     : std_logic_vector(div_q_div2k'length+G_MODULUS'length-1 downto 0);
 -- Output  
   signal dout_int     : std_logic_vector(G_MODULUS'range);
-- Functions
   function t_length return natural is
      begin
         if (din_int'length > mult_mod'length) then
            return natural(din_int'length);
         else
            return natural(mult_mod'length);
         end if;
   end function t_length; 
 -- T subtractor 
   signal t            : std_logic_vector(t_length downto 0);
begin
gen_Static: if(G_USE_STATIC_MODULUS = '1') generate
-----------------------------------------------------------------------------------
-- din_r = DIN * R
-- Desc: Multiply DIN by R factor
----------------------------------------------------------------------------------- 
   comp_Mult_DIN_R: multiplier 
   generic map(
      G_IN_PIPES      => G_NUM_RMULT_IN_PIPES,  -- : natural:= 2;    -- Pipe delays on A and B. 
      G_OUT_PIPES     => G_NUM_RMULT_OUT_PIPES, -- : natural:= 2;    -- Pipe delays on P_OUT
      G_USE_RST       => G_USE_RST,             -- : std_logic:='0'; -- '1' enable resets, '0' disable resets
      G_IS_SYNC_RST   => G_IS_SYNC_RST,         -- : std_logic:='1'; -- '1' use synchronous reset, '0' use asynchronous reset
      G_A_IS_SIGNED   => '0',                   -- : std_logic:='0'; -- '1' A_IN is signed, '0' A_IN is unsigned
      G_B_IS_SIGNED   => '0'                    -- : std_logic:='0'  -- '1' B_IN is signed, '0' B_IN is unsigned
   )
   port map(
      CLK             => CLK,                   -- : in  std_logic;
      RST             => RST,                   -- : in  std_logic;

      A_IN            => din_int,               -- : in  std_logic_vector; -- A Input
      B_IN            => G_R,                   -- : in  std_logic_vector; -- B Input
      P_OUT           => mult_r                 -- : out std_logic_vector  -- A*B output, A_IN'len + B_IN'len - 1 downto 0)
   ); -- multiplier;

-------------------------------------------------------------------------------------
---- din_q_div2k = (DIN * R)/(4*k)
---- Desc: Right shit to divide by factor of 2
------------------------------------------------------------------------------------- 
   div_q_div2k <= std_logic_vector(resize(shift_right(unsigned(mult_r),to_integer(unsigned(G_K2))),mult_r'length));
-------------------------------------------------------------------------------------
---- din_r = ((DIN * R)/(2*k))*Q
---- Desc: Right shit to divide by factor of 2
------------------------------------------------------------------------------------- 
   comp_Mult_Q: multiplier 
   generic map(
      G_IN_PIPES      => G_NUM_MODMULT_IN_PIPES,  -- : natural:= 2;    -- Pipe delays on A and B. 
      G_OUT_PIPES     => G_NUM_MODMULT_OUT_PIPES, -- : natural:= 2;    -- Pipe delays on P_OUT
      G_USE_RST       => G_USE_RST,               -- : std_logic:='0'; -- '1' enable resets, '0' disable resets
      G_IS_SYNC_RST   => G_IS_SYNC_RST,           -- : std_logic:='1'; -- '1' use synchronous reset, '0' use asynchronous reset
      G_A_IS_SIGNED   => '0',                     -- : std_logic:='0'; -- '1' A_IN is signed, '0' A_IN is unsigned
      G_B_IS_SIGNED   => '0'                      -- : std_logic:='0'  -- '1' B_IN is signed, '0' B_IN is unsigned
   )
   port map(
      CLK             => CLK,                     -- : in  std_logic;
      RST             => RST,                     -- : in  std_logic;

      A_IN            => div_q_div2k,             -- : in  std_logic_vector; -- A Input
      B_IN            => G_MODULUS,               -- : in  std_logic_vector; -- B Input
      P_OUT           => mult_mod                 -- : out std_logic_vector  -- A*B output, A_IN'len + B_IN'len - 1 downto 0)
   ); -- multiplier;
   
-----------------------------------------------------------------------------------
-- t = DIN - ((DIN * R)/(2*k))*Q
-- Desc: Right shit to divide by factor of 2
----------------------------------------------------------------------------------- 
   comp_T_Subtractor: adder_2input 
   generic map(
   -- Pipes
      G_NUM_IN_PIPES    => 0,                 -- : natural:=1;     -- Number of input pipelines
      G_NUM_OUT_PIPES   => G_NUM_TSUB_PIPES,  -- : natural:=1;     -- Number of output pipelines
      G_USE_RST         => G_USE_RST,         -- : std_logic:='0'; -- '1' use reset logic, '0' remove reset logic
      G_IS_SYNC_RST     => G_IS_SYNC_RST,     -- : std_logic:='1'; -- '1' use synchronous reset, '0' use asynchronous reset
      -- Parameters
      G_IS_SIGNED       => '0',               -- : std_logic:='0'; -- '1' inputs/outputs are signed binary, '0' inputs/outputs are unsigned binary
      G_IS_SUBTRATCTION => '1'                -- : std_logic:='0'  -- '1' Add, '0' subtract
   )
   port map ( 
      CLK   => CLK,                           -- : in std_logic;                     -- System Clock
      RST   => RST,                           -- : in std_logic;                     -- Synchronous Reset

      DINA  => din_delay,                     -- : in std_logic_vector(0 downto 0);  -- First Data Input
      DINB  => mult_mod,                      -- : in std_logic_vector(0 downto 0);  -- Second Data Input

      DOUT  => t                              -- : out std_logic_vector(1 downto 0)  -- Data Output
    ); --adder_2input;t;
   
-----------------------------------------------------------------------------------
-- DOUT = t if t < q others t -q
-- Desc: 
----------------------------------------------------------------------------------- 
   p_OutMux: process(ALL)
   begin
      if(unsigned(t) < unsigned(G_MODULUS)) then
         dout_int <= t(G_MODULUS'length -1 downto 0);
      else
         dout_int <= std_logic_vector(resize(unsigned(t) - unsigned(G_MODULUS),G_MODULUS'length));
      end if;
   end process;

-------------------------------------------------------------------------------------
---- Optional Output Pipes
------------------------------------------------------------------------------------- 
   pipe_DOUT: pipe generic map(G_RANK => G_NUM_OUT_PIPES, G_USE_RST => G_USE_RST,G_IS_SYNC_RST => G_IS_SYNC_RST) 
   port map(CLK => CLK,RST => RST, D => dout_int, Q => DOUT);
end generate gen_Static;
end block block_Static;

end behavioral;
