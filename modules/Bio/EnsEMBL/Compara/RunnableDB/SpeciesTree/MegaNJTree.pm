=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::MegaNJTree

=head1 SYNOPSIS

Wrapper around MEGA (http://www.megasoftware.net/)

=head1 DESCRIPTION

=cut

package Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::MegaNJTree;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Bio::Tree::DistanceFactory;
use Bio::Matrix::IO;

# sub run {
# 	my $self = shift;

# 	my $mega_exe  = $self->param_required('mega_exe');
# 	my $data_file = $self->param_required('data_file');
# 	my $analysis_opts_file = $self->param_required('analysis_opts_file');

# 	my $mega_cmd = "$mega_exe -a $analysis_opts_file -d $data_file";
# 	$mega_cmd .= " -o " . $self->param('outfile') if $self->param('outfile');
# 	system($mega_cmd) == 0 or die "Error running command: $mega_cmd\n";
# }

sub run {
	my $self = shift;

	$self->createTreeFromPhylip( $self->param_required('phylip_file'), $self-> );
}

sub createTreeFromPhylip{
  my($self, $phylip, $outdir)=@_;

  my $dfactory = Bio::Tree::DistanceFactory->new(-method=>"NJ");
  my $matrix   = Bio::Matrix::IO->new(-format=>"phylip", -file=>$phylip)->next_matrix;
  my $treeObj = $dfactory->make_tree($matrix);
  open(TREE,">","$outdir/tree.dnd") or die "ERROR: could not open $outdir/tree.dnd: $!";
  print TREE $treeObj->as_text("newick");
  print TREE "\n";
  close TREE;

  return $treeObj;

}

1;