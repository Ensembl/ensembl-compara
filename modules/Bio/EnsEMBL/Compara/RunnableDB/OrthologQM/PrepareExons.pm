=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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
    
    Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareExons

=head1 SYNOPSIS

	Find and format the start/end positions for the exons for each member of a given homology_id

=head1 DESCRIPTION

    Input(s):
    orth_id         homology dbID
    orth_ranges     formatted hash of start/end positions of homologs (just for passthrough)
    orth_dnafrags   list of dnafrags included in homologs (just for passthrough)

    Outputs:
    hash combining all given ortholog info + exon boundaries

=cut


package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareExons;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Bio::EnsEMBL::Registry;

sub fetch_input {
    my $self = shift;

    # my $orth_id    = $self->param_required( 'orth_id' );
    # $self->param( 'orth_exons', $self->_fetch_exons( $orth_id ) ) unless ( $self->param( 'orth_exons' ) );

    my $gdb_id = $self->param_required( 'genome_db_id' );
    my $gdb_adaptor = $self->compara_dba->get_GenomeDBAdaptor;
    my $gdb = $gdb_adaptor->fetch_by_dbID( $gdb_id );

    my $gene_member_adaptor = $self->compara_dba->get_GeneMemberAdaptor;
    my $gene_members = $gene_member_adaptor->fetch_all_by_GenomeDB($gdb);

    my @exons;
    my $c = 0;
    foreach my $gm ( @{ $gene_members } ) {
        push( @exons, $self->get_exons_for_gene_member($gm) );
        # $c++;
        # last if ( $c >= 100 );
    }
    $gdb->db_adaptor->dbc->disconnect_if_idle();
    $self->param('exons', \@exons);
}

sub write_output {
    my $self = shift;

    $self->dataflow_output_id( $self->param('exons'), 1 );
}

sub get_exons_for_gene_member {
    my ( $self, $gm ) = @_;

    my $seqmems = $gm->get_all_SeqMembers;
    my ($transcript, @exons);
    foreach my $sm ( @{ $seqmems } ) {
        $transcript = $sm->get_Transcript;

        next unless ( defined $transcript );

        my $exon_list;
        if    ( $sm->source_name =~ "PEP"   ) { $exon_list = $transcript->get_all_translateable_Exons }
        elsif ( $sm->source_name =~ "TRANS" ) { $exon_list = $transcript->get_all_Exons }

        my (%make_unique, $key);
        foreach my $exon ( @{ $exon_list } ) {
            my @ex_coords = ( $exon->start, $exon->end );
            $key = join(',', $gm->dbID, @ex_coords, $sm->dbID);
            
            push( @exons, { 
                gene_member_id => $gm->dbID, 
                dnafrag_start => $ex_coords[0], 
                dnafrag_end => $ex_coords[1], 
                seq_member_id => $sm->dbID 
            } ) unless ( $make_unique{ $key } );

            $make_unique{ $key } = 1;
        }
        $transcript->adaptor->db->dbc->disconnect_if_idle();
    }
    return @exons;
}

# =head2 _fetch_exons

#     Description: fetch exon coordinates for each gene member in the homology

#     Returns: hash of exon coordinates; key = genome_db_id; value = array of exon coordinates

# =cut

# sub _fetch_exons {
#     my ( $self, $orth_id ) = @_;

#     my ( %orth_exons, @new_exons );

#     my $hom_adapt = $self->compara_dba->get_HomologyAdaptor;
#     my $homology  = $hom_adapt->fetch_by_dbID( $orth_id );

#     my $gene_members = $homology->get_all_GeneMembers();    

#     my $sql = 'SELECT dnafrag_start, dnafrag_end FROM exon_ranges WHERE gene_member_id = ?';
#     my $sth = $self->db->dbc->prepare($sql);

#     foreach my $gm ( @{ $gene_members } ) {
#         $orth_exons{ $gm->genome_db_id } = [];
#         # first, check if ranges are available in the exon_ranges table
#         $sth->execute( $gm->dbID );
#         my @all_coords = @{ $sth->fetchall_arrayref([]) };

#         if ( defined $all_coords[0] ) {
#             push( @{ $orth_exons{ $gm->genome_db_id } }, \@all_coords );
#         }
#         else { # exon boundaries not found in local DB - grab using core API and store locally
#             my $seqmems = $gm->get_all_SeqMembers;
#             my $transcript;
#             foreach my $sm ( @{ $seqmems } ) {
#                 $transcript = $sm->get_Transcript;

#                 my $exon_list;
#                 if    ( $sm->source_name =~ "PEP"   ) { $exon_list = $transcript->get_all_translateable_Exons }
#                 elsif ( $sm->source_name =~ "TRANS" ) { $exon_list = $transcript->get_all_Exons }

#                 my (%make_unique, $key);
#                 foreach my $exon ( @{ $exon_list } ) {
#                     my @ex_coords = ( $exon->start, $exon->end );
#                     $key = $exon->start . "-" . $exon->end;
#                     unless ( $make_unique{ $key } ) {
#                         push( @{ $orth_exons{ $gm->genome_db_id } }, \@ex_coords );
#                         # add to list, flow to table later
#                         push( @new_exons, { gene_member_id => $gm->dbID, dnafrag_start => $ex_coords[0], dnafrag_end => $ex_coords[1] } );
#                     }
#                     $make_unique{ $key } = 1;
#                 }
#             }
#             $transcript->adaptor->db->dbc->disconnect_if_idle();
            
#         }
#     }

#     $self->param( 'new_exons', \@new_exons );
#     return \%orth_exons;
# }

# sub _stringify {
#     my ( $self, $exon ) = @_;

#     return '[' . $exon->[0] . ',' . $exon->[1] . ']';
# }

=head2 _unique_exons

	Description: take hash structure of exon ranges and remove duplicates

=cut

# sub _unique_exons {
# 	my ($self, $exons) = @_;

# 	my %uniq;
# 	foreach my $gdb ( keys %{ $exons } ) {
# 		foreach my $range ( @{ $exons->{$gdb} } ) {
# 			my $str_range = join('-', @{ $range });
# 			$uniq{$str_range} = $gdb;
# 		}
# 	}

# 	my %u_exons;
# 	foreach my $str_range ( keys %uniq ) {
# 		my $gdb = $uniq{$str_range};
# 		my @unstr_range = split('-', $str_range);
# 		push( @{ $u_exons{$gdb} }, \@unstr_range );
# 	}

# 	return \%u_exons;
# }



1;