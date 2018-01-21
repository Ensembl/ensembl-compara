-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2018] EMBL-European Bioinformatics Institute
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

SET @this_taxon_id=7718;
SET @this_value='Ciona sea squirts';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9526;
SET @this_value='Apes and Old World monkeys';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9975;
SET @this_value='Rabbits, Hares and Pikas';
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

SET @this_taxon_id=314293;
SET @this_value='Simians';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=379584;
SET @this_value='Caniforms';
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
