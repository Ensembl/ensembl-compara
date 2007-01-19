/mysqld/current/bin/mysql -S /mysqld/ecs3d_3307/ecs3d_3307.sock -uensro homo_sapiens_variation_42_36d -e 'select variation_id,source_id,name from variation order by variation_id' > hsv.txt
/mysqld/current/bin/mysql -S /mysqld/ecs3d_3307/ecs3d_3307.sock -uensro homo_sapiens_variation_42_36d -e 'select variation_id,source_id,name from variation_synonym order by variation_id' > hsvs.txt
/mysqld/current/bin/mysql -S /mysqld/ecs3d_3307/ecs3d_3307.sock -uensro mus_musculus_variation_42_36c -e 'select variation_id,source_id,name from variation order by variation_id' > msv.txt
/mysqld/current/bin/mysql -S /mysqld/ecs3d_3307/ecs3d_3307.sock -uensro mus_musculus_variation_42_36c -e 'select variation_id,source_id,name from variation_synonym order by variation_id' > msvs.txt
