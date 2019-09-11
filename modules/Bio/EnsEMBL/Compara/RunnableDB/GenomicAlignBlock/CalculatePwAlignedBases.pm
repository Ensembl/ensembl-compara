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

=cut


=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::Calculate_pw_aligned_bases

=head1 DESCRIPTION


=cut

package Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::CalculatePwAlignedBases;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Utils::Cigars;
use Bio::EnsEMBL::Compara::Utils::Preloader;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
#    	'genomic_align_block_id'           => '11320000002048',
#    	'compara_db' 					   => 'mysql://ensro@mysql-ens-compara-prod-1.ebi.ac.uk:4485/ensembl_compara_92',
    }
}

sub fetch_input {
    my $self = shift @_;
    my $GAB = $self->compara_dba->get_GenomicAlignBlockAdaptor->fetch_by_dbID($self->param_required('genomic_align_block_id'));
    $self->param('genomic_aligns', $GAB->genomic_align_array()) or die "Could not fetch genomic_aligns object with genomic_align_block object='$GAB->dbID'";
    my %genomic_aligns_hash;

    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_DnaFrags($self->compara_dba->get_DnaFragAdaptor, $self->param('genomic_aligns'));
    #create an hash where the key is the genome db id of the genomic align object and the value is an array of all the genomic aligns belonging to that genome
    foreach my $ga (@{$self->param('genomic_aligns')}) {
        unless (exists ($genomic_aligns_hash{$ga->dnafrag->genome_db_id})) {
            $genomic_aligns_hash{$ga->dnafrag->genome_db_id} = [];
        }
        push @{$genomic_aligns_hash{$ga->dnafrag->genome_db_id}}, $ga;
    }

    $self->param('genomic_aligns_hash', \%genomic_aligns_hash);
#    print $_->dbID," \n" foreach (@{$self->param('genomic_aligns')}) if ( $self->debug >3 );
    $self->param('dataflow_output_ids', []);
}


sub run {
    my $self = shift @_;
    $self->disconnect_from_databases;
    my @gdbs = keys %{$self->param('genomic_aligns_hash')};
    print "\n we are now in RUN of CalculatePwAlignedBases\n" ;
    for (my $pos = 0; $pos<scalar @gdbs; $pos++) {
        for (my $inner_pos = $pos+1; $inner_pos < scalar @gdbs; $inner_pos++){
            $self->_calculate_coverage($gdbs[$pos], $gdbs[$inner_pos]);
            $self->_calculate_coverage($gdbs[$inner_pos], $gdbs[$pos]);
        }
    }
}

sub write_output {
    my $self = shift @_;
    $self->dataflow_output_id( $self->param('dataflow_output_ids'), 2);
}


sub _calculate_coverage {
    my ($self,$gid1, $gid2) = @_;
    print "\n we are now in _calculate_coverage $gid1 VS $gid2  \n";

    foreach my $ga1 (@{$self->param('genomic_aligns_hash')->{$gid1}}) { #usind foreach loop because there can be more than one genomic align 
        print " \n ref start ", $ga1->dnafrag_start, " ref end " , $ga1->dnafrag_end, "  = ", ($ga1->dnafrag_end-$ga1->dnafrag_start), " \n\n" if ( $self->debug >3 );
        #now we do the calculation of the aligned position. between the souce genomic align and the duplication genomic. A match for a single position can only be recorded once even if that position is matched in multiple duplicated genomic aligns
        my $aligned_base_positions = 0;
        my $cb = sub {
            my $pos     = shift;
            my $codes   = shift;
            my $length  = shift;
            if (($codes->[0] eq 'M') && (scalar(grep {$_ eq 'M'} @$codes) >= 2)) {
                $aligned_base_positions += $length;
            }
        };
        my @cls = ($ga1->cigar_line, map {$_->cigar_line} @{$self->param('genomic_aligns_hash')->{$gid2}});
        Bio::EnsEMBL::Compara::Utils::Cigars::column_iterator(\@cls, $cb, 'group');
        print "\nthis is currently aligned_base_positions : $aligned_base_positions  \n\n" if ( $self->debug >3 );
        push @{$self->param('dataflow_output_ids')}, { 'frm_genome_db_id' => $gid1, 'to_genome_db_id' => $gid2, 'no_of_aligned_bases' => $aligned_base_positions};
    }   
}


1;
