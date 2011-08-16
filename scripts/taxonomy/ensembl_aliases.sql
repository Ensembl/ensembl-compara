--  set the "ensembl alias name" and "ensembl common name" for each species used in Ensembl
--  this values are also uploaded in the meta table of each core db and then used by
--  the web code for display.

--  Search for 'ADD' below to copy+paste the empty template

SET @this_taxon_id=9601;
SET @this_value='Orangutan';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9601;
SET @this_value='orangutan';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=10116;
SET @this_value='Rat';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=10116;
SET @this_value='Norway rat';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=31033;
SET @this_value='Fugu';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=31033;
SET @this_value='torafugu';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7165;
SET @this_value='Anopheles';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7165;
SET @this_value='African malaria mosquito';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=6239;
SET @this_value='C.elegans';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=6239;
SET @this_value='nematode';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9031;
SET @this_value='Chicken';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9031;
SET @this_value='chicken';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=99883;
SET @this_value='Tetraodon';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=99883;
SET @this_value='Fresh water pufferfish';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9913;
SET @this_value='Cow';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9913;
SET @this_value='cattle';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=8364;
SET @this_value='X.tropicalis';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=8364;
SET @this_value='western clawed frog';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=4932;
SET @this_value='Saccharomyces cerevisiae';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=4932;
SET @this_value="baker's yeast";
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7719;
SET @this_value='C.intestinalis';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7719;
SET @this_value='Sea squirt Ciona intestinalis';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9606;
SET @this_value='Human';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9606;
SET @this_value='human';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7227;
SET @this_value='Fruitfly';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7227;
SET @this_value='fruit fly';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=10090;
SET @this_value='Mouse';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=10090;
SET @this_value='house mouse';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7955;
SET @this_value='Zebrafish';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7955;
SET @this_value='zebrafish';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=51511;
SET @this_value='C.savignyi';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=51511;
SET @this_value='Sea squirt Ciona savignyi';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=13616;
SET @this_value='Opossum';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=13616;
SET @this_value='gray short-tailed opossum';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7159;
SET @this_value='Aedes';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7159;
SET @this_value='yellow fever mosquito';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9544;
SET @this_value='Macaque';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9544;
SET @this_value='rhesus monkey';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9785;
SET @this_value='Elephant';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9785;
SET @this_value='African savanna elephant';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9371;
SET @this_value='Lesser hedgehog tenrec';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9371;
SET @this_value='small Madagascar hedgehog';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9986;
SET @this_value='Rabbit';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9986;
SET @this_value='rabbit';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9361;
SET @this_value='Armadillo';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9361;
SET @this_value='nine-banded armadillo';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=69293;
SET @this_value='Stickleback';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=69293;
SET @this_value='three spined stickleback';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=8090;
SET @this_value='Medaka';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=8090;
SET @this_value='Japanese medaka';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9598;
SET @this_value='Chimpanzee';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9598;
SET @this_value='chimpanzee';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9615;
SET @this_value='Dog';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9615;
SET @this_value='dog';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9258;
SET @this_value='Platypus';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9258;
SET @this_value='platypus';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9685;
SET @this_value='Cat';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9685;
SET @this_value='cat';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9796;
SET @this_value='Horse';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9796;
SET @this_value='horse';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9593;
SET @this_value='Gorilla';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9593;
SET @this_value='gorilla';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;
-- 2X genomes
SET @this_taxon_id=42254;
SET @this_value='Shrew';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=42254;
SET @this_value='European shrew';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=30611;
SET @this_value='Bushbaby';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=30611;
SET @this_value='small-eared galago';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=59463;
SET @this_value='Microbat';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=59463;
SET @this_value='little brown bat';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9365;
SET @this_value='Hedgehog';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9365;
SET @this_value='western European hedgehog';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=10141;
SET @this_value='Guinea Pig';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=10141;
SET @this_value='domestic guinea pig';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=43179;
SET @this_value='Squirrel';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=43179;
SET @this_value='thirteen-lined ground squirrel';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=37347;
SET @this_value='Tree Shrew';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=37347;
SET @this_value='northern tree shrew';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=30608;
SET @this_value='Mouse Lemur';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=30608;
SET @this_value='grey mouse lemur';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9978;
SET @this_value='Pika';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9978;
SET @this_value='American pika';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9739;
SET @this_value='Dolphin';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9739;
SET @this_value='Bottlenose dolphin';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9478;
SET @this_value='Tarsier';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9478;
SET @this_value='Philippine tarsier';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=10020;
SET @this_value='Kangaroo rat';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=10020;
SET @this_value='Ords kangaroo rat';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=30538;
SET @this_value='Alpaca';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=30538;
SET @this_value='alpaca';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=132908;
SET @this_value='Megabat';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=132908;
SET @this_value='Large flying fox';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9813;
SET @this_value='Hyrax';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9813;
SET @this_value='cape rock hyrax';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=59729;
SET @this_value='Zebra Finch';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=59729;
SET @this_value='Zebra Finch';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9358;
SET @this_value='Sloth';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9358;
SET @this_value='Two-toed sloth';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=28377;
SET @this_value='Anole Lizard';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=28377;
SET @this_value='Green anole Lizard';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9315;
SET @this_value='Wallaby';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9315;
SET @this_value='Tammar Wallaby';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9823;
SET @this_value='Pig';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9823;
SET @this_value='pig';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9483;
SET @this_value='Marmoset';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9483;
SET @this_value='marmoset';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9557;
SET @this_value='Hamadryas baboon';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9557;
SET @this_value='hamadryas baboon';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=8049;
SET @this_value='Atlantic cod';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=8049;
SET @this_value='Cod';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9103;
SET @this_value='Turkey';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9103;
SET @this_value='common turkey';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9646;
SET @this_value='Panda';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9646;
SET @this_value='giant panda';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=61853;
SET @this_value='Gibbon';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=61853;
SET @this_value='Northern white-cheeked gibbon';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7757;
SET @this_value='Lamprey';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7757;
SET @this_value='Sea lamprey';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;


SET @this_taxon_id=9305;
SET @this_value='Tasmanian devil';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9305;
SET @this_value='tasmanian devil';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;


SET @this_taxon_id=8128;
SET @this_value='Tilapia';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=8128;
SET @this_value='Nile tilapia';
SET @this_name_class='ensembl common name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;


-- -- Use these to ADD new species

-- SET @this_taxon_id=;
-- SET @this_value='';
-- SET @this_name_class='ensembl alias name';
-- insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

-- SET @this_taxon_id=;
-- SET @this_value='';
-- SET @this_name_class='ensembl common name';
-- insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;


-- Internal nodes for the GeneTrees
SET @this_taxon_id=33553;
SET @this_value='Mouse/Rat/Squirrel ancestor';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=39107;
SET @this_value='Old World rodents';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=129949;
SET @this_value='Smegmamorph fish';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=186625;
SET @this_value='Bony fish';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=207598;
SET @this_value='Human/Chimp/Gorilla ancestor';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=311790;
SET @this_value='African mammals';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=314145;
SET @this_value='Carnivore/Insectivore/Ungulate mammalian ancestor';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=314146;
SET @this_value='Primates/Rodents ancestor';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=376911;
SET @this_value='Wet nose lemurs';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7147;
SET @this_value='Flies';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7157;
SET @this_value='Mosquitos';
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
SET @this_value='puffers';
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
SET @this_value='Rodents and rabbits';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7718;
SET @this_value='Ciona ancestor';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9443;
SET @this_value='Primates';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9526;
SET @this_value='Apes and old world monkeys';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9604;
SET @this_value='Human/Chimp/Orang ancestor';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9975;
SET @this_value='Rabbit/Pika ancestor';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=32485;
SET @this_value='Bony fish, not zebrafish';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=32525;
SET @this_value='Marsupial/Mammal';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=33154;
SET @this_value='Fungi/Metazoa ancestor';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=33213;
SET @this_value='Bilateral animals';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=33316;
SET @this_value='Coelomate animals';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=376913;
SET @this_value='Human/Chimp/Orang/Macaque/Tarsier ancestor';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=91561;
SET @this_value='Cow/Alpaca/Dolphin ancestor';
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
SET @this_value='Reptiles';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9348;
SET @this_value='Sloth/Anteater/Armadillo ancestor';
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
SET @this_value='Dog/Giant Panda ancestor';
SET @this_name_class='ensembl alias name';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

-- -- Use these to ADD new internal node aliases

-- SET @this_taxon_id=;
-- SET @this_value='';
-- SET @this_name_class='ensembl alias name';
-- insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;


-- Timetree divergence times for the GeneTree internal nodes
SET @this_taxon_id=33553;
SET @this_value='78.91';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=39107;
SET @this_value='36.95';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=129949;
SET @this_value='180';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=186625;
SET @this_value='320';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=207598;
SET @this_value='8.78';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=311790;
SET @this_value='93.95';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=314145;
SET @this_value='87.98';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=314146;
SET @this_value='106.69';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=376911;
SET @this_value='69.22';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7711;
SET @this_value='550';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9347;
SET @this_value='102.41';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9362;
SET @this_value='67.92';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9989;
SET @this_value='81.05';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=31031;
SET @this_value='65';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=32523;
SET @this_value='358.99';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=32524;
SET @this_value='325.75';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=33554;
SET @this_value='56.34';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=40674;
SET @this_value='183.61';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=117571;
SET @this_value='420';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=314147;
SET @this_value='81.16';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=7718;
SET @this_value='100';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9443;
SET @this_value='82.95';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9526;
SET @this_value='30.96';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9604;
SET @this_value='16.24';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9975;
SET @this_value='48.42';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=32485;
SET @this_value='190';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=32525;
SET @this_value='165.83';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=33154;
SET @this_value='1500';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=33213;
SET @this_value='580';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=33316;
SET @this_value='570';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=376913;
SET @this_value='56.70';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=91561;
SET @this_value='61.33';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9397;
SET @this_value='60.22';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=8825;
SET @this_value='105.00';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=32561;
SET @this_value='267.03';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9348;
SET @this_value='64.50';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9263;
SET @this_value='148';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=314293;
SET @this_value='45.16';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9528;
SET @this_value='13.64';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

SET @this_taxon_id=9005;
SET @this_value='47.29';
SET @this_name_class='ensembl timetree mya';
insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;


-- -- Use these to add new mya estimates
-- SET @this_taxon_id=;
-- SET @this_value='';
-- SET @this_name_class='ensembl timetree mya';
-- insert into ncbi_taxa_name select @this_taxon_id,@this_value,@this_name_class from ncbi_taxa_name WHERE taxon_id=@this_taxon_id and name_class=@this_name_class having count(*)=0;

