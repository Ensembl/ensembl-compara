=pod
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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.


=head1 NAME
	
	Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Prepare_Per_Chr_Jobs

=head1 SYNOPSIS

=head1 DESCRIPTION
  Takes as input an hash of reference and non reference species DBIDs and  dnafrag DBIDs as keys and the list of homolog DBIDs as values. 
  Unpacks the hash into seperate hashes each containing a single dnafrag DBID as the key to a list of ordered homologs.
  if the reuse_goc arguement is set to 1 and previous_rel_db argument is set,
   theis runnable will reuse goc scores from the previous db and only calculate goc scores for new homologs and the 2 homologies closest to them on each side.

    Example run

  standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Prepare_Per_Chr_Jobs

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Prepare_Per_Chr_Jobs;

use strict;
use warnings;
use Data::Dumper;
use base 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Compare_orthologs';

use Bio::EnsEMBL::Registry;

sub param_defaults {
  my $self = shift;
  return {
    %{ $self->SUPER::param_defaults() },
#      'ortholog_info_hashref' => {'1045552' => {
#                         '188667' => '91970917',
#                         '188633' => '92106887',
#                         '90131' => '114483953',
#                         '76908' => '167268593',
#                         '329697' => '168351186',
       
#                       },

#    },
#    'ref_species_dbid'    => 31,
#    'non_ref_species_dbid'    => 155, # 4,
#    'reuse_goc'   => 0,
#    'previous_rel_db'  =>  'mysql://ensadmin:ensembl@compara4/wa2_protein_trees_84',
#    'compara_db'  => 'mysql://ensadmin:ensembl@compara4/', #mysql://ensadmin:ensembl@compara3/cc21_prottree_85_snapshot',
#    'goc_mlss_id'  => '100021',# '20515',
    };
}


=head2 fetch_input

    Description : Implements fetch_input() interface method of Bio::EnsEMBL::Hive::Process that is used to read in parameters and load data.
    Here I need to retrieve the ortholog hash that was data flowed here by Prepare_Othologs.pm 

=cut

sub fetch_input {
  my $self = shift;
#  $self->debug(9);
  my $ortholog_hashref = $self->param_required('ortholog_info_hashref');
  print "Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Prepare_Per_Chr_Jobs --------------------------------START  \n  " if ( $self->debug );
  my $mlss_id = $self->param_required('goc_mlss_id');
  
  if ($self->param('reuse_goc') ) { 
    $self->param('homolog_adaptor', $self->compara_dba->get_HomologyAdaptor);
    $self->param('previous_compara_dba' , Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($self->param('previous_rel_db')) );
    $self->param('prev_homolog_adaptor', $self->param('previous_compara_dba')->get_HomologyAdaptor);
    my $q = "SELECT mlss_id FROM homology_id_mapping where mlss_id = $mlss_id limit 1";
    my $mlssID = $self->compara_dba->dbc->db_handle->selectrow_arrayref($q);

    if (defined $mlssID) {
      $self->param('mlss_check', 1);
      my $query = "SELECT curr_release_homology_id, prev_release_homology_id FROM homology_id_mapping where mlss_id = $mlss_id";
      my $hID_map = $self->compara_dba->dbc->db_handle->selectall_arrayref($query);
      my %homologyID_map = map { $_->[0] => $_->[1] } @{$hID_map} ;
      $self->param('homologyID_map', \%homologyID_map);
    }
  }
}

sub run {
  my $self = shift;
  print "the runnable Prepare_Per_Chr_Jobs ----------start \n mlss_id ---->   ", $self->param('goc_mlss_id')   if ( $self->debug >3);
  if ($self->param('reuse_goc') and $self->param('mlss_check')) {
    $self->_reusable_species();
  }
  else {
    $self->_non_reusable_species();
  }
  
  print "the runnable Prepare_Per_Chr_Jobs ----------END \n mlss_id \n", $self->param('goc_mlss_id') , if ( $self->debug >3);
}

sub _reusable_species {
  my $self = shift;
  print "\n Starting ------  _reusable_species \n" if ( $self->debug );
  my $ortholog_hashref = $self->param_required('ortholog_info_hashref');
  print "ortholog_info_hashref \n" if ( $self->debug > 3);
  print Dumper($ortholog_hashref) if ( $self->debug > 3);
  while (my ($ref_dnafragID, $chr_orth_hashref) = each(%$ortholog_hashref) ) {
    print "chr_orth_hashref  \n" if ( $self->debug > 3);
    print Dumper($chr_orth_hashref) if ( $self->debug > 3);
    my $orth_sorted = $self->_order_chr_homologs($chr_orth_hashref); # will contain the orthologs ordered by the dnafrag start position #sorting the orthologs by dnafrag start position
    for (my $homolog_index = 0; $homolog_index < scalar @{$orth_sorted}; $homolog_index++ ) {
      my $curr_homology_id = $orth_sorted->[$homolog_index];
      my $prev_homology_id = $self->param('homologyID_map')->{$curr_homology_id};
      print "\n curr_homology_id ----> $curr_homology_id   \n prev_homology_id --------> $prev_homology_id \n" if ( $self->debug > 3);

      if ( defined $prev_homology_id) {
        my $curr_homology_obj = $self->param('homolog_adaptor')->fetch_by_dbID($curr_homology_id);
        my $curr_ref_gmem_dbID = $curr_homology_obj->get_all_GeneMembers($self->param('ref_species_dbid'))->[0]->dbID;
        my $prev_homology_obj = $self->param('prev_homolog_adaptor')->fetch_by_dbID($prev_homology_id);
        my $prev_ref_gmem_dbID = $prev_homology_obj->get_all_GeneMembers($self->param('ref_species_dbid'))->[0]->dbID;
        print "\n curr_homology_id ----> $curr_homology_id can be reuseddddd  \n curr_ref_gmem_dbID --------> $curr_ref_gmem_dbID \n  prev_ref_gmem_dbID ------>$prev_ref_gmem_dbID" if ( $self->debug > 3);

        my $homology_goc_score = $self->_copy_homology_goc_score($prev_homology_id,$prev_ref_gmem_dbID);
        $homology_goc_score->{'gene_member_id'} = $curr_ref_gmem_dbID;
        $homology_goc_score->{'homology_id'} = $curr_homology_id;
        $homology_goc_score->{'dnafrag_id'} = $ref_dnafragID;
        print Dumper($homology_goc_score) if ( $self->debug > 3);
        $self->_update_ortholog_goc_table($homology_goc_score);
      }
      
      else {
        if ($homolog_index == 0 ) {
          $self->_new_homolog_at_0($orth_sorted,$homolog_index,$ref_dnafragID);
          $homolog_index +=2;
        }
        elsif ($homolog_index == 1) {
          $self->_new_homolog_at_1($orth_sorted,$homolog_index,$ref_dnafragID);
          $homolog_index +=2;
        }
        else {
          $self->_new_homolog($orth_sorted,$homolog_index,$ref_dnafragID);
          $homolog_index +=2;
        }
      }
    }
  }

}

sub _new_homolog_at_0 {
  my $self = shift;
  print "\n Starting ------  _new_homolog_at_0 \n" if ( $self->debug );
  my ($sorted_homologs,$h_index,$curr_ref_dnafragID) = @_;
  my ($left1, $left2, $right1, $right2, $query) = (undef,undef,undef,undef);
      #recalculate the goc score for the query (new) homolog
  ($right1, $right2) = ($sorted_homologs->[$h_index +1], $sorted_homologs->[$h_index +2]);
  $query = $sorted_homologs->[$h_index];
  $self->_compute_ortholog_score($left1, $left2, $query, $right1, $right2, $curr_ref_dnafragID );
  #recalculate the goc score for the homolog at right1 of the query homolog (query position +1 is now the query)
  ($left1, $query, $right1, $right2) = ($sorted_homologs->[$h_index], $sorted_homologs->[$h_index +1], $sorted_homologs->[$h_index +2], $sorted_homologs->[$h_index +3]);
   $self->_compute_ortholog_score($left1, $left2, $query, $right1, $right2, $curr_ref_dnafragID );
  #recalculate the goc score for the homolog at right2 of the query homolog (query position +2 is now the query)
  ($left2, $left1, $query, $right1, $right2) = ($sorted_homologs->[$h_index], $sorted_homologs->[$h_index +1], $sorted_homologs->[$h_index +2], $sorted_homologs->[$h_index +3], $sorted_homologs->[$h_index +4]);
#  print $left2, " left2 \n", $left1, " left1 \n", $query, " query \n", $right1, " right1 \n", $right2, " right2  \n\n";
  $self->_compute_ortholog_score($left1, $left2, $query, $right1, $right2, $curr_ref_dnafragID );
}

sub _new_homolog_at_1 {
  my $self = shift;
  print "\n Starting ------  _new_homolog_at_1 \n" if ( $self->debug );
  my ($sorted_homologs,$h_index,$curr_ref_dnafragID) = @_;
  my ($left1, $left2, $right1, $right2, $query) = (undef,undef,undef,undef);
  $self->_delete_from_goc_table($sorted_homologs->[$h_index -1]);
  #recalculate the goc score for the homolog at left1 of the query homolog (query position -1 is now the query)
  ($query, $right1, $right2) = ($sorted_homologs->[$h_index -1], $sorted_homologs->[$h_index], $sorted_homologs->[$h_index +1]);
  $self->_compute_ortholog_score($left1, $left2, $query, $right1, $right2, $curr_ref_dnafragID );
  #recalculate the goc score for the query (new) homolog 
  ($left1, $query, $right1, $right2) = ($sorted_homologs->[$h_index -1],$sorted_homologs->[$h_index],$sorted_homologs->[$h_index +1],$sorted_homologs->[$h_index +2]);
  $self->_compute_ortholog_score($left1, $left2, $query, $right1, $right2, $curr_ref_dnafragID );
  #recalculate the goc score for the homolog at right1 of the query homolog (query position +1 is now the query)
  ($left2, $left1, $query, $right1, $right2) = ($sorted_homologs->[$h_index -1], $sorted_homologs->[$h_index], $sorted_homologs->[$h_index +1], $sorted_homologs->[$h_index +2], $sorted_homologs->[$h_index +3]);
  $self->_compute_ortholog_score($left1, $left2, $query, $right1, $right2, $curr_ref_dnafragID );
  #recalculate the goc score for the homolog at right2 of the query homolog (query position +2 is now the query)
  ($left2, $left1, $query, $right1, $right2) = ($sorted_homologs->[$h_index], $sorted_homologs->[$h_index +1], $sorted_homologs->[$h_index +2], $sorted_homologs->[$h_index +3], $sorted_homologs->[$h_index +4]);
  $self->_compute_ortholog_score($left1, $left2, $query, $right1, $right2, $curr_ref_dnafragID );
}

sub _new_homolog {
  my $self = shift;
  print "\n Starting ------  _new_homolog \n" if ( $self->debug );
  my ($sorted_homologs,$h_index,$curr_ref_dnafragID) = @_;
  my ($left1, $left2, $right1, $right2, $query) = (undef,undef,undef,undef);
  $self->_delete_from_goc_table($sorted_homologs->[$h_index -1]);
  $self->_delete_from_goc_table($sorted_homologs->[$h_index -2]);
  #recalculate the goc score for the homolog at left2 of the query homolog (query position -2 is now the query)
  ($left2, $left1, $query, $right1, $right2) = ($sorted_homologs->[$h_index -4], $sorted_homologs->[$h_index -3], $sorted_homologs->[$h_index -2], $sorted_homologs->[$h_index -1], $sorted_homologs->[$h_index]);
  $self->_compute_ortholog_score($left1, $left2, $query, $right1, $right2, $curr_ref_dnafragID );
  #recalculate the goc score for the homolog at left1 of the query homolog (query position -1 is now the query)
  ($left2, $left1, $query, $right1, $right2) = ($sorted_homologs->[$h_index -3], $sorted_homologs->[$h_index -2], $sorted_homologs->[$h_index -1], $sorted_homologs->[$h_index], $sorted_homologs->[$h_index +1]);
  $self->_compute_ortholog_score($left1, $left2, $query, $right1, $right2, $curr_ref_dnafragID );
  #recalculate the goc score for the query (new) homolog 
  ($left2, $left1, $query, $right1, $right2) = ($sorted_homologs->[$h_index -2], $sorted_homologs->[$h_index -1], $sorted_homologs->[$h_index], $sorted_homologs->[$h_index +1], $sorted_homologs->[$h_index +2]);
  $self->_compute_ortholog_score($left1, $left2, $query, $right1, $right2, $curr_ref_dnafragID );
  #recalculate the goc score for the homolog at right1 of the query homolog (query position +1 is now the query)
  ($left2, $left1, $query, $right1, $right2) = ($sorted_homologs->[$h_index -1], $sorted_homologs->[$h_index], $sorted_homologs->[$h_index +1], $sorted_homologs->[$h_index +2], $sorted_homologs->[$h_index +3]);
  $self->_compute_ortholog_score($left1, $left2, $query, $right1, $right2, $curr_ref_dnafragID );
  #recalculate the goc score for the homolog at right2 of the query homolog (query position +2 is now the query)
  ($left2, $left1, $query, $right1, $right2) = ($sorted_homologs->[$h_index], $sorted_homologs->[$h_index +1], $sorted_homologs->[$h_index +2], $sorted_homologs->[$h_index +3], $sorted_homologs->[$h_index +4]);
  $self->_compute_ortholog_score($left1, $left2, $query, $right1, $right2, $curr_ref_dnafragID );
}

sub _delete_from_goc_table {
  my $self = shift;
  print "\n Starting ------  _delete_from_goc_table \n" if ( $self->debug );
  my $mlss_id = $self->param_required('goc_mlss_id');
  my $query_homolog_id = shift @_;
  my $query_homology_obj = $self->param('homolog_adaptor')->fetch_by_dbID($query_homolog_id);
  my $query_ref_gmem_dbID = $query_homology_obj->get_all_GeneMembers($self->param('ref_species_dbid'))->[0]->dbID;
  my $query2 = "DELETE FROM ortholog_goc_metric where method_link_species_set_id = ? AND homology_id = ? AND gene_member_id = ?";
  my $sth = $self->compara_dba->dbc->db_handle->prepare($query2);
  $sth->execute($mlss_id,$query_homolog_id,$query_ref_gmem_dbID);

}

#this method will query the ortholog_goc_metric table from the previous db using the prev homology id that maps to the new homology id
sub _copy_homology_goc_score {
  my $self = shift;
  print "\n Starting ------  _copy_homology_goc_score \n" if ( $self->debug );
  my ($query_hID, $query_gmem_ID) = @_; 
  my $mlss_id = $self->param_required('goc_mlss_id');
  my $query2 = "SELECT goc_score, left1, left2, right1, right2 FROM ortholog_goc_metric 
                WHERE method_link_species_set_id = $mlss_id AND homology_id = $query_hID and gene_member_id = $query_gmem_ID ";
  my $query_goc_score = $self->param('previous_compara_dba')->dbc->db_handle->selectrow_hashref($query2);
  return $query_goc_score;              
}

#this method will write the retrieved homology score to the new db ortholog_goc_metric table so that it can be reused
sub _update_ortholog_goc_table {
  my $self = shift;
  print "\n Starting ------  _update_ortholog_goc_table \n" if ( $self->debug );
  my $result = shift @_;
  $self->dataflow_output_id($result, 3 );
}

#this method creates a per chromosome array of ordered homologies which it dataflows to the compare_orthologs.pm
sub _non_reusable_species {
  my $self = shift;
  print "\n Starting ------  _non_reusable_species \n" if ( $self->debug );
  my $ortholog_hashref = $self->param_required('ortholog_info_hashref');

  while (my ($ref_dnafragID, $chr_orth_hashref) = each(%$ortholog_hashref) ) {   
    my $orth_sorted = $self->_order_chr_homologs($chr_orth_hashref); # will contain the orthologs ordered by the dnafrag start position #sorting the orthologs by dnafrag start position
    my $chr_job = {};
    $chr_job->{$ref_dnafragID} = $orth_sorted;
    print Dumper($chr_job) if ( $self->debug > 3);
    $self->dataflow_output_id( {'chr_job' => $chr_job, 'ref_species_dbid' => $self->param('ref_species_dbid'), 'non_ref_species_dbid' => $self->param('non_ref_species_dbid') }, 2 );  
  }
}

#this method sorts an hash of homology id and dnafrag_starts into an ordered array of homology_ids based on the dnafrag starts
sub _order_chr_homologs {
  my $self = shift;
  print "\n Starting ------  _order_chr_homologs \n" if ( $self->debug );
  my ($unsorted_chr_orth_hashref) = @_;
  print "unsorted_chr_orth_hashref \n"  if ( $self->debug );
  print Dumper($unsorted_chr_orth_hashref) if ( $self->debug );
  my @sorted_orth;
  foreach my $name (sort { $unsorted_chr_orth_hashref->{$a} <=> $unsorted_chr_orth_hashref->{$b} } keys %$unsorted_chr_orth_hashref ) {
    
        printf "%-8s %s \n", $name, $unsorted_chr_orth_hashref->{$name} if ( $self->debug >3);
        push @sorted_orth, $name;

    }

    return \@sorted_orth;
}

1;


