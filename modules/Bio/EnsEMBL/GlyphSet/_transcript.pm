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
  my $analyses = $self->my_config('logic_names');
  my @T;
  ## FIXME - this is an ugly hack!
  if ($slice->isa('Bio::EnsEMBL::LRGSlice') && $analyses->[0] ne 'LRG_import') {
    @T = map { @{$slice->feature_Slice->get_all_Genes( $_, $db_alias )||[]} } @$analyses;
  }
  else {
    @T = map { @{$slice->get_all_Genes( $_, $db_alias, 1 )||[]} } @$analyses;
  }
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

sub href {
  my ($self, $gene, $transcript) = @_;
  my $action =  $self->my_config('zmenu') ?  $self->my_config('zmenu') :  $ENV{'ENSEMBL_ACTION'};
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
  my $action =  $self->my_config('zmenu') ?  $self->my_config('zmenu') :  $ENV{'ENSEMBL_ACTION'};
  my $gene_loc = $gene->seq_region_name.':'.$gene->seq_region_start.'-'.$gene->seq_region_end.':'.$gene->seq_region_strand;
  my $params = {
    species    => $self->species,
    type       => 'Gene',
    action     => $action,
    g          => $gene->stable_id, 
    db         => $self->my_config('db'),
    calling_sp => $ENV{'ENSEMBL_SPECIES'},
  };

  $params->{'r'} = undef if $self->{'container'}->{'web_species'} ne $self->species;

  my $url_params = $self->{'config'}->core_objects->{'input'};
  foreach my $p ( @{$url_params->{'.parameters'}} ) {
    if ($p =~ /^s|r\d+/) {
      $params->{$p} =  $url_params->{$p}[0];
    }
    if ($p eq 'r') {
      $params->{'real_r'} =  $url_params->{$p}[0];
    }
  }

  return $self->_url($params);
}

sub export_feature {
  my $self = shift;
  my ($feature, $transcript_id, $transcript_name, $gene_id, $gene_name, $gene_type, $gene_source) = @_;
  
  return $self->_render_text($feature, 'Exon', {
    headers => [ 'gene_id', 'gene_name', 'transcript_id', 'transcript_name', 'exon_id', 'gene_type' ],
    values  => [ $gene_id, $gene_name, $transcript_id, $transcript_name, $feature->stable_id, $gene_type ]
  }, { source => $gene_source });
}

1;
