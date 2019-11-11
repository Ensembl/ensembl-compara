=pod

=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::EBI::Vertebrates::StrainsOrthologQM_Alignment_conf;

=head1 SYNOPSIS

 init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::Vertebrates::StrainsOrthologQM_Alignment_conf $(mysql-ens-compara-prod-6-ensadmin details hive) -member_type ncrna -collection murinae

=head1 DESCRIPTION

See the parent class Bio::EnsEMBL::Compara::PipeConfig::EBI::Vertebrates::OrthologQM_Alignment_conf

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::Vertebrates::StrainsOrthologQM_Alignment_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::EBI::Vertebrates::OrthologQM_Alignment_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'division'      => 'vertebrates',

        # 'member_type'   => undef, # should be 'protein' or 'ncrna'
        # 'collection'    => undef, # should be 'murinae' or 'sus'

        'master_db'  => 'compara_master',

        # location of homology data. note: wga_score will be written here
        'compara_db' => '#expr( (#member_type# eq "protein") ? "sus_ptrees" : "sus_nctrees" )expr#',,
        # if alignments are not all present in compara_db, define alternative db locations
        'alt_aln_dbs' => [
            # list of databases with EPO or LASTZ data
            'compara_curr',
        ],
        'previous_rel_db'  => 'compara_prev',
        'species_set_name' => 'collection-' . $self->o('collection'),
    };
}

1;
