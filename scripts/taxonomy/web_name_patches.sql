-- This file might need to be edited before importing NCBI taxonomy into ncbi_taxonomy@ens-livemirror:

update ncbi_taxa_name set name = 'Canis familiaris'         where taxon_id = 9615  and name_class = 'scientific name'   and name = 'Canis lupus familiaris';
update ncbi_taxa_name set name = 'Canis lupus familiaris'   where taxon_id = 9615  and name_class = 'synonym'           and name = 'Canis familiaris';
update ncbi_taxa_name set name = 'Vicugna pacos'            where taxon_id = 30538 and name_class = 'scientific name'   and name = 'Lama pacos';
update ncbi_taxa_name set name = 'Lama pacos'               where taxon_id = 30538 and name_class = 'synonym'           and name = 'Vicugna pacos';
update ncbi_taxa_name set name = 'Vicugna'                  where taxon_id=9839                                         and name ='Lama';

update ncbi_taxa_name set name = 'Xenopus tropicalis'       where taxon_id = 8364  and name_class = 'scientific name'   and name = 'Xenopus (Silurana) tropicalis';
update ncbi_taxa_name set name = 'Xenopus (Silurana) tropicalis' where taxon_id = 8364 and name_class = 'synonym'       and name = 'Xenopus tropicalis';

-- change this internal node name as requested by Dr. Brandon Menzies:

update ncbi_taxa_name set name = 'Marsupialia'              where taxon_id = 9263  and name_class = 'scientific name'   and name = 'Metatheria';
update ncbi_taxa_name set name = 'Metatheria'               where taxon_id = 9263  and name_class = 'synonym'           and name = 'Marsupialia';

