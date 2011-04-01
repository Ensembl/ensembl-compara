# $Id$

package EnsEMBL::Web::Configuration::StructuralVariation;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  $self->{'_data'}->{'default'} = 'Summary';
}


sub populate_tree {
  my $self = shift;

	$self->create_node('Summary', 'Genes/Transcripts',
    [qw( summary EnsEMBL::Web::Component::StructuralVariation::Mappings )],
    { 'availability' => 'structural_variation', 'concise' => 'Overlapped Genes/Transcripts' }
  );
	
	$self->create_node('Evidence', 'Supporting evidence',
    [qw( summary  EnsEMBL::Web::Component::StructuralVariation::SupportingEvidence)],
    { 'availability' => 'supporting_structural_variation', 'concise' => 'Supporting evidence' }
  );
	
  $self->create_node('Context', 'Genomic context',
    [qw( summary  EnsEMBL::Web::Component::StructuralVariation::Context)],
    { 'availability' => 'structural_variation', 'concise' => 'Context' }
  );
}
1;
