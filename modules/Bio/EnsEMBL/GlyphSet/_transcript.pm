package Bio::EnsEMBL::GlyphSet::_transcript;

use strict;

use base qw( Bio::EnsEMBL::GlyphSet_transcript );

sub analysis_logic_name{
  my $self = shift;
  return $self->my_config('LOGIC_NAME');
}

sub features {
  my ($self) = @_;
  my $slice = $self->{'container'};
  
  my $db_alias = $self->my_config('db');
  my $analyses = $self->my_config('logicnames');
  my @T = map { @{$slice->get_all_Genes( $_, $db_alias )||[]} } @$analyses;
  $self->timer_push( 'Fetched transcripts', undef, 'fetch' );
  return \@T;
}

sub text_label {
  my ($self, $gene, $transcript) = @_;
  my $id  = $transcript->external_name || $transcript->stable_id;
  return $id if $self->get_parameter( 'opt_shortlabels');
  my $label = $self->transcript_label($transcript, $gene);
  $id .= "\n$label" unless $label eq '-';
  return $id;
}

sub gene_text_label {
  my ($self, $gene ) = @_;
  my $id  = $gene->external_name || $gene->stable_id;
  return $id if $self->get_parameter( 'opt_shortlabels');
  my $label = $self->gene_label( $gene);
  $id .= "\n$label" unless $label eq '-';
  return $id;
}

sub _add_legend_entry {
  my $self = shift;
  $self->{'legend_data'}{ $self->{'my_config'}->left }=1;
}

sub legend {
  my ($self, $colours) = @_;
  # TODO; make generic
  return undef;
}

## sub error_track_name { return $_[0]->my_label }

sub href { 	 
  my ($self, $gene, $transcript, %highlights ) = @_; 	 
  my $gid = $gene->stable_id(); 	 
  my $tid = $transcript->stable_id(); 	 
  return $self->_url({'type'=>'Transcript','action'=>'Summary','t'=>$tid,'g'=>$gid, 'db' => $self->my_config('db')}); 	 
} 	 
  	 
sub gene_href { 	 
  my ($self, $gene, %highlights ) = @_; 	 
  my $gid = $gene->stable_id(); 	 
  return $self->_url({'type'=>'Gene','action'=>'Summary','g'=>$gid, 'db' => $self->my_config('db') }); 	 
}

sub export_feature {
  my $self = shift;
  my ($feature, $transcript_id, $transcript_name, $gene_id, $gene_name, $gene_type) = @_;
  
  return $self->_render_text($feature, 'Exon', {
    'headers' => [ 'gene_id', 'gene_name', 'transcript_id', 'transcript_name', 'exon_id', 'gene_type' ],
    'values' => [ $gene_id, $gene_name, $transcript_id, $transcript_name, $feature->stable_id, $gene_type ]
  });
}

1;
