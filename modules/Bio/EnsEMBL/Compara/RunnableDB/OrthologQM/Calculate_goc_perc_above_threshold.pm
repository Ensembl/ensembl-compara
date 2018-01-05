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

Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Calculate_goc_perc_above_threshold

=head1 DESCRIPTION

use the genetic distance of a pair species to determine what the goc threshold should be. 

Example run

  standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Calculate_goc_perc_above_threshold -goc_mlss_id -goc_threshold

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Calculate_goc_perc_above_threshold;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
	my $self = shift;
  print " START OF Calculate_goc_perc_above_threshold-------\n  mlss_id  :    ", $self->param('goc_mlss_id'), "\n goc_threshold  :  ", $self->param_required('goc_threshold'), "  ---\n\n" if ($self->debug);
  my $mlss_id = $self->param('goc_mlss_id');
  my $query = "SELECT goc_score , COUNT(*) FROM homology where method_link_species_set_id =$mlss_id GROUP BY goc_score";
  my $goc_distribution = $self->compara_dba->dbc->db_handle->selectall_arrayref($query);
  $self->param('goc_dist', $goc_distribution);
  print Dumper($self->param('goc_dist')) if ( $self->debug >3 );
  my $thresh = $self->param_required('goc_threshold');
  print "this is the goc threshold :           $thresh \n\n" if ( $self->debug );
	$self->param('thresh', $thresh);

  print " START OF Calculate_goc_perc_above_threshold-------------- mlss_id ---------------  $mlss_id  --------\n\n  " if ($self->debug);
}

sub run {
  my $self = shift;

  if ( scalar @{$self->param('goc_dist')} == 1 ) {
    if ( $self->param('goc_dist')->[0]->[0] eq '0' ) {
      print "\n all the goc score are zeros \n" if ( $self->debug);
      $self->param('perc_above_thresh', '0');
    }
    else {
      print "\n all the goc score are Nul \n" if ( $self->debug);
      $self->param('perc_above_thresh', 'NULL');
    }
  }
  else { 
    $self->param('perc_above_thresh', $self->_calculate_perc());
    print "\n\n"  , $self->param('perc_above_thresh') , "\n\n" if ( $self->debug >3 );
  }
}

sub write_output {
  	my $self = shift @_;
    print $self->param('thresh') , "  :  goc_threshold \n" , $self->param('perc_above_thresh') , "  :  perc_above_thresh \n " if ( $self->debug >3 );
    #goc threshold need to be dataflow'd  beacuse if it is given a default value by the user this would not have been dataflow'd atleast once, hence the next runnable after this will not be able to access it, causing failure.
    $self->dataflow_output_id( {'perc_above_thresh' => $self->param('perc_above_thresh'), 'goc_dist' => $self->param('goc_dist'), 'goc_threshold' => $self->param('thresh')} , 1);
}


sub _calculate_perc {
  my $self = shift @_;
  my ($total, $above_thresh_total);
  foreach my $dist (@{$self->param('goc_dist')}) {
    if (!$dist->[0]) {
      next;
    }
    else{
      $total += $dist->[1];

      if ($dist->[0] >= $self->param('thresh')) {
        $above_thresh_total += $dist->[1];
      }

    }
  }
  if (!$total) {
    #if all the goc scores are zero
    #we will only get here if there both Null and zero goc scores
    print "\n all the goc score are either zeros or nulls \n" if ( $self->debug);
    return '0';
  }
  my $perc_above_thresh = ($above_thresh_total/$total) * 100;
  return $perc_above_thresh;
}

1;