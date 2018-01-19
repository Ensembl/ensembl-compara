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

Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Compare_orthologs

=head1 DESCRIPTION

    Takes as input an hash of orthologs as values (the query ortholog and 2 orthologs to its left and 2 to its right). The hash also contains the dna frag id of the ref genome, the reference species dbid and the non reference species dbid
    It uses the orthologs to pull out the ref and non ref members.
    it then uses the extreme start and end of the non ref members to define a constraint that is used in a query to pull all the members spanning that region on the non ref genome.
    This new member are screened and ordered before their ordered is compared to the order depicted by the orthologous members.
    It returns an hash showing how much of the orthologous memebers match the order of the members on the genome and a percentage score to reflect this.

    Example run

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Compare_orthologs
=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Compare_orthologs;

use strict;
use warnings;

use Data::Dumper;
use List::MoreUtils qw(firstidx);

use Bio::EnsEMBL::Compara::Utils::CopyData qw(:insert);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
  my $self = shift;
  return {
    %{ $self->SUPER::param_defaults() },
#    "chr_job" => {13200473 => [70578,153474,171749,153125,225827,40769]},
#    "non_ref_species_dbid" => 144,
#    "ref_species_dbid" => 122,
#    'compara_db'  => 'mysql://ensadmin:'.$ENV{ENSADMIN_PSW}.'@compara5/cc21_protein_trees_no_reuse_86',
#    'goc_mlss_id'  => '50062',
    }
}

=head2 fetch_input

    Description : Implements fetch_input() interface method of Bio::EnsEMBL::Hive::Process that is used to read in parameters and load data.
    Here I need to retrieve the ordered chromosome ortholog hash that was data flowed here by Prepare_Per_Chr_Jobs.pm

=cut

sub fetch_input{
    my $self = shift;
#    $self->debug(1);

    # Preload all the homologies
  my $preloaded_homologs_hashref;
  my $homology_adaptor = $self->compara_dba->get_HomologyAdaptor;
  while (my ($dnafrag_id, $homologies_dbID_list) = each(%{$self->param('chr_job')}) ) {

#preload all gene members to make quering the homologs faster later on
    my $homologs = $homology_adaptor->fetch_all_by_dbID_list($homologies_dbID_list);
    my $sms = Bio::EnsEMBL::Compara::Utils::Preloader::expand_Homologies($homologs->[0]->adaptor->db->get_AlignedMemberAdaptor, $homologs);
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_GeneMembers($homologs->[0]->adaptor->db->get_GeneMemberAdaptor, $sms);

  #loop through the preloaded homologies to create a hash table homology id => homology object. this will serve as a look up table 
    while ( my $ortholog = shift( @{ $homologs} ) ) {
        $preloaded_homologs_hashref->{$ortholog->dbID()} = $ortholog;
    }
  }

    $self->param('preloaded_homologs', $preloaded_homologs_hashref);
    $self->param('all_goc_score_arrayref', []);

}

sub run {
    my $self = shift;
    my $chr_orth_hashref = $self->param('chr_job');
#    $self->dbc and $self->dbc->disconnect_if_idle();
    print " --------------------------------------Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Comparison_job_arrays \n\n" if ( $self->debug );
    print Dumper($chr_orth_hashref)if ( $self->debug >3 );
    my $count_homologs = 0;
    while (my ($ref_chr_dnafragID, $ordered_orth_arrayref) = each(%$chr_orth_hashref) ) {
        my @ordered_orth_array = @$ordered_orth_arrayref;
        print $#ordered_orth_array , "\n\n" if ( $self->debug >3 );
        foreach my $index (0 .. $#ordered_orth_array ) {
            $count_homologs ++;
            my $comparion_arrayref = {};
            my ($left1, $left2, $right1, $right2, $query) = (undef,undef,undef,undef);

            if ($index == 1){
                $left1 = $ordered_orth_array[0];
            }
            if ($index != 1 and $index != 0){

                $left1 = $ordered_orth_array[$index - 1];
                $left2 = $ordered_orth_array[$index - 2];
            }
            if ($index == $#ordered_orth_array -1) {
                $right1 = $ordered_orth_array[$index + 1];
            }
            if ($index != $#ordered_orth_array and $index != $#ordered_orth_array -1) {
                $right1 = $ordered_orth_array[$index + 1];
                $right2 = $ordered_orth_array[$index + 2];

            }
            $query = $ordered_orth_array[$index];
            print $left1//'NA', " left1 ", $left2//'NA', " left2 ", $query, " query ", $right1//'NA', " right1 ", $right2//'NA', " right2 ", $ref_chr_dnafragID, " ref_chr_dnafragID\n\n" if ( $self->debug );
            my $goc_score_hashref = $self->_compute_ortholog_score($left1, $left2, $query, $right1, $right2);
            push @{$self->param('all_goc_score_arrayref')}, $goc_score_hashref ;
        }
    }
    print "\n\n This is how many homology ids were in the input : $count_homologs  \n\n" if ( $self->debug );
}

sub write_output {
    my $self = shift;
    $self->_insert_goc_scores($self->param('all_goc_score_arrayref'));
}

#this method will create one sql insert statement out of the goc_scores array and insert it into the ortholog_goc_metric table
sub _insert_goc_scores {
  my ($self, $goc_arrayref) = @_;
  print "\n Starting ------  _insert_goc_scores\n" if ( $self->debug );

  my $size_goc_score_arrayref = scalar @$goc_arrayref;
  print "\n\n This is the how many homology ids we have goc scores for and inserting into the ortholog goc table :  \n  $size_goc_score_arrayref \n\n " if ( $self->debug );
  my @goc_data;
  foreach ( @$goc_arrayref ) {
    defined $_->{'goc_score'} or die " the goc score should atleast be 0. mlss id :  $_->{'method_link_species_set_id'} , homology_id : $_->{'homology_id'} ";
    defined $_->{'method_link_species_set_id'} or die " the method_link_species_set_id can not be empty. homology_id : $_->{'homology_id'} ";
    push @goc_data, [$_->{'method_link_species_set_id'}, $_->{'homology_id'}, $_->{'gene_member_id'}, $_->{'goc_score'}, $_->{'left1'}, $_->{'left2'}, $_->{'right1'}, $_->{'right2'}];
  }

  bulk_insert($self->compara_dba->dbc, 'ortholog_goc_metric', \@goc_data, [qw(method_link_species_set_id homology_id gene_member_id goc_score left1 left2 right1 right2)], 'INSERT IGNORE');
}


sub _compute_ortholog_score {
    my $self = shift;
    my ($left1, $left2, $query, $right1, $right2) = @_;
    print " ------------------------------------_compute_ortholog_score  \n\n" if ( $self->debug );
#    print " \n ", $left1//'NA',  " left1 ", $left2//'NA', " left2 ", $query, " query ", $right1//'NA', " right1 ", $right2//'NA', " right2\n\n" if ( $self->debug >1);
    my %input_hash = ('left1' => $left1, 'left2' => $left2, 'query' => $query, 'right1' => $right1 , 'right2' => $right2);

    #create an array of only the present neighbours
    # will be useful in collapsing tandem duplications
    print " getting homolog gene tree node id-------------------------START \n" if ( $self->debug );
    my $homology_gtn_id_href = {};
    for my $pos (($left1, $left2, $query, $right1, $right2)) {
        if (defined $pos) {
            my $gtn_id = $self->param('preloaded_homologs')->{$pos}->_gene_tree_node_id();
#            print $pos , "-------------------------", $gtn_id , "-----\n\n" if ( $self->debug >3 );
            if ( not defined($homology_gtn_id_href->{$gtn_id})) {
                $homology_gtn_id_href->{$gtn_id} = [$pos];
            }
            else {
                push (@{$homology_gtn_id_href->{$gtn_id}}, $pos);
            }
        }
    }
    $self->param('homology_gtn_id_href', $homology_gtn_id_href);
#    print Dumper($self->param('homology_gtn_id_href')) if ( $self->debug );
#    print " getting homolog gene tree node id-------------------------END \n" if ( $self->debug );

    my @defined_positions;
    if (defined($left1)) {
        push(@defined_positions, 'left1');
        if (defined($left2)) {
            push(@defined_positions, 'left2');
        }
    }
    if (defined($right1)) {
        push(@defined_positions, 'right1');
        if (defined($right2)) {
            push(@defined_positions, 'right2');
        }
    }
    my $homology = $self->param('preloaded_homologs')->{$query};

    my $result;
    my $non_ref_gmembers_list={};

    my $query_ref_gmem_obj = $homology->get_all_GeneMembers($self->param('ref_species_dbid'))->[0];
    my $query_non_ref_gmem_obj = $homology->get_all_GeneMembers($self->param('non_ref_species_dbid'))->[0];
    $non_ref_gmembers_list->{'query'} = $query_non_ref_gmem_obj->dbID;
    my $start = $query_non_ref_gmem_obj->dnafrag_start;
    my $end = $query_non_ref_gmem_obj->dnafrag_end;
    my $query_non_ref_dnafragID = $query_non_ref_gmem_obj->dnafrag_id() ;

    #create an hash ref with the non ref member dbid of the defined positions as the values using the defined positions as the keys, also get the extreme start and end postions on the genome
    #only use non ref gene members on the same chr as the query non ref gene member to get the start and end postions.
    #the extreme start and end will be used in the subroutine _get_non_ref_gmembers to define the section of the genome that we want to pull out
    #this will allow me to check if the non ref gene members of the defined positions are in order
    foreach my $ortholog (@defined_positions) {
        my $non_ref_gm = $self->param('preloaded_homologs')->{$input_hash{$ortholog}}->get_all_GeneMembers($self->param('non_ref_species_dbid'))->[0];
        $non_ref_gmembers_list->{$ortholog} = $non_ref_gm->dbID;
        if ($query_non_ref_dnafragID eq $non_ref_gm->dnafrag_id()) {
            if ($start > $non_ref_gm->dnafrag_start()) {
                $start = $non_ref_gm->dnafrag_start();
            }
            if ($end < $non_ref_gm->dnafrag_end()) {
                $end =  $non_ref_gm->dnafrag_end();
            }
        }
    }

    #to account for inversions in the genome, we checks if both members of the query ortholog are in the same direction/ strand
    my $strand = 0;
    if ($query_ref_gmem_obj->dnafrag_strand() == $query_non_ref_gmem_obj->dnafrag_strand()) {
        $strand = 1;
    }

    # get the all protein-coding gene members (ordered by their dnafrag start position)  spanning the specified start and end range of the given chromosome. dnafrag_id  == chromosome, that have homologs on the ref genome
    $self->param('non_ref_gmembers_ordered', $self->_get_non_ref_gmembers($query_non_ref_dnafragID, $start, $end));

    #Create the result hash showing if the order gene conservation indicated by the ortholog matches the order of genes retrieve from the geneme.
    if ($strand == 1) {
        $result = $self->_compare($non_ref_gmembers_list, $self->param('non_ref_gmembers_ordered'));
    }
    else {
        my $temp_query = $non_ref_gmembers_list->{'query'};
        my $temp_left1 = $non_ref_gmembers_list->{'right1'};
        my $temp_left2 = $non_ref_gmembers_list->{'right2'};
        my $temp_right1 = $non_ref_gmembers_list->{'left1'};
        my $temp_right2 = $non_ref_gmembers_list->{'left2'};
        my $result_temp = $self->_compare( {'query' => $temp_query, 'left1' => $temp_left1, 'left2' => $temp_left2, 'right1' => $temp_right1, 'right2' => $temp_right2}, , $self->param('non_ref_gmembers_ordered'));
        $result = {
            'left1' => $result_temp->{right1},
            'left2' => $result_temp->{right2},
            'right1' => $result_temp->{left1},
            'right2' => $result_temp->{left2},
        };
    }

    #calculate the percentage of the goc score
    my $percent = ($result->{'left1'} // 0) + ($result->{'left2'} // 0) + ($result->{'right1'} // 0) + ($result->{'right2'} // 0);
    my $percentage = $percent * 25;

    $result->{'goc_score'}      = $percentage;
    $result->{'dnafrag_id'}     = $query_ref_gmem_obj->dnafrag_id();
    $result->{'gene_member_id'} = $query_ref_gmem_obj->dbID();
    $result->{'homology_id'}    = $query;
    $result->{'method_link_species_set_id'} = $self->param('goc_mlss_id');

#    print "RESULTS hash--------------->>>>>   \n" if ( $self->debug );
#    print Dumper($result) if ( $self->debug );
#    print  " mlss_id  ----->>>>  \n", $self->param('goc_mlss_id'), "\n" if ( $self->debug );
    return $result;

}

sub _fetch_members_with_homology_by_range {
    my $self = shift;
    my ($dnafragID, $st, $ed)= @_;

        # The query could do GROUP BY and ORDER BY, but the MySQL server would have to buffer the data, make temporary tables, etc
        # It is faster to have a straightforward query and do some processing in Perl
    my $sql = q{SELECT m.gene_member_id, m.dnafrag_start, homology.gene_tree_node_id, homology.homology_id FROM gene_member m
            JOIN
                homology_member USING (gene_member_id)
            JOIN
                homology USING (homology_id)
            WHERE
                method_link_species_set_id = ? AND (m.dnafrag_id = ?) AND (m.dnafrag_start BETWEEN ? AND ?) AND (m.dnafrag_end BETWEEN ? AND ?) AND m.biotype_group = "coding"};

        # Returns the rows as an array of hashes (Slice parameter)
    return $self->compara_dba->dbc->db_handle->selectall_arrayref($sql, {Slice=> {}} , $self->param('goc_mlss_id'), $dnafragID, $st, $ed, $st, $ed);
}


#get all the gene members of in a chromosome coordinate range, filter only the ones that are protein-coding and order them based on their dnafrag start positions
sub _get_non_ref_gmembers {
    my $self = shift;
    print "This is the _get_non_ref_members subroutine -------------------------------START\n\n\n" if ( $self->debug );
    my ($dnafragID, $st, $ed)= @_;
        print $dnafragID,"\n", $st ,"\n", $ed ,"\n\n" if ( $self->debug >3 );

    my $unsorted_mem = $self->_fetch_members_with_homology_by_range($dnafragID, $st, $ed);

    # And now we simply sort the genes by their coordinates and return the sorted list
    my @sorted_all_mem = sort {($a->{dnafrag_start} <=> $b->{dnafrag_start}) || ($a->{gene_member_id} <=> $b->{gene_member_id}) || ($a->{homology_id} <=> $b->{homology_id})} @$unsorted_mem;

        #collapse tandem duplications
    my @sorted_mem=grep {$self->_collapse_tandem_repeats($_)} @sorted_all_mem;

    my @nr_gmem_sorted;
    foreach my $mem (@sorted_mem) {
        push (@nr_gmem_sorted, $mem->{gene_member_id});
    }
#    print "This is the _get_non_ref_members subroutine ------------------------------END\n\n" if ( $self->debug );
    return \@nr_gmem_sorted;
}


#this will loop through the list of raw non ref gene members and flag tandem repeats. which will then be remove from the rest of the analyses
sub _collapse_tandem_repeats {
    my $self = shift;
    print " THis is the _collapse_tandem_repeats------------------------------START\n\n" if ( $self->debug > 3);
    my ($local_unsorted_mem) = @_;

    #check if the gene member is a tandem duplication by looking for it comparing gene tree node its of it homology_id
    if ( (defined $self->param('homology_gtn_id_href')->{$local_unsorted_mem->{gene_tree_node_id}}) &&
                not (grep {$local_unsorted_mem->{homology_id} == $_} @{$self->param('homology_gtn_id_href')->{$local_unsorted_mem->{gene_tree_node_id} } } ) ) {

                    return 0;
            }
            return 1;
}

#check that the order of the non ref gmembers that we get from the orthologs match the order of the gene member that we get from the the method '_get_non_ref_members'
sub _compare {
    my $self = shift;
    print " THis is the _compare subroutine -----------------------------------------START\n\n" if ( $self->debug );
    my ($orth_non_ref_gmembers_hashref, $ordered_non_ref_gmembers_arrayref,$strand1)= @_;
    my $non_ref_query_gmember = $orth_non_ref_gmembers_hashref->{'query'};
    my $query_index = firstidx { $_ eq $non_ref_query_gmember } @$ordered_non_ref_gmembers_arrayref;

        #create an array of available $ordered_non_ref_gmembers_arrayref index so that we dont check uninitialised values in our comparisons
    my @indexes;
    for my $val (0 .. scalar(@{$ordered_non_ref_gmembers_arrayref})-1) {
        push @indexes, $val;
    }

    my $left1_result = undef ;
    my $left2_result = undef;
    my $right1_result = undef ;
    my $right2_result = undef;

    if (defined($orth_non_ref_gmembers_hashref->{'left1'} )) {
        $left1_result =    (grep {$_ == $query_index-1} @indexes)
                                    && (    ($orth_non_ref_gmembers_hashref->{'left1'} eq $ordered_non_ref_gmembers_arrayref->[$query_index -1])
                                         || (      (grep {$_ == $query_index-2} @indexes)
                                                && ($orth_non_ref_gmembers_hashref->{'left1'} eq $ordered_non_ref_gmembers_arrayref->[$query_index -2])
                                            )
                                       )
                        ? 1 : 0;

        if (defined($orth_non_ref_gmembers_hashref->{'left2'} )) {
            $left2_result = ( $left1_result
                        ? (
                                    (grep {$_ == $query_index-2} @indexes)
                                 && (   ($orth_non_ref_gmembers_hashref->{'left2'} eq $ordered_non_ref_gmembers_arrayref->[$query_index -2])
                                     || (   (grep {$_ == $query_index-3} @indexes)
                                         && ($orth_non_ref_gmembers_hashref->{'left2'} eq $ordered_non_ref_gmembers_arrayref->[$query_index -3])
                                        )
                                    )
                        )
                        : (
                                    (grep {$_ == $query_index-1} @indexes)
                                 && (     ($orth_non_ref_gmembers_hashref->{'left2'} eq $ordered_non_ref_gmembers_arrayref->[$query_index -1])
                                       || (    (grep {$_ == $query_index-2} @indexes)
                                            && ($orth_non_ref_gmembers_hashref->{'left2'} eq $ordered_non_ref_gmembers_arrayref->[$query_index -2])
                                          )
                                    )
                        )
                     ) ? 1 : 0;
        }
    }

    if (defined($orth_non_ref_gmembers_hashref->{'right1'} )) {
        $right1_result =    (grep {$_ == $query_index+1} @indexes)
                                    && (    ($orth_non_ref_gmembers_hashref->{'right1'} eq $ordered_non_ref_gmembers_arrayref->[$query_index +1])
                                         || (      (grep {$_ == $query_index+2} @indexes)
                                                && ($orth_non_ref_gmembers_hashref->{'right1'} eq $ordered_non_ref_gmembers_arrayref->[$query_index +2])
                                            )
                                       )
                        ? 1 : 0;

        if (defined($orth_non_ref_gmembers_hashref->{'right2'} )) {
            $right2_result = ( $right1_result
                        ? (
                                    (grep {$_ == $query_index+2} @indexes)
                                 && (   ($orth_non_ref_gmembers_hashref->{'right2'} eq $ordered_non_ref_gmembers_arrayref->[$query_index +2])
                                     || (   (grep {$_ == $query_index+3} @indexes)
                                         && ($orth_non_ref_gmembers_hashref->{'right2'} eq $ordered_non_ref_gmembers_arrayref->[$query_index +3])
                                        )
                                    )
                        )
                        : (
                                    (grep {$_ == $query_index+1} @indexes)
                                 && (     ($orth_non_ref_gmembers_hashref->{'right2'} eq $ordered_non_ref_gmembers_arrayref->[$query_index +1])
                                       || (    (grep {$_ == $query_index+2} @indexes)
                                            && ($orth_non_ref_gmembers_hashref->{'right2'} eq $ordered_non_ref_gmembers_arrayref->[$query_index +2])
                                          )
                                    )
                        )
                     ) ? 1 : 0;
        }
    }
#    print " THis is the _compare subroutine -------------------------------END\n\n" if ( $self->debug );
    return {'left1' => $left1_result, 'right1' => $right1_result, 'left2' => $left2_result, 'right2' => $right2_result};
}

1;
