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
                              'ornithorhynchus_anatinus',
                              'mus_musculus',
                              'monodelphis_domestica',
                              'homo_sapiens',
                              'gasterosteus_aculeatus',
                              'gallus_gallus',
                              'danio_rerio',
                              'ciona_savignyi',
                              'anolis_carolinensis'
                              ],
            'protists'     => [
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
                              'yersinia_pestis_biovar_microtus_str_91001_GCA_000007885',
                              'xanthomonas_campestris_pv_campestris_str_atcc_33913_GCA_000007145',
                              'wolbachia_endosymbiont_of_drosophila_melanogaster_GCA_000008025',
                              'vibrio_cholerae_o1_biovar_el_tor_str_n16961_GCA_000006745',
                              'ureaplasma_parvum_serovar_3_str_atcc_700970_GCA_000006625',
                              'treponema_pallidum_subsp_pallidum_str_nichols_GCA_000008605',
                              'thermus_thermophilus_hb8_GCA_000091545',
                              'thermotoga_maritima_msb8_GCA_000008545',
                              'thermosynechococcus_elongatus_bp_1_GCA_000011345',
                              'thermoplasma_acidophilum_dsm_1728_GCA_000195915',
                              'thermofilum_pendens_hrk_5_GCA_000015225',
                              'thermodesulfovibrio_yellowstonii_dsm_11347_GCA_000020985',
                              'thermococcus_kodakarensis_kod1_GCA_000009965',
                              'thermanaerovibrio_acidaminovorans_dsm_6589_GCA_000024905',
                              'synechocystis_sp_pcc_6803_GCA_000009725',
                              'streptococcus_pneumoniae_tigr4_GCA_000006885',
                              'stenotrophomonas_maltophilia_k279a_GCA_000072485',
                              'staphylococcus_aureus_subsp_aureus_n315_GCA_000009645',
                              'sinorhizobium_meliloti_1021_GCA_000006965',
                              'shigella_dysenteriae_sd197_GCA_000012005',
                              'salinibacter_ruber_dsm_13855_GCA_000013045',
                              'saccharolobus_solfataricus_p2_GCA_000007005',
                              'rickettsia_prowazekii_str_madrid_e_GCA_000195735',
                              'rhodospirillum_rubrum_atcc_11170_GCA_000013085',
                              'rhodopirellula_baltica_sh_1_GCA_000196115',
                              'rhodobacter_sphaeroides_2_4_1_GCA_000012905',
                              'rhizobium_leguminosarum_bv_viciae_3841_GCA_000009265',
                              'ralstonia_solanacearum_gmi1000_GCA_000009125',
                              'pyrococcus_horikoshii_ot3_GCA_000011105',
                              'pyrobaculum_aerophilum_str_im2_GCA_000007225',
                              'proteus_mirabilis_hi4320_GCA_000069965',
                              'prochlorococcus_marinus_subsp_marinus_str_ccmp1375_GCA_000007925',
                              'porphyromonas_gingivalis_w83_GCA_000007585',
                              'pasteurella_multocida_subsp_multocida_str_pm70_GCA_000006825',
                              'paracoccus_denitrificans_pd1222_GCA_000203895',
                              'nostoc_punctiforme_pcc_73102_GCA_000020025',
                              'nitrosopumilus_maritimus_scm1_GCA_000018465',
                              'neisseria_meningitidis_z2491_GCA_000009105',
                              'natronomonas_pharaonis_dsm_2160_GCA_000026045',
                              'nanoarchaeum_equitans_kin4_m_GCA_000008085',
                              'myxococcus_xanthus_dk_1622_GCA_000012685',
                              'mycoplasma_pneumoniae_m129_GCA_000027345',
                              'moorella_thermoacetica_atcc_39073_GCA_000013105',
                              'microcystis_aeruginosa_nies_843_GCA_000010625',
                              'micrococcus_luteus_nctc_2665_GCA_000023205',
                              'methanothermobacter_thermautotrophicus_str_delta_h_GCA_000008645',
                              'methanospirillum_hungatei_jf_1_GCA_000013445',
                              'methanosarcina_acetivorans_c2a_GCA_000007345',
                              'methanopyrus_kandleri_av19_GCA_000007185',
                              'methanococcus_maripaludis_s2_GCA_000011585',
                              'methanocaldococcus_jannaschii_dsm_2661_GCA_000091665',
                              'methanobrevibacter_smithii_atcc_35061_GCA_000016525',
                              'mesoplasma_florum_l1_GCA_000008305',
                              'lysinibacillus_sphaericus_c3_41_GCA_000017965',
                              'listeria_monocytogenes_egd_e_GCA_000196035',
                              'leuconostoc_mesenteroides_subsp_mesenteroides_atcc_8293_GCA_000014445',
                              'leptospira_interrogans_serovar_lai_str_56601_GCA_000092565',
                              'lactococcus_lactis_subsp_lactis_il1403_GCA_000006865',
                              'lactobacillus_plantarum_wcfs1_GCA_000203855',
                              'klebsiella_pneumoniae_subsp_pneumoniae_mgh_78578_GCA_000016305',
                              'hyperthermus_butylicus_dsm_5456_GCA_000015145',
                              'helicobacter_pylori_26695_GCA_000008525',
                              'haloferax_volcanii_ds2_GCA_000025685',
                              'halobacterium_salinarum_r1_GCA_000069025',
                              'haloarcula_marismortui_atcc_43049_GCA_000011085',
                              'haemophilus_influenzae_rd_kw20_GCA_000027305',
                              'gloeobacter_violaceus_pcc_7421_GCA_000011385',
                              'geobacter_sulfurreducens_pca_GCA_000007985',
                              'gardnerella_vaginalis_0288e_GCA_000263555',
                              'fusobacterium_nucleatum_subsp_nucleatum_atcc_25586_GCA_000007325',
                              'francisella_tularensis_subsp_tularensis_schu_s4_GCA_000008985',
                              'flavobacterium_psychrophilum_jip02_86_GCA_000064305',
                              'escherichia_coli_str_k_12_substr_mg1655_GCA_000005845',
                              'enterococcus_faecalis_v583_GCA_000007785',
                              'enterobacter_cloacae_subsp_cloacae_atcc_13047_GCA_000025565',
                              'dictyoglomus_turgidum_dsm_6724_GCA_000021645',
                              'desulfovibrio_vulgaris_str_hildenborough_GCA_000195755',
                              'deinococcus_radiodurans_r1_GCA_000008565',
                              'cutibacterium_acnes_kpa171202_GCA_000008345',
                              'coxiella_burnetii_rsa_493_GCA_000007765',
                              'clostridioides_difficile_630_GCA_000009205',
                              'chloroflexus_aurantiacus_j_10_fl_GCA_000018865',
                              'chlorobaculum_tepidum_tls_GCA_000006985',
                              'chlamydia_trachomatis_d_uw_3_cx_GCA_000008725',
                              'cenarchaeum_symbiosum_a_GCA_000200715',
                              'caulobacter_vibrioides_cb15_GCA_000006905',
                              'candidatus_koribacter_versatilis_ellin345_GCA_000014005',
                              'candidatus_korarchaeum_cryptofilum_opf8_GCA_000019605',
                              'campylobacter_jejuni_subsp_jejuni_nctc_11168_atcc_700819_GCA_000009085',
                              'burkholderia_pseudomallei_1710b_GCA_000012785',
                              'buchnera_aphidicola_str_aps_acyrthosiphon_pisum__GCA_000009605',
                              'brucella_abortus_bv_1_str_9_941_GCA_000008145',
                              'bradyrhizobium_diazoefficiens_usda_110_GCA_000011365',
                              'borreliella_burgdorferi_b31_GCA_000008685',
                              'bifidobacterium_longum_ncc2705_GCA_000007525',
                              'bartonella_henselae_str_houston_1_GCA_000046705',
                              'bacteroides_thetaiotaomicron_vpi_5482_GCA_000011065',
                              'bacillus_subtilis_subsp_subtilis_str_168_GCA_000009045',
                              'azotobacter_vinelandii_dj_GCA_000021045',
                              'archaeoglobus_fulgidus_dsm_4304_GCA_000008665',
                              'aquifex_aeolicus_vf5_GCA_000008625',
                              'anaplasma_phagocytophilum_str_hz_GCA_000013125',
                              'aliivibrio_fischeri_es114_GCA_000011805',
                              'agrobacterium_fabrum_str_c58_GCA_000092025',
                              'aeropyrum_pernix_k1_GCA_000011125',
                              'aeromonas_hydrophila_subsp_hydrophila_atcc_7966_GCA_000014805',
                              'actinobacillus_pleuropneumoniae_serovar_5b_str_l20_GCA_000015885',
                              'acinetobacter_baumannii_aye_GCA_000069245'
                              ]
        },
    };
}

1;
