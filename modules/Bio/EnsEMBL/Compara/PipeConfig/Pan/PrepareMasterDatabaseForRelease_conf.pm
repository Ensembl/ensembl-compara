=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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
                              'physcomitrium_patens',
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
                              'octopus_bimaculoides_gca001194135v1',
                              'nematostella_vectensis',
                              'mnemiopsis_leidyi',
                              'lottia_gigantea',
                              'lingula_anatina_gca001039355v2',
                              'helobdella_robusta',
                              'heliconius_melpomene',
                              'drosophila_melanogaster',
                              'daphnia_pulex_gca021134715v1rs',
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
                              'yersinia_pestis_biovar_microtus_str_91001_gca_000007885',
                              'xanthomonas_campestris_pv_campestris_str_atcc_33913_gca_000007145',
                              'wolbachia_endosymbiont_of_drosophila_melanogaster_gca_000008025',
                              'vibrio_cholerae_o1_biovar_el_tor_str_n16961_gca_000006745',
                              'ureaplasma_parvum_serovar_3_str_atcc_700970_gca_000006625',
                              'treponema_pallidum_subsp_pallidum_str_nichols_gca_000008605',
                              'thermus_thermophilus_hb8_gca_000091545',
                              'thermotoga_maritima_msb8_gca_000008545',
                              'thermosynechococcus_elongatus_bp_1_gca_000011345',
                              'thermoplasma_acidophilum_dsm_1728_gca_000195915',
                              'thermofilum_pendens_hrk_5_gca_000015225',
                              'thermodesulfovibrio_yellowstonii_dsm_11347_gca_000020985',
                              'thermococcus_kodakarensis_kod1_gca_000009965',
                              'thermanaerovibrio_acidaminovorans_dsm_6589_gca_000024905',
                              'synechocystis_sp_pcc_6803_gca_000009725',
                              'streptococcus_pneumoniae_tigr4_gca_000006885',
                              'stenotrophomonas_maltophilia_k279a_gca_000072485',
                              'staphylococcus_aureus_subsp_aureus_n315_gca_000009645',
                              'sinorhizobium_meliloti_1021_gca_000006965',
                              'shigella_dysenteriae_sd197_gca_000012005',
                              'salinibacter_ruber_dsm_13855_gca_000013045',
                              'saccharolobus_solfataricus_p2_gca_000007005',
                              'rickettsia_prowazekii_str_madrid_e_gca_000195735',
                              'rhodospirillum_rubrum_atcc_11170_gca_000013085',
                              'rhodopirellula_baltica_sh_1_gca_000196115',
                              'rhodobacter_sphaeroides_2_4_1_gca_000012905',
                              'rhizobium_leguminosarum_bv_viciae_3841_gca_000009265',
                              'ralstonia_solanacearum_gmi1000_gca_000009125',
                              'pyrococcus_horikoshii_ot3_gca_000011105',
                              'pyrobaculum_aerophilum_str_im2_gca_000007225',
                              'proteus_mirabilis_hi4320_gca_000069965',
                              'prochlorococcus_marinus_subsp_marinus_str_ccmp1375_gca_000007925',
                              'porphyromonas_gingivalis_w83_gca_000007585',
                              'pasteurella_multocida_subsp_multocida_str_pm70_gca_000006825',
                              'paracoccus_denitrificans_pd1222_gca_000203895',
                              'nostoc_punctiforme_pcc_73102_gca_000020025',
                              'nitrosopumilus_maritimus_scm1_gca_000018465',
                              'neisseria_meningitidis_z2491_gca_000009105',
                              'natronomonas_pharaonis_dsm_2160_gca_000026045',
                              'nanoarchaeum_equitans_kin4_m_gca_000008085',
                              'myxococcus_xanthus_dk_1622_gca_000012685',
                              'mycoplasma_pneumoniae_m129_gca_000027345',
                              'moorella_thermoacetica_atcc_39073_gca_000013105',
                              'microcystis_aeruginosa_nies_843_gca_000010625',
                              'micrococcus_luteus_nctc_2665_gca_000023205',
                              'methanothermobacter_thermautotrophicus_str_delta_h_gca_000008645',
                              'methanospirillum_hungatei_jf_1_gca_000013445',
                              'methanosarcina_acetivorans_c2a_gca_000007345',
                              'methanopyrus_kandleri_av19_gca_000007185',
                              'methanococcus_maripaludis_s2_gca_000011585',
                              'methanocaldococcus_jannaschii_dsm_2661_gca_000091665',
                              'methanobrevibacter_smithii_atcc_35061_gca_000016525',
                              'mesoplasma_florum_l1_gca_000008305',
                              'lysinibacillus_sphaericus_c3_41_gca_000017965',
                              'listeria_monocytogenes_egd_e_gca_000196035',
                              'leuconostoc_mesenteroides_subsp_mesenteroides_atcc_8293_gca_000014445',
                              'leptospira_interrogans_serovar_lai_str_56601_gca_000092565',
                              'lactococcus_lactis_subsp_lactis_il1403_gca_000006865',
                              'lactobacillus_plantarum_wcfs1_gca_000203855',
                              'klebsiella_pneumoniae_subsp_pneumoniae_mgh_78578_gca_000016305',
                              'hyperthermus_butylicus_dsm_5456_gca_000015145',
                              'helicobacter_pylori_26695_gca_000008525',
                              'haloferax_volcanii_ds2_gca_000025685',
                              'halobacterium_salinarum_r1_gca_000069025',
                              'haloarcula_marismortui_atcc_43049_gca_000011085',
                              'haemophilus_influenzae_rd_kw20_gca_000027305',
                              'gloeobacter_violaceus_pcc_7421_gca_000011385',
                              'geobacter_sulfurreducens_pca_gca_000007985',
                              'gardnerella_vaginalis_0288e_gca_000263555',
                              'fusobacterium_nucleatum_subsp_nucleatum_atcc_25586_gca_000007325',
                              'francisella_tularensis_subsp_tularensis_schu_s4_gca_000008985',
                              'flavobacterium_psychrophilum_jip02_86_gca_000064305',
                              'escherichia_coli_str_k_12_substr_mg1655_gca_000005845',
                              'enterococcus_faecalis_v583_gca_000007785',
                              'enterobacter_cloacae_subsp_cloacae_atcc_13047_gca_000025565',
                              'dictyoglomus_turgidum_dsm_6724_gca_000021645',
                              'desulfovibrio_vulgaris_str_hildenborough_gca_000195755',
                              'deinococcus_radiodurans_r1_gca_000008565',
                              'cutibacterium_acnes_kpa171202_gca_000008345',
                              'coxiella_burnetii_rsa_493_gca_000007765',
                              'clostridioides_difficile_630_gca_000009205',
                              'chloroflexus_aurantiacus_j_10_fl_gca_000018865',
                              'chlorobaculum_tepidum_tls_gca_000006985',
                              'chlamydia_trachomatis_d_uw_3_cx_gca_000008725',
                              'cenarchaeum_symbiosum_a_gca_000200715',
                              'caulobacter_vibrioides_cb15_gca_000006905',
                              'candidatus_koribacter_versatilis_ellin345_gca_000014005',
                              'candidatus_korarchaeum_cryptofilum_opf8_gca_000019605',
                              'campylobacter_jejuni_subsp_jejuni_nctc_11168_atcc_700819_gca_000009085',
                              'burkholderia_pseudomallei_1710b_gca_000012785',
                              'buchnera_aphidicola_str_aps_acyrthosiphon_pisum__gca_000009605',
                              'brucella_abortus_bv_1_str_9_941_gca_000008145',
                              'bradyrhizobium_diazoefficiens_usda_110_gca_000011365',
                              'borreliella_burgdorferi_b31_gca_000008685',
                              'bifidobacterium_longum_ncc2705_gca_000007525',
                              'bartonella_henselae_str_houston_1_gca_000046705',
                              'bacteroides_thetaiotaomicron_vpi_5482_gca_000011065',
                              'bacillus_subtilis_subsp_subtilis_str_168_gca_000009045',
                              'azotobacter_vinelandii_dj_gca_000021045',
                              'archaeoglobus_fulgidus_dsm_4304_gca_000008665',
                              'aquifex_aeolicus_vf5_gca_000008625',
                              'anaplasma_phagocytophilum_str_hz_gca_000013125',
                              'aliivibrio_fischeri_es114_gca_000011805',
                              'agrobacterium_fabrum_str_c58_gca_000092025',
                              'aeropyrum_pernix_k1_gca_000011125',
                              'aeromonas_hydrophila_subsp_hydrophila_atcc_7966_gca_000014805',
                              'actinobacillus_pleuropneumoniae_serovar_5b_str_l20_gca_000015885',
                              'acinetobacter_baumannii_aye_gca_000069245'
                              ]
        },
    };
}

1;
