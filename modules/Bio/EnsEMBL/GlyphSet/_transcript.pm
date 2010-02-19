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
  my ($self, $gene, $transcript) = @_;
  my $source = $ENV{'ENSEMBL_ACTION'};
#  my $action =  $source eq 'Multi' ? 'MultiTranscript' : 'Summary';#will be used to add realign around this gene link
  #logic will be moved into web_data
  my $action = $transcript->analysis->logic_name eq 'ccds_import' ? 'CCDS'
             : $transcript->analysis->logic_name eq 'refseq_human_import' ? 'RefSeq'
             : $ENV{'ENSEMBL_ACTION'};
  my $params = {
    species => $self->species,
    type    => 'Transcript',
    action  => $action,
    t       => $transcript->stable_id,
    g       => $gene->stable_id, 
    db      => $self->my_config('db')
  };
  
  $params->{'r'} = undef if $self->{'container'}->{'web_species'} ne $self->species;
  
  return $self->_url($params);
}

sub gene_href { 	 
  my ($self, $gene) = @_;
  my $source = $ENV{'ENSEMBL_ACTION'};
#  my $action =  $source eq 'Multi' ? 'MultiGene' : 'Summary';#will be used to add realign around this gene link
  #logic will be moved into web_data
  my $action = $gene->analysis->logic_name eq 'ccds_import' ? 'CCDS'
             : $gene->analysis->logic_name eq 'refseq_human_import' ? 'RefSeq'
             : $ENV{'ENSEMBL_ACTION'};
  my $params = {
    species => $self->species,
    type    => 'Gene',
    action  => $action,
    g       => $gene->stable_id, 
    db      => $self->my_config('db')
  };
  
  $params->{'r'} = undef if $self->{'container'}->{'web_species'} ne $self->species;
  
  return $self->_url($params);
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
