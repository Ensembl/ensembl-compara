-- This file might need to be edited before importing NCBI taxonomy into ncbi_taxonomy@ens-livemirror:

UPDATE ncbi_taxa_name SET name = 'Xenopus tropicalis'       WHERE taxon_id = 8364   AND name_class = 'scientific name'  AND name = 'Xenopus (Silurana) tropicalis';
UPDATE ncbi_taxa_name SET name = 'Xenopus (Silurana) tropicalis' WHERE taxon_id = 8364 AND name_class = 'synonym'       AND name = 'Xenopus tropicalis';

-- change this internal node name as requested by Dr. Brandon Menzies:

UPDATE ncbi_taxa_name SET name = 'Marsupialia'              WHERE taxon_id = 9263   AND name_class = 'scientific name'  AND name = 'Metatheria';
UPDATE ncbi_taxa_name SET name = 'Metatheria'               WHERE taxon_id = 9263   AND name_class = 'synonym'          AND name = 'Marsupialia';

-- these species were renamed by WormBase:

UPDATE ncbi_taxa_name SET name = 'Caenorhabditis csp11'     WHERE taxon_id = 886184 AND name_class = 'scientific name';

