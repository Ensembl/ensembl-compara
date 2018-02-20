=pod

=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME
	
	Bio::EnsEMBL::Compara::PipeConfig::EBI::OrthologQM_Alignment_conf;

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::OrthologQM_Alignment_conf

    To run on a species_set_name:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::OrthologQM_Alignment_conf -species_set_name <species_set_name>
        or
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::OrthologQM_Alignment_conf -species_set_id <species_set dbID>

    To run on a pair of species:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::OrthologQM_Alignment_conf -species1 homo_sapiens -species2 gallus_gallus

=head1 DESCRIPTION

    This pipeline uses whole genome alignments to calculate the coverage of homologous pairs.
    The coverage is calculated on both exonic and intronic regions seperately and summarised using a quality_score calculation
    The average quality_score between both members of the homology will be written to the homology table (in compara_db option)

    http://www.ebi.ac.uk/seqdb/confluence/display/EnsCom/Quality+metrics+for+the+orthologs

    Additional options:
    -compara_db         database containing relevant data (this is where final scores will be written)
    -alt_aln_db         take alignment objects from a different source
    -alt_homology_db    take homology objects from a different source
    -previous_rel_db    reuse scores from a previous release (requires a homology_id_mapping table in compara_db)

    Note: If you wish to use homologies from one database, but the alignments live in a different database,
    remember that final scores will be written to the homology table of the appointed compara_db. So, if you'd 
    like the final scores written to the homology database, assign this as compara_db and use the alt_aln_db option 
    to specify the location of the alignments. Likewise, if you want the scores written to the alignment-containing
    database, assign it as compara_db and use the alt_homology_db option.

    Examples:
    ---------
    # scores go to homology db, alignments come from afar
    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::OrthologQM_Alignment_conf -compara_db mysql://user:pass@host/homologies
        -alt_aln_db mysql://ro_user@hosty_mchostface/alignments

    # scores go to alignment db
    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::OrthologQM_Alignment_conf -compara_db mysql://user:pass@host/alignments
        -alt_homology_db mysql://ro_user@hostess_with_the_mostest/homologies


    # standard production run:
    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::OrthologQM_Alignment_conf -compara_db <current protein tree db> -alt_aln_db 
        <previous release database (unless new alignments were run)> -previous_rel_db <previous release database> 
        -species_set_name "collection-default"
    
    (note: compara_db is supplied here in the pipeconfig, so may not be needed at init step)

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::OrthologQM_Alignment_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

# use base ( 'Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf' );
use base ('Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_Alignment_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        #update me!!
        # 'current_release' => 89,
        'current_release' => $ENV{CURR_ENSEMBL_RELEASE},

        'host'       => "mysql-ens-compara-prod-3.ebi.ac.uk",
        'port'       => 4523,
        'master_db'  => "mysql://ensro\@mysql-ens-compara-prod-1.ebi.ac.uk:4485/ensembl_compara_master",

        # location of homology data. note: wga_score will be written here
        'compara_db' => "mysql://ensadmin:$ENV{ENSADMIN_PSW}\@mysql-ens-compara-prod-1.ebi.ac.uk:4485/ensembl_compara_" . $self->o('current_release'),
        # if alignments are not all present in compara_db, define alternative db locations
        'alt_aln_db' => [
            $self->o('previous_rel_db'),
            # list of databases with EPO or LASTZ data
        ],
        'previous_rel_db'  => 'mysql://ensadmin:$ENV{ENSADMIN_PSW}\@mysql-ens-compara-prod-1.ebi.ac.uk:4485/ensembl_compara_#expr( #current_release# - 1 )expr#',
        'species_set_name' => 'collection-default',
    };
}

1;
