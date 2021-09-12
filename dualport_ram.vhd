-- Title: Dual Port Ram
-- Created by: Cody Emerson
-- Date: 6/21/2021
-- Target: Xilinx Ultrascale
--|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
-- Description: Designed using xilinx template file
--|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.helper_functions.all;

entity dualport_ram is
   generic (
      G_RAM_WIDTH       : positive := 18;           -- RAM width
      G_RAM_DEPTH       : positive := 1024;         -- RAM depth 
      G_TYPE            : string := "LOW_LATENCY";  -- "HIGH_PERFORMANCE" or "LOW_LATENCY"
      G_COEF_FILE       : string := ""              --  Path of RAM initialization file 
   );
   port (
        ADDRA         : in std_logic_vector((ceil_log2(G_RAM_DEPTH)-1) downto 0);  
        ADDRB         : in std_logic_vector((ceil_log2(G_RAM_DEPTH)-1) downto 0);  
        DINA          : in std_logic_vector(G_RAM_WIDTH-1 downto 0);              
        DINB          : in std_logic_vector(G_RAM_WIDTH-1 downto 0);              
        CLKA          : in std_logic;                                             
        CLKB          : in std_logic;                                             
        WEA           : in std_logic;                                             
        WEB           : in std_logic;                                             
        ENA           : in std_logic;                                             
        ENB           : in std_logic;                                             
        RSTA          : in std_logic;                                             
        RSTB          : in std_logic;                                             
        REGCEA        : in std_logic;                                              
        REGCEB        : in std_logic;                                              
        DOUTA         : out std_logic_vector(G_RAM_WIDTH-1 downto 0);              
        DOUTB         : out std_logic_vector(G_RAM_WIDTH-1 downto 0)               
   ); 
end dualport_ram;

architecture behavioral of dualport_ram is
 
-- Types
   type ram_type is array (G_RAM_DEPTH-1 downto 0) of std_logic_vector (G_RAM_WIDTH-1 downto 0);
   
-- Signals 
   signal douta_reg : std_logic_vector(G_RAM_WIDTH-1 downto 0);
   signal doutb_reg : std_logic_vector(G_RAM_WIDTH-1 downto 0);

   signal ram_data_a : std_logic_vector(G_RAM_WIDTH-1 downto 0);
   signal ram_data_b : std_logic_vector(G_RAM_WIDTH-1 downto 0);
   
--Functions
   -- String to std_logic_vector
   --function str_to_slv(str : string) return std_logic_vector is
   --   alias str_norm : string(1 to str'length) is str;
   --   variable char_v : character;
   --   variable val_of_char_v : natural;
   --   variable res_v : std_logic_vector(4 * str'length - 1 downto 0);
   -- begin
   --for str_norm_idx in str_norm'range loop
   --   char_v := str_norm(str_norm_idx);
   --   case char_v is
   --      when '0' to '9' => val_of_char_v := character'pos(char_v) - character'pos('0');
   --      when 'A' to 'F' => val_of_char_v := character'pos(char_v) - character'pos('A') + 10;
   --      when 'a' to 'f' => val_of_char_v := character'pos(char_v) - character'pos('a') + 10;
   --      when others => report "str_to_slv: Invalid characters for convert" severity ERROR;
   --   end case;
   --   res_v(res_v'left - 4 * str_norm_idx + 4 downto res_v'left - 4 * str_norm_idx + 1) :=
   --   std_logic_vector(to_unsigned(val_of_char_v, 4));
   --   end loop;
   --   return res_v;
   --end function;

   --function initramfromfile (ramfilename : in string) return ram_type is
   --   file ramfile   : text open read_mode is ramfilename;
   --   variable ramfileline : line;
   --   variable ram_name : ram_type;
   --   variable bitvec : string((G_RAM_WIDTH-1)/4 downto 0);
   --begin
   --   for i in 0 to G_RAM_DEPTH -1 loop
   --      readline (ramfile, ramfileline);
   --      read (ramfileline, bitvec);
   --      ram_name(i) := str_to_slv(bitvec);
   --   end loop;
   --   return ram_name;
   --end function;

   --function init_from_file_or_zeroes(ramfile : string) return ram_type is
   --begin
   --   if ramfile /= "" then
   --      return InitRamFromFile(ramfile) ;
   --   else
   --      return (others => (others => '0'));
   --   end if;
   --end;

   shared variable ram_name : ram_type; -- := init_from_file_or_zeroes(G_COEF_FILE);

begin

   process(CLKA)
   begin
      if(rising_edge(CLKA)) then
         if(ena = '1') then
            if(wea = '1') then
               ram_name(to_integer(unsigned(addra))) := dina;
               ram_data_a <= dina;
            else
               ram_data_a <= ram_name(to_integer(unsigned(addra)));
            end if;
         end if;
      end if;
   end process;
   
   process(CLKB)
   begin
      if(rising_edge(CLKB)) then
         if(enb = '1') then
            if(web = '1') then
               ram_name(to_integer(unsigned(addrb))) := dinb;
               ram_data_b <= dinb;
            else
               ram_data_b <= ram_name(to_integer(unsigned(addrb)));
            end if;
         end if;
      end if;
   end process;
   
   no_output_register : if G_TYPE = "LOW_LATENCY" generate
      douta <= ram_data_a;
      doutb <= ram_data_b;
   end generate;
    
   output_register : if G_TYPE = "HIGH_PERFORMANCE"  generate
   process(CLKA)
   begin
      if(rising_edge(CLKA)) then
         if(rsta = '1') then
            douta_reg <= (others => '0');
         elsif(regcea = '1') then
            douta_reg <= ram_data_a;
         end if;
      end if;
   end process;
   douta <= douta_reg;
   
   process(CLKB)
   begin
      if(rising_edge(CLKB)) then
         if(rstb = '1') then
            doutb_reg <= (others => '0');
         elsif(regceb = '1') then
            doutb_reg <= ram_data_b;
         end if;
      end if;
   end process;
   doutb <= doutb_reg;
   
   end generate;
end behavioral;
