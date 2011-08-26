-- This file might need to be edited before importing NCBI taxonomy into ncbi_taxonomy@ens-livemirror:

UPDATE ncbi_taxa_name SET name = 'Canis familiaris'         WHERE taxon_id = 9615   AND name_class = 'scientific name'  AND name = 'Canis lupus familiaris';
UPDATE ncbi_taxa_name SET name = 'Canis lupus familiaris'   WHERE taxon_id = 9615   AND name_class = 'synonym'          AND name = 'Canis familiaris';
UPDATE ncbi_taxa_name SET name = 'Vicugna pacos'            WHERE taxon_id = 30538  AND name_class = 'scientific name'  AND name = 'Lama pacos';
UPDATE ncbi_taxa_name SET name = 'Lama pacos'               WHERE taxon_id = 30538  AND name_class = 'synonym'          AND name = 'Vicugna pacos';
UPDATE ncbi_taxa_name SET name = 'Vicugna'                  WHERE taxon_id=9839                                         AND name ='Lama';

UPDATE ncbi_taxa_name SET name = 'Xenopus tropicalis'       WHERE taxon_id = 8364   AND name_class = 'scientific name'  AND name = 'Xenopus (Silurana) tropicalis';
UPDATE ncbi_taxa_name SET name = 'Xenopus (Silurana) tropicalis' WHERE taxon_id = 8364 AND name_class = 'synonym'       AND name = 'Xenopus tropicalis';

-- change this internal node name as requested by Dr. Brandon Menzies:

UPDATE ncbi_taxa_name SET name = 'Marsupialia'              WHERE taxon_id = 9263   AND name_class = 'scientific name'  AND name = 'Metatheria';
UPDATE ncbi_taxa_name SET name = 'Metatheria'               WHERE taxon_id = 9263   AND name_class = 'synonym'          AND name = 'Marsupialia';

-- these species were renamed by WormBase:

UPDATE ncbi_taxa_name SET name = 'Caenorhabditis angaria'   WHERE taxon_id = 96668  AND name_class = 'scientific name';
UPDATE ncbi_taxa_name SET name = 'Caenorhabditis csp11'     WHERE taxon_id = 886184 AND name_class = 'scientific name';

