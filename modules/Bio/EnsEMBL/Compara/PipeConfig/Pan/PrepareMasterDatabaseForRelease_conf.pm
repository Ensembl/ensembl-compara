=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Pan::PrepareMasterDatabaseForRelease_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Pan::PrepareMasterDatabaseForRelease_conf -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

Prepare Pan master database for next release. Please, refer to the parent
class for further information.

WARNING: the previous reports and backups will be removed if the pipeline is
initialised again for the same division and release.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Pan::PrepareMasterDatabaseForRelease_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

use base ('Bio::EnsEMBL::Compara::PipeConfig::PrepareMasterDatabaseForRelease_conf');

sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'division'               => 'pan',
        'additional_species'     => {
            'vertebrates' => [
                              'xenopus_tropicalis',
                              'pongo_abelii',
                              'pan_troglodytes',
                              'mus_musculus',
                              'monodelphis_domestica',
                              'homo_sapiens',
                              'gasterosteus_aculeatus',
                              'gallus_gallus',
                              'danio_rerio',
                              'ciona_savignyi',
                              'anolis_carolinensis'
                              ],
            'protist'     => [
                              'thecamonas_trahens_atcc_50062_gca_000142905',
                              'tetrahymena_thermophila',
                              'plasmodium_falciparum',
                              'phytophthora_infestans',
                              'phaeodactylum_tricornutum',
                              'monosiga_brevicollis_mx1_gca_000002865',
                              'leishmania_major',
                              'guillardia_theta',
                              'giardia_lamblia',
                              'emiliania_huxleyi',
                              'dictyostelium_discoideum',
                              'cryptomonas_paramecium_gca_000194455',
                              'bigelowiella_natans'
                              ],
            'plants'      => [
                              'vitis_vinifera',
                              'solanum_lycopersicum',
                              'selaginella_moellendorffii',
                              'physcomitrella_patens',
                              'oryza_sativa',
                              'marchantia_polymorpha',
                              'cyanidioschyzon_merolae',
                              'chlamydomonas_reinhardtii',
                              'brachypodium_distachyon',
                              'arabidopsis_thaliana',
                              'amborella_trichopoda'
                              ],
            'metazoa'     => [
                              'zootermopsis_nevadensis',
                              'trichoplax_adhaerens',
                              'tribolium_castaneum',
                              'tetranychus_urticae',
                              'strongylocentrotus_purpuratus',
                              'strigamia_maritima',
                              'stegodyphus_mimosarum',
                              'schistosoma_mansoni',
                              'pediculus_humanus',
                              'octopus_bimaculoides',
                              'nematostella_vectensis',
                              'mnemiopsis_leidyi',
                              'lottia_gigantea',
                              'lingula_anatina',
                              'helobdella_robusta',
                              'heliconius_melpomene',
                              'drosophila_melanogaster',
                              'daphnia_pulex',
                              'caenorhabditis_elegans',
                              'brugia_malayi',
                              'apis_mellifera',
                              'anopheles_gambiae',
                              'amphimedon_queenslandica',
                              'aedes_aegypti_lvpagwg'
                              ],
            'fungi'       => [
                              'zymoseptoria_tritici',
                              'ustilago_maydis',
                              'schizosaccharomyces_pombe',
                              'saccharomyces_cerevisiae',
                              'puccinia_graminis',
                              'neurospora_crassa',
                              'aspergillus_nidulans'
                              ],
            'bacteria'    => [
                              'yersinia_pestis_biovar_microtus_str_91001',
                              'xanthomonas_campestris_pv_campestris_str_atcc_33913',
                              'wolbachia_endosymbiont_of_drosophila_melanogaster',
                              'vibrio_fischeri_es114',
                              'vibrio_cholerae_o1_biovar_el_tor_str_n16961',
                              'ureaplasma_parvum_serovar_3_str_atcc_700970',
                              'treponema_pallidum_subsp_pallidum_str_nichols',
                              'thermus_thermophilus_hb8',
                              'thermotoga_maritima_msb8',
                              'thermosynechococcus_elongatus_bp_1',
                              'thermoplasma_acidophilum_dsm_1728',
                              'thermofilum_pendens_hrk_5',
                              'thermodesulfovibrio_yellowstonii_dsm_11347',
                              'thermococcus_kodakarensis_kod1',
                              'thermanaerovibrio_acidaminovorans_dsm_6589',
                              'synechocystis_sp_pcc_6803',
                              'sulfolobus_solfataricus_p2',
                              'streptomyces_coelicolor_a3_2_',
                              'streptococcus_pneumoniae_tigr4',
                              'stenotrophomonas_maltophilia_k279a',
                              'staphylococcus_aureus_subsp_aureus_n315',
                              'sinorhizobium_meliloti_1021',
                              'shigella_dysenteriae_sd197',
                              'shewanella_oneidensis_mr_1',
                              'salmonella_enterica_subsp_enterica_serovar_typhimurium_str_lt2',
                              'salinibacter_ruber_dsm_13855',
                              'rickettsia_prowazekii_str_madrid_e',
                              'rhodospirillum_rubrum_atcc_11170',
                              'rhodopirellula_baltica_sh_1',
                              'rhodobacter_sphaeroides_2_4_1',
                              'rhizobium_leguminosarum_bv_viciae_3841',
                              'ralstonia_solanacearum_gmi1000',
                              'pyrococcus_horikoshii_ot3',
                              'pyrobaculum_aerophilum_str_im2',
                              'pseudomonas_aeruginosa_mpao1_p2',
                              'proteus_mirabilis_hi4320',
                              'propionibacterium_acnes_kpa171202',
                              'prochlorococcus_marinus_subsp_marinus_str_ccmp1375',
                              'prevotella_intermedia_17',
                              'porphyromonas_gingivalis_w83',
                              'pasteurella_multocida_subsp_multocida_str_pm70',
                              'paracoccus_denitrificans_pd1222',
                              'nostoc_punctiforme_pcc_73102',
                              'nitrosopumilus_maritimus_scm1',
                              'neisseria_meningitidis_z2491',
                              'natronomonas_pharaonis_dsm_2160',
                              'nanoarchaeum_equitans_kin4_m',
                              'myxococcus_xanthus_dk_1622',
                              'mycoplasma_pneumoniae_m129',
                              'mycobacterium_tuberculosis_h37rv',
                              'moraxella_catarrhalis_7169',
                              'moorella_thermoacetica_atcc_39073',
                              'microcystis_aeruginosa_nies_843',
                              'micrococcus_luteus_nctc_2665',
                              'methanothermobacter_thermautotrophicus_str_delta_h',
                              'methanospirillum_hungatei_jf_1',
                              'methanosarcina_acetivorans_c2a',
                              'methanopyrus_kandleri_av19',
                              'methanococcus_maripaludis_s2',
                              'methanocaldococcus_jannaschii_dsm_2661',
                              'methanobrevibacter_smithii_atcc_35061',
                              'methanobacterium_formicicum_dsm_3637',
                              'mesoplasma_florum_l1',
                              'mannheimia_haemolytica_serotype_a2_str_ovine',
                              'lysinibacillus_sphaericus_c3_41',
                              'listeria_monocytogenes_egd_e',
                              'leuconostoc_mesenteroides_subsp_mesenteroides_atcc_8293',
                              'leptospira_interrogans_serovar_lai_str_56601',
                              'legionella_pneumophila_str_paris',
                              'lactococcus_lactis_subsp_lactis_il1403',
                              'lactobacillus_plantarum_wcfs1',
                              'klebsiella_pneumoniae_subsp_pneumoniae_mgh_78578',
                              'hyperthermus_butylicus_dsm_5456',
                              'helicobacter_pylori_26695',
                              'haloferax_volcanii_ds2',
                              'halobacterium_salinarum_r1',
                              'haloarcula_marismortui_atcc_43049',
                              'haemophilus_influenzae_rd_kw20',
                              'gloeobacter_violaceus_pcc_7421',
                              'geobacter_sulfurreducens_pca',
                              'gardnerella_vaginalis_0288e',
                              'fusobacterium_nucleatum_subsp_nucleatum_atcc_25586',
                              'francisella_tularensis_subsp_tularensis_schu_s4',
                              'flavobacterium_psychrophilum_jip02_86',
                              'escherichia_coli_str_k_12_substr_mg1655',
                              'enterococcus_faecalis_v583',
                              'enterobacter_cloacae_subsp_cloacae_atcc_13047',
                              'dictyoglomus_turgidum_dsm_6724',
                              'desulfovibrio_vulgaris_str_hildenborough',
                              'deinococcus_radiodurans_r1',
                              'coxiella_burnetii_rsa_493',
                              'corynebacterium_glutamicum_atcc_13032',
                              'clostridium_botulinum_a_str_hall',
                              'clostridioides_difficile_630',
                              'citrobacter_freundii_4_7_47cfaa',
                              'chloroflexus_aurantiacus_j_10_fl',
                              'chlorobium_tepidum_tls',
                              'chlamydia_trachomatis_d_uw_3_cx',
                              'cenarchaeum_symbiosum_a',
                              'caulobacter_crescentus_cb15',
                              'candidatus_koribacter_versatilis_ellin345',
                              'candidatus_korarchaeum_cryptofilum_opf8',
                              'campylobacter_jejuni_subsp_jejuni_nctc_11168_atcc_700819',
                              'burkholderia_pseudomallei_1710b',
                              'buchnera_aphidicola_str_aps_acyrthosiphon_pisum_',
                              'brucella_abortus_bv_1_str_9_941',
                              'bradyrhizobium_diazoefficiens_usda_110',
                              'borrelia_burgdorferi_b31',
                              'bordetella_pertussis_tohama_i',
                              'bifidobacterium_longum_ncc2705',
                              'bartonella_henselae_str_houston_1',
                              'bacteroides_thetaiotaomicron_vpi_5482',
                              'bacillus_subtilis_subsp_subtilis_str_168',
                              'azotobacter_vinelandii_dj',
                              'archaeoglobus_fulgidus_dsm_4304',
                              'aquifex_aeolicus_vf5',
                              'anaplasma_phagocytophilum_str_hz',
                              'agrobacterium_fabrum_str_c58',
                              'aggregatibacter_actinomycetemcomitans_d11s_1',
                              'aeropyrum_pernix_k1',
                              'aeromonas_hydrophila_subsp_hydrophila_atcc_7966',
                              'actinobacillus_pleuropneumoniae_serovar_5b_str_l20',
                              'acinetobacter_baumannii_aye'
                              ]
        },
    };
}

1;
