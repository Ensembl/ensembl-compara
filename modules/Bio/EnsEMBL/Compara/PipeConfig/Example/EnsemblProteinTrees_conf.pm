=heada LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

   http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

  Bio::EnsEMBL::Compara::PipeConfig::Example::EnsemblProteinTrees_conf

=head1 DESCRIPTION

    The PipeConfig file for ProteinTrees pipeline that should automate most of the pre-execution tasks.

=head2 rel.63 stats

    sequences to cluster:       1,198,678           [ SELECT count(*) from sequence; ]
    reused core dbs:            48                  [ SELECT count(*) FROM analysis JOIN job USING(analysis_id) WHERE logic_name='paf_table_reuse'; ]
    newly loaded core dbs:       5                  [ SELECT count(*) FROM analysis JOIN job USING(analysis_id) WHERE logic_name='load_fresh_members'; ]

    total running time:         8.7 days            [ SELECT (UNIX_TIMESTAMP(max(died))-UNIX_TIMESTAMP(min(born)))/3600/24 FROM worker;  ]  # NB: stable_id mapping phase not included
    blasting time:              1.9 days            [ SELECT (UNIX_TIMESTAMP(max(died))-UNIX_TIMESTAMP(min(born)))/3600/24 FROM worker JOIN analysis USING (analysis_id) WHERE logic_name='blastp_with_reuse'; ]

=head2 rel.62 stats

    sequences to cluster:       1,192,544           [ SELECT count(*) from sequence; ]
    reused core dbs:            46                  [ number of 'load_reuse_members' jobs ]
    newly loaded core dbs:       7                  [ number of 'load_fresh_members' jobs ]

    total running time:         6 days              [ SELECT (UNIX_TIMESTAMP(max(died))-UNIX_TIMESTAMP(min(born)))/3600/24 FROM hive;  ]
    blasting time:              2.7 days            [ SELECT (UNIX_TIMESTAMP(max(died))-UNIX_TIMESTAMP(min(born)))/3600/24 FROM hive JOIN analysis USING (analysis_id) WHERE logic_name='blastp_with_reuse'; ]

=head2 rel.61 stats

    sequences to cluster:       1,173,469           [ SELECT count(*) from sequence; ]
    reused core dbs:            46                  [ number of 'load_reuse_members' jobs ]
    newly loaded core dbs:       6                  [ number of 'load_fresh_members' jobs ]

    total running time:         6 days              [ SELECT (UNIX_TIMESTAMP(max(died))-UNIX_TIMESTAMP(min(born)))/3600/24 FROM hive;  ]
    blasting time:              1.4 days            [ SELECT (UNIX_TIMESTAMP(max(died))-UNIX_TIMESTAMP(min(born)))/3600/24 FROM hive JOIN analysis USING (analysis_id) WHERE logic_name like 'blast%' or logic_name like 'SubmitPep%'; ]

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author$

=head VERSION

$Revision$

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Example::EnsemblProteinTrees_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

    # parameters that are likely to change from execution to another:
#       'mlss_id'               => 40077,   # it is very important to check that this value is current (commented out to make it obligatory to specify)
        'release'               => $self->o('mlss_id'),
        'rel_suffix'            => '',    # an empty string by default, a letter otherwise
        'work_dir'              => '/lustre/scratch109/ensembl/'.$self->o('ENV', 'USER').'/ortho_benchmark_'.$self->o('rel_with_suffix'),

    # dependent parameters: updating 'work_dir' should be enough
        'rel_with_suffix'       => $self->o('release').$self->o('rel_suffix'),
        'pipeline_name'         => 'OB_'.$self->o('rel_with_suffix'),   # name the pipeline to differentiate the submitted processes

    # dump parameters:

    # blast parameters:

    # clustering parameters:
        'outgroups'                     => [
       4,24,44,64,84,104,124,144,164,184,204,224,244,264,284,304,324,344,364,384,404,424,444,464,484,504,524,544,564,584,604,624,644,664,684,704,724,744,764,784,804,824,844,864,884,904,924,944,964,984,1004,1024,1044,1064,1084,1104,1124,1144,1164,1184,1204,1224,1244,1264,1284,1304,1324,1344,1364,1384,1404,1424,1444,1464,1484,1504,1524,1544,1564,1584,1604,1624,1644,1664,1684,1704,1724,1744,1764,1784,1804,1824,1844,1864,1884,1904,1924,1944,1964,1984,2004,2024,2044,2064,2084,2104,2124,2144,2164,2184,2204,2224,2244,2264,2284,2304,2324,2344,2364,2384,2404,2424,2444,2464,2484,2504,2524,2544,2564,2584,2604,2624,2644,2664,2684,2704,2724,2744,2764,2784,2804,2824,2844,2864,2884,2904,2924,2944,2964,2984,3004,3024,3044,3064,3084,3104,3124,3144,3164,3184,3204,3224,3244,3264,3284,3304,3324,3344,3364,3384,3404,3424,3444,3464,3484,3504,3524,3544,3564,3584,3604,3624,3644,3664,3684,3704,3724,3744,3764,3784,3804,3824,3844,3864,3884,3904,3924,3944,3964,3984,4004,4024,4044,4064,4084,4104,4124,4144,4164,4184,4204,4224,4244,4264,4284,4304,4324,4344,4364,4384,4404,4424,4444,4464,4484,4504,4524,4544,4564,4584,4604,4624,4644,4664,4684,4704,4724,4744,4764,4784,4804,4824,4844,4864,4884,4904,4924,4944,4964,4984,5004,5024,5044,5064,5084,5104,5124,5144,5164,5184,5204,5224,5244,5264,5284,5304,5324,5344,5364,5384,5404,5424,5444,5464,5484,5504,5524,5544,5564,5584,5604,5624,5644,5664,5684,5704,5724,5744,5764,5784,5804,5824,5844,5864,5884,5904,5924,5944,5964,5984,6004,6024,6044,6064,6084,6104,6124,6144,6164,6184,6204,6224,6244,6264,6284,6304,6324,6344,6364,6384,6404,6424,6444,6464,6484,6504,6524,6544,6564,6584,6604,6624,6644,6664,6684,6704,6724,6744,6764,6784,6804,6824,6844,6864,6884,6904,6924,6944,6964,6984,7004,7024,7044,7064,7084,7104,7124,7144,7164,7184,7204,7224,7244,7264,7284,7304,7324,7344,7364,7384,7404,7424,7444,7464,7484,7504,7524,7544,7564,7584,7604,7624,7644,7664,7684,7704,7724,7744,7764,7784,7804,7824,7844,7864,7884,7904,7924,7944,7964,7984,8004,8024,8044,8064,8084
       ,
       1,21,41,61,81,101,121,141,161,181,201,221,241,261,281,301,321,341,361,381,401,421,441,461,481,501,521,541,561,581,601,621,641,661,681,701,721,741,761,781,801,821,841,861,881,901,921,941,961,981,1001,1021,1041,1061,1081,1101,1121,1141,1161,1181,1201,1221,1241,1261,1281,1301,1321,1341,1361,1381,1401,1421,1441,1461,1481,1501,1521,1541,1561,1581,1601,1621,1641,1661,1681,1701,1721,1741,1761,1781,1801,1821,1841,1861,1881,1901,1921,1941,1961,1981,2001,2021,2041,2061,2081,2101,2121,2141,2161,2181,2201,2221,2241,2261,2281,2301,2321,2341,2361,2381,2401,2421,2441,2461,2481,2501,2521,2541,2561,2581,2601,2621,2641,2661,2681,2701,2721,2741,2761,2781,2801,2821,2841,2861,2881,2901,2921,2941,2961,2981,3001,3021,3041,3061,3081,3101,3121,3141,3161,3181,3201,3221,3241,3261,3281,3301,3321,3341,3361,3381,3401,3421,3441,3461,3481,3501,3521,3541,3561,3581,3601,3621,3641,3661,3681,3701,3721,3741,3761,3781,3801,3821,3841,3861,3881,3901,3921,3941,3961,3981,4001,4021,4041,4061,4081,4101,4121,4141,4161,4181,4201,4221,4241,4261,4281,4301,4321,4341,4361,4381,4401,4421,4441,4461,4481,4501,4521,4541,4561,4581,4601,4621,4641,4661,4681,4701,4721,4741,4761,4781,4801,4821,4841,4861,4881,4901,4921,4941,4961,4981,5001,5021,5041,5061,5081,5101,5121,5141,5161,5181,5201,5221,5241,5261,5281,5301,5321,5341,5361,5381,5401,5421,5441,5461,5481,5501,5521,5541,5561,5581,5601,5621,5641,5661,5681,5701,5721,5741,5761,5781,5801,5821,5841,5861,5881,5901,5921,5941,5961,5981,6001,6021,6041,6061,6081,6101,6121,6141,6161,6181,6201,6221,6241,6261,6281,6301,6321,6341,6361,6381,6401,6421,6441,6461,6481,6501,6521,6541,6561,6581,6601,6621,6641,6661,6681,6701,6721,6741,6761,6781,6801,6821,6841,6861,6881,6901,6921,6941,6961,6981,7001,7021,7041,7061,7081,7101,7121,7141,7161,7181,7201,7221,7241,7261,7281,7301,7321,7341,7361,7381,7401,7421,7441,7461,7481,7501,7521,7541,7561,7581,7601,7621,7641,7661,7681,7701,7721,7741,7761,7781,7801,7821,7841,7861,7881,7901,7921,7941,7961,7981,8001,8021,8041,8061,8081
       ,
       8107,8137,8167,8197,8227,8257,8287,8317,8347,8377,8407,8437,8467,8497,8527,8557,8587,8617,8647,8677,8707,8737,8767,8797,8827,8857,8887,8917,8947,8977,9007,9037,9067,9097,9127,9157,9187,9217,9247,9277,9307,9337,9367,9397,9427,9457,9487,9517,9547,9577,9607,9637,9667,9697,9727,9757,9787,9817,9847,9877,9907,9937,9967,9997,10027,10057,10087,10117,10147,10177,10207,10237,10267,10297,10327,10357,10387,10417,10447,10477,10507,10537,10567,10597,10627,10657,10687,10717,10747,10777,10807,10837,10867,10897,10927,10957,10987,11017,11047,11077,11107,11137,11167,11197,11227,11257,11287,11317,11347,11377,11407,11437,11467,11497,11527,11557,11587,11617,11647,11677,11707,11737,11767,11797,11827,11857,11887,11917,11947,11977,12007,12037,12067,12097,12127,12157,12187,12217,12247,12277,12307,12337,12367,12397,12427,12457,12487,12517,12547,12577,12607,12637,12667,12697,12727,12757,12787,12817,12847,12877,12907,12937,12967,12997,13027,13057,13087,13117,13147,13177,13207,13237,13267,13297,13327,13357,13387,13417,13447,13477,13507,13537,13567,13597,13627,13657,13687,13717,13747,13777,13807,13837,13867,13897,13927,13957,13987,14017,14047,14077,14107,14137,14167,14197,14227,14257,14287,14317,14347,14377,14407,14437,14467,14497,14527,14557,14587,14617,14647,14677,14707,14737,14767,14797,14827,14857,14887,14917,14947,14977,15007,15037,15067,15097,15127,15157,15187,15217,15247,15277,15307,15337,15367,15397,15427,15457,15487,15517,15547,15577,15607,15637,15667,15697,15727,15757,15787,15817,15847,15877,15907,15937,15967,15997,16027,16057,16087,16117,16147,16177,16207,16237,16267,16297,16327,16357,16387,16417,16447,16477,16507,16537,16567,16597,16627,16657,16687,16717,16747,16777,16807,16837,16867,16897,16927,16957,16987,17017,17047,17077,17107,17137,17167,17197,17227,17257,17287,17317,17347,17377,17407,17437,17467,17497,17527,17557,17587,17617,17647,17677,17707,17737,17767,17797,17827,17857,17887,17917,17947,17977,18007,18037,18067,18097,18127,18157,18187,18217,18247,18277,18307,18337,18367,18397,18427,18457,18487,18517,18547,18577,18607,18637,18667,18697,18727,18757,18787,18817,18847,18877,18907,18937,18967,18997,19027,19057,19087,19117,19147,19177,19207,19237,19267,19297,19327,19357,19387,19417,19447,19477,19507,19537,19567,19597,19627,19657,19687,19717,19747,19777,19807,19837,19867,19897,19927,19957,19987,20017,20047,20077,20107,20137,20167,20197,20227
        ],   # affects 'hcluster_dump_input_per_genome'

    # tree building parameters:
    species_tree_input_file =>  '/nfs/users/nfs_m/mm14/workspace/ortho_bench/SpeciesTree.'.($self->o('mlss_id')).'.nwk',

    # homology_dnds parameters:
        'taxlevels'                 => [],
        'filter_high_coverage'      => 1,   # affects 'group_genomes_under_taxa'

    # executable locations:
        'wublastp_exe'              => '/usr/local/ensembl/bin/wublastp',
        'hcluster_exe'              => '/software/ensembl/compara/hcluster/hcluster_sg',
        'mcoffee_exe'               => '/software/ensembl/compara/tcoffee-7.86b/t_coffee',
        'mafft_exe'                 => '/software/ensembl/compara/mafft-6.707/bin/mafft',
        'mafft_binaries'            => '/software/ensembl/compara/mafft-6.707/binaries',
        'sreformat_exe'             => '/usr/local/ensembl/bin/sreformat',
        'treebest_exe'              => '/software/ensembl/compara/treebest.doubletracking',
        'quicktree_exe'             => '/software/ensembl/compara/quicktree_1.1/bin/quicktree',
        'buildhmm_exe'              => '/software/ensembl/compara/hmmer3/hmmer-3.0/src/hmmbuild',
        'codeml_exe'                => '/usr/local/ensembl/bin/codeml',
        'ktreedist_exe'             => '/software/ensembl/compara/ktreedist/Ktreedist.pl',

    # HMM specific parameters
        'hmm_clustering'            => 0, ## by default run blastp clustering
        'cm_file_or_directory'      => '/lustre/scratch109/sanger/fs9/treefam8_hmms',
        'hmm_library_basedir'       => '/lustre/scratch109/sanger/fs9/treefam8_hmms',
        #'cm_file_or_directory'      => '/lustre/scratch110/ensembl/mp12/panther_hmms/PANTHER7.2_ascii', ## Panther DB
        #'hmm_library_basedir'       => '/lustre/scratch110/ensembl/mp12/Panther_hmms',
        'blast_path'                => '/software/ensembl/compara/ncbi-blast-2.2.26+/bin/',
        'pantherScore_path'         => '/software/ensembl/compara/pantherScore1.03',
        'hmmer_path'                => '/software/ensembl/compara/hmmer-2.3.2/src/',

    # hive_capacity values for some analyses:
        'reuse_capacity'            =>   4,
        'blast_factory_capacity'    =>  50,
        'blastp_capacity'           => 900,
        'mcoffee_capacity'          => 600,
        'split_genes_capacity'      => 600,
        'njtree_phyml_capacity'     => 400,
        'ortho_tree_capacity'       => 200,
        'ortho_tree_annot_capacity' => 300,
        'quick_tree_break_capacity' => 100,
        'build_hmm_capacity'        => 200,
        'merge_supertrees_capacity' => 100,
        'other_paralogs_capacity'   => 100,
        'homology_dNdS_capacity'    => 200,
        'qc_capacity'               =>   4,
        'HMMer_classify_capacity'   => 100,

    # connection parameters to various databases:

        # Uncomment and update the database locations
        'pipeline_db' => {                      # the production database itself (will be created)
            -host   => 'compara4',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => $self->o('ENV', 'USER').'_ortho_benchmark_'.$self->o('rel_with_suffix'),
        },

        'master_db' => {                        # the master database for synchronization of various ids
            -host   => 'compara4',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            -dbname => 'mm14_ortho_benchmark_master',
        },

        'curr_core_sources_locs'    => [  ],
        'curr_file_sources_locs'    => [ '/nfs/users/nfs_m/mm14/workspace/ortho_bench/all.' . ($self->o('mlss_id')) . '.json'  ],    # It can be a list of JSON files defining an additionnal set of species

        'reuse_core_sources_locs'   => [ ],
        'reuse_db' => undef,

    };
}


sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class

         '250Mb_job'    => {'LSF' => '-C0 -M250000   -R"select[mem>250]   rusage[mem=250]"' },
         '500Mb_job'    => {'LSF' => '-C0 -M500000   -R"select[mem>500]   rusage[mem=500]"' },
         '1Gb_job'      => {'LSF' => '-C0 -M1000000  -R"select[mem>1000]  rusage[mem=1000]"' },
         '2Gb_job'      => {'LSF' => '-C0 -M2000000  -R"select[mem>2000]  rusage[mem=2000]"' },
         '8Gb_job'      => {'LSF' => '-C0 -M8000000  -R"select[mem>8000]  rusage[mem=8000]"' },

         'msa'          => {'LSF' => '-C0 -M2000000  -R"select[mem>2000]  rusage[mem=2000]"' },
         'msa_himem'    => {'LSF' => '-C0 -M8000000  -R"select[mem>8000]  rusage[mem=8000]"' },

         'urgent_hcluster'   => {'LSF' => '-C0 -M32000000 -R"select[mem>32000] rusage[mem=32000]" -q yesterday' },
    };
}

1;

