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

# patch_94_95_c.sql
#
# Title: New column in genome_db: is_good_for_alignment
#
# Description:
#   Introduces a new column in genome_db: is_good_for_alignment
#   "is_good_for_alignment" is a boolean that is true if the assembly is suitable for EPO/PECAN high coverage alignments
#   Both are normally automatically populated from the core database

ALTER TABLE genome_db
	ADD COLUMN is_good_for_alignment TINYINT(1) NOT NULL DEFAULT 0 AFTER has_karyotype;

ALTER TABLE genome_db
DROP COLUMN is_high_coverage;

UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "acanthochromis_polyacanthus" AND assembly = "ASM210954v1";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "ailuropoda_melanoleuca" AND assembly = "ailMel1";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "amphilophus_citrinellus" AND assembly = "Midas_v5";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "amphiprion_ocellaris" AND assembly = "AmpOce1.0";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "amphiprion_percula" AND assembly = "Nemo_v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "anabas_testudineus" AND assembly = "fAnaTes1.1";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "anas_platyrhynchos" AND assembly = "BGI_duck_1.0";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "anolis_carolinensis" AND assembly = "AnoCar2.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "aotus_nancymaae" AND assembly = "Anan_2.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "astatotilapia_burtoni" AND assembly = "AstBur1.0";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "astatotilapia_calliptera" AND assembly = "fAstCal1.2";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "astyanax_mexicanus" AND assembly = "Astyanax_mexicanus-2.0";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "bos_taurus" AND assembly = "ARS-UCD1.2";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "caenorhabditis_elegans" AND assembly = "WBcel235";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "callithrix_jacchus" AND assembly = "ASM275486v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "canis_familiaris" AND assembly = "CanFam3.1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "canis_lupus_dingo" AND assembly = "ASM325472v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "capra_hircus" AND assembly = "ARS1";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "carlito_syrichta" AND assembly = "Tarsius_syrichta-2.0.1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "cavia_aperea" AND assembly = "CavAp1.0";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "cavia_porcellus" AND assembly = "Cavpor3.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "cebus_capucinus" AND assembly = "Cebus_imitator-1.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "cercocebus_atys" AND assembly = "Caty_1.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "chinchilla_lanigera" AND assembly = "ChiLan1.0";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "chlorocebus_sabaeus" AND assembly = "ChlSab1.1";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "choloepus_hoffmanni" AND assembly = "choHof1";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "chrysemys_picta_bellii" AND assembly = "Chrysemys_picta_bellii-3.0.3";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "ciona_intestinalis" AND assembly = "KH";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "ciona_savignyi" AND assembly = "CSAV2.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "colobus_angolensis_palliatus" AND assembly = "Cang.pa_1.0";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "cricetulus_griseus_chok1gshd" AND assembly = "CHOK1GS_HDv1";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "cricetulus_griseus_crigri" AND assembly = "CriGri_1.0";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "cynoglossus_semilaevis" AND assembly = "Cse_v1.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "cyprinodon_variegatus" AND assembly = "C_variegatus-1.0";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "danio_rerio" AND assembly = "GRCz11";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "dasypus_novemcinctus" AND assembly = "Dasnov3.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "dipodomys_ordii" AND assembly = "Dord_2.0";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "drosophila_melanogaster" AND assembly = "BDGP6";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "echinops_telfairi" AND assembly = "TENREC";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "eptatretus_burgeri" AND assembly = "Eburgeri_3.2";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "equus_asinus_asinus" AND assembly = "ASM303372v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "equus_caballus" AND assembly = "EquCab3.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "erinaceus_europaeus" AND assembly = "HEDGEHOG";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "esox_lucius" AND assembly = "Eluc_V3";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "felis_catus" AND assembly = "Felis_catus_9.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "ficedula_albicollis" AND assembly = "FicAlb_1.4";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "fukomys_damarensis" AND assembly = "DMR_v1.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "fundulus_heteroclitus" AND assembly = "Fundulus_heteroclitus-3.0.2";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "gadus_morhua" AND assembly = "gadMor1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "gallus_gallus" AND assembly = "Gallus_gallus-5.0";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "gambusia_affinis" AND assembly = "ASM309773v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "gasterosteus_aculeatus" AND assembly = "BROADS1";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "gopherus_agassizii" AND assembly = "ASM289641v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "gorilla_gorilla" AND assembly = "gorGor4";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "haplochromis_burtoni" AND assembly = "AstBur1.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "heterocephalus_glaber_female" AND assembly = "HetGla_female_1.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "heterocephalus_glaber_male" AND assembly = "HetGla_1.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "hippocampus_comes" AND assembly = "H_comes_QL1_v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "homo_sapiens" AND assembly = "GRCh38";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "ictalurus_punctatus" AND assembly = "IpCoco_1.2";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "ictidomys_tridecemlineatus" AND assembly = "SpeTri2.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "jaculus_jaculus" AND assembly = "JacJac1.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "kryptolebias_marmoratus" AND assembly = "ASM164957v1";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "labrus_bergylta" AND assembly = "BallGen_V1";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "latimeria_chalumnae" AND assembly = "LatCha1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "lepisosteus_oculatus" AND assembly = "LepOcu1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "loxodonta_africana" AND assembly = "loxAfr3";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "macaca_fascicularis" AND assembly = "Macaca_fascicularis_5.0";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "macaca_mulatta" AND assembly = "Mmul_8.0.1";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "macaca_nemestrina" AND assembly = "Mnem_1.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "mandrillus_leucophaeus" AND assembly = "Mleu.le_1.0";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "mastacembelus_armatus" AND assembly = "fMasArm1.1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "maylandia_zebra" AND assembly = "M_zebra_UMD2a";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "meleagris_gallopavo" AND assembly = "UMD2";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "mesocricetus_auratus" AND assembly = "MesAur1.0";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "microcebus_murinus" AND assembly = "Mmur_3.0";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "microtus_ochrogaster" AND assembly = "MicOch1.0";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "mola_mola" AND assembly = "ASM169857v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "monodelphis_domestica" AND assembly = "monDom5";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "monopterus_albus" AND assembly = "M_albus_1.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "mustela_putorius_furo" AND assembly = "MusPutFur1.0";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "mus_caroli" AND assembly = "CAROLI_EIJ_v1.1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "mus_musculus" AND assembly = "GRCm38";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "mus_musculus_129s1svimj" AND assembly = "129S1_SvImJ_v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "mus_musculus_aj" AND assembly = "A_J_v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "mus_musculus_akrj" AND assembly = "AKR_J_v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "mus_musculus_balbcj" AND assembly = "BALB_cJ_v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "mus_musculus_c3hhej" AND assembly = "C3H_HeJ_v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "mus_musculus_c57bl6nj" AND assembly = "C57BL_6NJ_v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "mus_musculus_casteij" AND assembly = "CAST_EiJ_v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "mus_musculus_cbaj" AND assembly = "CBA_J_v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "mus_musculus_dba2j" AND assembly = "DBA_2J_v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "mus_musculus_fvbnj" AND assembly = "FVB_NJ_v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "mus_musculus_lpj" AND assembly = "LP_J_v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "mus_musculus_nodshiltj" AND assembly = "NOD_ShiLtJ_v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "mus_musculus_nzohlltj" AND assembly = "NZO_HlLtJ_v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "mus_musculus_pwkphj" AND assembly = "PWK_PhJ_v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "mus_musculus_wsbeij" AND assembly = "WSB_EiJ_v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "mus_pahari" AND assembly = "PAHARI_EIJ_v1.1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "mus_spretus" AND assembly = "SPRET_EiJ_v1";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "myotis_lucifugus" AND assembly = "Myoluc2.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "nannospalax_galili" AND assembly = "S.galili_v1.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "neolamprologus_brichardi" AND assembly = "NeoBri1.0";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "nomascus_leucogenys" AND assembly = "Nleu_3.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "notamacropus_eugenii" AND assembly = "Meug_1.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "ochotona_princeps" AND assembly = "OchPri2.0-Ens";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "octodon_degus" AND assembly = "OctDeg1.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "oreochromis_niloticus" AND assembly = "Orenil1.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "ornithorhynchus_anatinus" AND assembly = "OANA5";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "oryctolagus_cuniculus" AND assembly = "OryCun2.0";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "oryzias_latipes" AND assembly = "ASM223467v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "oryzias_latipes_hni" AND assembly = "ASM223471v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "oryzias_latipes_hsok" AND assembly = "ASM223469v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "oryzias_melastigma" AND assembly = "Om_v0.7.RACA";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "otolemur_garnettii" AND assembly = "OtoGar3";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "ovis_aries" AND assembly = "Oar_v3.1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "panthera_pardus" AND assembly = "PanPar1.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "panthera_tigris_altaica" AND assembly = "PanTig1.0";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "pan_paniscus" AND assembly = "panpan1.1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "pan_troglodytes" AND assembly = "Pan_tro_3.0";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "papio_anubis" AND assembly = "Panu_3.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "paramormyrops_kingsleyae" AND assembly = "PKINGS_0.1";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "pelodiscus_sinensis" AND assembly = "PelSin_1.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "periophthalmus_magnuspinnatus" AND assembly = "PM.fa";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "peromyscus_maniculatus_bairdii" AND assembly = "Pman_1.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "petromyzon_marinus" AND assembly = "Pmarinus_7.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "phascolarctos_cinereus" AND assembly = "phaCin_tgac_v2.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "poecilia_formosa" AND assembly = "PoeFor_5.1.2";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "poecilia_latipinna" AND assembly = "P_latipinna-1.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "poecilia_mexicana" AND assembly = "P_mexicana-1.0";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "poecilia_reticulata" AND assembly = "Guppy_female_1.0_MT";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "pongo_abelii" AND assembly = "PPYG2";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "procavia_capensis" AND assembly = "proCap1";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "propithecus_coquereli" AND assembly = "Pcoq_1.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "pteropus_vampyrus" AND assembly = "pteVam1";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "pundamilia_nyererei" AND assembly = "PunNye1.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "pygocentrus_nattereri" AND assembly = "Pygocentrus_nattereri-1.0.2";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "rattus_norvegicus" AND assembly = "Rnor_6.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "rhinopithecus_bieti" AND assembly = "ASM169854v1";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "rhinopithecus_roxellana" AND assembly = "Rrox_v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "saccharomyces_cerevisiae" AND assembly = "R64-1-1";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "saimiri_boliviensis_boliviensis" AND assembly = "SaiBol1.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "sarcophilus_harrisii" AND assembly = "DEVIL7.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "scleropages_formosus" AND assembly = "ASM162426v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "scophthalmus_maximus" AND assembly = "ASM318616v1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "seriola_dumerili" AND assembly = "Sdu_1.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "seriola_lalandi_dorsalis" AND assembly = "Sedor1";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "sorex_araneus" AND assembly = "COMMON_SHREW1";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "stegastes_partitus" AND assembly = "Stegastes_partitus-1.0.2";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "sus_scrofa" AND assembly = "Sscrofa11.1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "taeniopygia_guttata" AND assembly = "taeGut3.2.4";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "takifugu_rubripes" AND assembly = "FUGU5";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "tetraodon_nigroviridis" AND assembly = "TETRAODON8";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "tupaia_belangeri" AND assembly = "TREESHREW";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "tursiops_truncatus" AND assembly = "turTru1";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "ursus_americanus" AND assembly = "ASM334442v1";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "ursus_maritimus" AND assembly = "UrsMar_1.0";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "vicugna_pacos" AND assembly = "vicPac1";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "vulpes_vulpes" AND assembly = "VulVul2.2";
UPDATE genome_db SET is_good_for_alignment = 0 WHERE name = "xenopus_tropicalis" AND assembly = "JGI_4.2";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "xiphophorus_couchianus" AND assembly = "Xiphophorus_couchianus-4.0.1";
UPDATE genome_db SET is_good_for_alignment = 1 WHERE name = "xiphophorus_maculatus" AND assembly = "X_maculatus-5.0-male";

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_94_95_c.sql|genome_db_is_good_for_alignment');
