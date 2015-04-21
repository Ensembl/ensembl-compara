-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--      http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

--  set the "ensembl alias name" for each species used in Ensembl
--  this values are also uploaded in the meta table of each core db and then used by
--  the web code for display.

--  Search for 'ADD' below to copy+paste the empty template

SET @this_taxon_id=9601;
SET @this_value='Orangutan';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=10116;
SET @this_value='Rat';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=31033;
SET @this_value='Fugu';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=6239;
SET @this_value='C.elegans';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9031;
SET @this_value='Chicken';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=99883;
SET @this_value='Tetraodon';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9913;
SET @this_value='Cow';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=8364;
SET @this_value='X.tropicalis';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=4932;
SET @this_value='S.cerevisiae';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7719;
SET @this_value='C.intestinalis';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9606;
SET @this_value='Human';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7227;
SET @this_value='Fruitfly';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=10090;
SET @this_value='Mouse';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7955;
SET @this_value='Zebrafish';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=51511;
SET @this_value='C.savignyi';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=13616;
SET @this_value='Opossum';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9544;
SET @this_value='Macaque';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9785;
SET @this_value='Elephant';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9371;
SET @this_value='Tenrec';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9986;
SET @this_value='Rabbit';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9361;
SET @this_value='Armadillo';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=69293;
SET @this_value='Stickleback';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=8090;
SET @this_value='Medaka';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9598;
SET @this_value='Chimpanzee';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9615;
SET @this_value='Dog';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9258;
SET @this_value='Platypus';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9685;
SET @this_value='Cat';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9796;
SET @this_value='Horse';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9595;
SET @this_value='Gorilla';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

-- 2X genomes
SET @this_taxon_id=42254;
SET @this_value='Shrew';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=30611;
SET @this_value='Bushbaby';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=59463;
SET @this_value='Microbat';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9365;
SET @this_value='Hedgehog';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=10141;
SET @this_value='Guinea Pig';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=43179;
SET @this_value='Squirrel';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=37347;
SET @this_value='Tree Shrew';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=30608;
SET @this_value='Mouse Lemur';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9978;
SET @this_value='Pika';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9739;
SET @this_value='Dolphin';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9478;
SET @this_value='Tarsier';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=10020;
SET @this_value='Kangaroo rat';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=30538;
SET @this_value='Alpaca';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=132908;
SET @this_value='Megabat';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9813;
SET @this_value='Hyrax';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=59729;
SET @this_value='Zebra Finch';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9358;
SET @this_value='Sloth';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=28377;
SET @this_value='Anole Lizard';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9315;
SET @this_value='Wallaby';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9823;
SET @this_value='Pig';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9483;
SET @this_value='Marmoset';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=8049;
SET @this_value='Cod';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9103;
SET @this_value='Turkey';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9646;
SET @this_value='Panda';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=61853;
SET @this_value='Gibbon';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7757;
SET @this_value='Lamprey';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9305;
SET @this_value='Tasmanian devil';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=8128;
SET @this_value='Tilapia';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=13735;
SET @this_value='Chinese softshell turtle';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7897;
SET @this_value='Coelacanth';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=8083;
SET @this_value='Platyfish';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9669;
SET @this_value='Ferret';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

-- <Added for rel.73>

SET @this_taxon_id=8839;
SET @this_value='Duck';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=59894;
SET @this_value='Flycatcher';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

-- </Added for rel.73>

-- <rel.74>

SET @this_taxon_id=7994;
SET @this_value='Cave fish';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7918;
SET @this_value='Spotted gar';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9940;
SET @this_value='Sheep';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

-- </rel.74>

-- <rel.76>

SET @this_taxon_id=9555;
SET @this_value='Olive baboon';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=48698;
SET @this_value='Amazon molly';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;
-- </rel.76>

-- <rel.77>

SET @this_taxon_id=60711;
SET @this_value='Vervet/AGM';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;
-- </rel.77>


-- -- Use these to ADD new species

-- SET @this_taxon_id=;
-- SET @this_value='';
-- SET @this_name_class='ensembl alias name';
-- insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;


-- Internal nodes for the GeneTrees
SET @this_taxon_id=33553;
SET @this_value='Squirrels and Old World rodents';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=39107;
SET @this_value='Old World rodents';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=186625;
SET @this_value='Teleost fishes';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=207598;
SET @this_value='Hominines';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=311790;
SET @this_value='African mammals';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=314145;
SET @this_value='Laurasiatherian mammals';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=314146;
SET @this_value='Primates and Rodents';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=376911;
SET @this_value='Wet nose lemurs';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7711;
SET @this_value='Chordates';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9347;
SET @this_value='Placental mammals';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9362;
SET @this_value='Insectivore mammals';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9989;
SET @this_value='Rodents';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=31031;
SET @this_value='Puffers';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=32523;
SET @this_value='Tetrapods';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=32524;
SET @this_value='Amniotes';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=33554;
SET @this_value='Carnivores';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=40674;
SET @this_value='Mammals';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=117571;
SET @this_value='Bony vertebrates';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=314147;
SET @this_value='Rodents and Rabbits';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7718;
SET @this_value='Ciona sea squirts';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9443;
SET @this_value='Primates';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9526;
SET @this_value='Apes and Old World monkeys';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9604;
SET @this_value='Great apes';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9975;
SET @this_value='Rabbits and Pikas';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=32525;
SET @this_value='Marsupials and Placental mammals';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=33154;
SET @this_value='Animals and Fungi';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=33213;
SET @this_value='Bilateral animals';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=376913;
SET @this_value='Dry-nosed primates';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=91561;
SET @this_value='Cetaceans and Even-toed ungulates';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9397;
SET @this_value='Bats';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=8825;
SET @this_value='Birds';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=32561;
SET @this_value='Reptiles and birds';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9348;
SET @this_value='Xenarthran mammals';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9263;
SET @this_value='Marsupials';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=314293;
SET @this_value='Simians';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=379584;
SET @this_value='Caniforms';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=314295;
SET @this_value='Apes';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9005;
SET @this_value='Turkeys';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7742;
SET @this_value='Vertebrates';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=8287;
SET @this_value='Lobe-finned fish';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=1489913;
SET @this_value='Silverside fishes';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

-- <Added for rel.73>

SET @this_taxon_id=9126;
SET @this_value='Perching birds';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

-- </Added for rel.73>

-- <rel.74>

SET @this_taxon_id=186626;
SET @this_value='Teleost fishes';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9895;
SET @this_value='Bovids';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=41665;
SET @this_value='Ray-finned fishes';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=1329799;
SET @this_value='Birds and turtles';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

-- </rel.74>


-- <rel.75>

SET @this_taxon_id=1206794;
SET @this_value='Arthropods and nematodes';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

-- </rel.75>

-- <rel.76>

SET @this_taxon_id=9528;
SET @this_value='Old World monkeys';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=586240;
SET @this_value='Live-bearing aquarium fishes';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=123368;
SET @this_value='Teleost fishes';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=1489872;
SET @this_value='Teleost fishes';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=1489922;
SET @this_value='Teleost fishes';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=1489908;
SET @this_value='Teleost fishes';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

-- </rel.76>

-- <rel.79>

SET @this_taxon_id=1437010;
SET @this_value='Placental mammals';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=1549675;
SET @this_value='Fowls';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

-- </rel.79>

-- -- Use these to ADD new internal node aliases

-- SET @this_taxon_id=;
-- SET @this_value='';
-- SET @this_name_class='ensembl alias name';
-- insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;


-- Timetree divergence times for the GeneTree internal nodes
SET @this_taxon_id=1489913;
SET @this_value='100';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=33553;
SET @this_value='74.5';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=39107;
SET @this_value='25.4';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=186625;
SET @this_value='265.5';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=207598;
SET @this_value='8.8';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=311790;
SET @this_value='81.8';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=314145;
SET @this_value='91.7';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=314146;
SET @this_value='92.3';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=376911;
SET @this_value='57.9';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7711;
SET @this_value='722.5';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9347;
SET @this_value='104.2';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9362;
SET @this_value='65.9';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9989;
SET @this_value='77.9';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=31031;
SET @this_value='69.8';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=32523;
SET @this_value='371.2';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=32524;
SET @this_value='296.0';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=33554;
SET @this_value='55.1';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=40674;
SET @this_value='167.4';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=117571;
SET @this_value='441';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=314147;
SET @this_value='86.9';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7718;
SET @this_value='100';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9443;
SET @this_value='74.0';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9526;
SET @this_value='29.0';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9604;
SET @this_value='15.7';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9975;
SET @this_value='51.2';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=32525;
SET @this_value='162.6';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=33154;
SET @this_value='1215.8';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=33213;
SET @this_value='937.5';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

-- SET @this_taxon_id=33316;
-- SET @this_value='570';
-- SET @this_name_class='ensembl timetree mya';
-- insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=376913;
SET @this_value='65.2';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=91561;
SET @this_value='63.4';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9397;
SET @this_value='60.0';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=8825;
SET @this_value='104.2';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=32561;
SET @this_value='276.0';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9348;
SET @this_value='64.50';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9263;
SET @this_value='86.4';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=314293;
SET @this_value='42.6';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9005;
SET @this_value='44.6';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=314295;
SET @this_value='20.4';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7742;
SET @this_value='535.7';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=379584;
SET @this_value='45.0';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=8287;
SET @this_value='414.9';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

-- <Added for rel.73>

SET @this_taxon_id=9126;
SET @this_value='39.2';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

-- </Added for rel.73>

-- <rel.74>

SET @this_taxon_id=186626;
SET @this_value='152.9';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9895;
SET @this_value='30.1';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=41665;
SET @this_value='333.8';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=1329799;
SET @this_value='244.2';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

-- </rel.74>

-- <rel.75>

SET @this_taxon_id=1206794;
SET @this_value='936.5';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

-- </rel.75>

-- <rel.76>

SET @this_taxon_id=9528;
SET @this_value='11.1';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=1489922;
SET @this_value='124.9';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=1489872;
SET @this_value='125.0';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=1489908;
SET @this_value='103.8';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=123368;
SET @this_value='165.0';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

-- </rel.76>

-- <rel.79>

SET @this_taxon_id=1549675;
SET @this_value='81.2';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=586240;
SET @this_value='40';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=1437010;
SET @this_value='100';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

-- </rel.79>


-- Web display information
-- <rel.75>
SET @this_taxon_id=7898;
SET @this_value='fish';
SET @this_name_class='ensembl web display';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7898;
SET @this_value='lightblue1';
SET @this_name_class='genetree_bgcolour';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7898;
SET @this_value='royalblue4';
SET @this_name_class='genetree_fgcolour';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7898;
SET @this_value='default';
SET @this_name_class='genetree_display';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

--

SET @this_taxon_id=40674;
SET @this_value='mammals';
SET @this_name_class='ensembl web display';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=40674;
SET @this_value='d0fad0';
SET @this_name_class='genetree_bgcolour';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=40674;
SET @this_value='005000';
SET @this_name_class='genetree_fgcolour';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=40674;
SET @this_value='default';
SET @this_name_class='genetree_display';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

--

SET @this_taxon_id=7742;
SET @this_value='vertebrates';
SET @this_name_class='ensembl web display';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7742;
SET @this_value='ffe0f0';
SET @this_name_class='genetree_bgcolour';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7742;
SET @this_value='tomato3';
SET @this_name_class='genetree_fgcolour';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7742;
SET @this_value='default';
SET @this_name_class='genetree_display';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

--

SET @this_taxon_id=314147;
SET @this_value='glires';
SET @this_name_class='ensembl web display';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=314147;
SET @this_value='fff0e0';
SET @this_name_class='genetree_bgcolour';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=314147;
SET @this_value='403000';
SET @this_name_class='genetree_fgcolour';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=314147;
SET @this_value='default';
SET @this_name_class='genetree_display';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

--

SET @this_taxon_id=9443;
SET @this_value='primates';
SET @this_name_class='ensembl web display';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9443;
SET @this_value='f0f0ff';
SET @this_name_class='genetree_bgcolour';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9443;
SET @this_value='000050';
SET @this_name_class='genetree_fgcolour';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9443;
SET @this_value='default';
SET @this_name_class='genetree_display';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

--

SET @this_taxon_id=314145;
SET @this_value='laurasiatheria';
SET @this_name_class='ensembl web display';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=314145;
SET @this_value='d0fafa';
SET @this_name_class='genetree_bgcolour';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=314145;
SET @this_value='005050';
SET @this_name_class='genetree_fgcolour';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=314145;
SET @this_value='default';
SET @this_name_class='genetree_display';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

--

SET @this_taxon_id=8457;
SET @this_value='sauropsids';
SET @this_name_class='ensembl web display';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=8457;
SET @this_value='lemonchiffon';
SET @this_name_class='genetree_bgcolour';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=8457;
SET @this_value='yellow4';
SET @this_name_class='genetree_fgcolour';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=8457;
SET @this_value='default';
SET @this_name_class='genetree_display';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

-- </rel.75>


-- / Web display information

-- -- Use these to add new mya estimates
-- SET @this_taxon_id=;
-- SET @this_value='';
-- SET @this_name_class='ensembl timetree mya';
-- insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;


/*
The following query will show entries that are in ncbi_taxa_name but not in ncbi_taxa_node   
This can happen when nodes have been deprecated in the NCBI taxonomy database but haven't been removed from this file.
So if the query below displays any entry, you may need to remove the corresponding entry in ncbi_taxa_name, in this file
and make sure that your code doesn't rely on the deprecated taxon.
Sending a mail to the Ensembl or Ensembl Compara teams may also be a good idea.
*/
SELECT "ncbi_taxa_name entries that does not correspond with ncbi_taxa_nodes:" AS "";
SELECT "If something is listed below, remove the entry in ncbi_taxa_name, remove the corresponding entries in ensembl_aliases.sql and make sure your code does not rely on the deprecated node" AS "";
SELECT * FROM ncbi_taxa_name WHERE NOT EXISTS (SELECT NULL FROM ncbi_taxa_node WHERE ncbi_taxa_node.taxon_id = ncbi_taxa_name.taxon_id);
