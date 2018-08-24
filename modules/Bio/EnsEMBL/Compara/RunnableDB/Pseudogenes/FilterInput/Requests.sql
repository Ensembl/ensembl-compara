## Gets the gene tree root foreach pseudogene

SELECT SUBSTRING(all_roots, 1, IF(LOCATE(',' , all_roots) > 0, LOCATE(',' , all_roots) - 1, LENGTH(all_roots))) AS root_id, GROUP_CONCAT(pseudogene_id) AS pseudogene_id
FROM
(
SELECT pseudogene_id, GROUP_CONCAT(tree_id ORDER BY evalue SEPARATOR ', ') AS all_roots, COUNT(*)
FROM pseudogenes_data 
WHERE pseudogene_id IS NOT NULL AND status = "OK"  AND tree_id IS NOT NULL
GROUP BY pseudogene_id 
) AS T
GROUP BY root_id;



SELECT pseudogene_id, tree_id, evalue FROM pseudogenes_data WHERE status = "OK" AND pseudogene_id in
(
SELECT psueudogene_id
FROM pseudogenes_data 
WHERE pseudogene_id in (SELECT pseudogene_id FROM pseudogenes_data WHERE tree_id = 366314 AND status = "OK") AND status = "OK" 
GROUP BY pseudogene_id HAVING COUNT(*) > 1
) ORDER by pseudogene_id

## Merges tree
UPDATE pseudogenes_data d1 JOIN pseudogenes_data d2 ON (d1.parent_id = d2.pseudogene_id)
SET d1.root_id = d2.root_id;

SELECT d2.tree_id, d1.tree_id, d2.parent As ancestor, d2.pseudogenes_id, d1.pseudogenes_id FROM pseudogenes_data d1 JOIN pseudogenes_data d2 ON (d1.parent_id = d2.pseudogene_id) 
WHERE d1.pseudogene_id IS NOT NULL AND d1.status = "OK" AND d2.status = "OK";


UPDATE pseudogenes_data d1 JOIN pseudogenes_data d2 ON (d1.parent_id = d2.pseudogene_id) 
SET d1.tree_id = d2.tree_id, d1.evalue = d2.evalue
WHERE d1.pseudogene_id IS NOT NULL AND d1.status = "OK" AND d2.status = "OK";
