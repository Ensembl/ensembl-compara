select count(*), description from homology group by description;

select count(*) cnt, h.description, mlss.name from homology h, method_link_species_set mlss where h.method_link_species_set_id=mlss.method_link_species_set_id and mlss.method_link_species_set_id in (select method_link_species_set_id from method_link_species_set where name like '%sap%') group by h.description, mlss.name order by h.description, cnt, mlss.name;

SELECT m1.genome_db_id, m2.genome_db_id, gdb1.name, gdb2.name
,h.description, count(*)
,AVG(hm1.perc_cov), AVG(hm1.perc_id), AVG(hm1.perc_pos),AVG(hm2.perc_cov), AVG(hm2.perc_id), AVG(hm2.perc_pos)
FROM homology h, homology_member hm1, homology_member hm2, member m1, member m2, genome_db gdb1, genome_db gdb2
WHERE h.homology_id=hm1.homology_id AND hm1.member_id=m1.member_id
AND h.homology_id=hm2.homology_id AND hm2.member_id=m2.member_id
AND m1.genome_db_id != m2.genome_db_id
AND m1.genome_db_id < m2.genome_db_id
AND m1.genome_db_id=gdb1.genome_db_id
AND m2.genome_db_id=gdb2.genome_db_id
GROUP BY m1.genome_db_id, m2.genome_db_id, h.description;
