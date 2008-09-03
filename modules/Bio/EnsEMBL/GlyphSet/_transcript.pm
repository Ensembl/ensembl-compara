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
  return \@T;
}

sub text_label {
  my ($self, $gene, $transcript) = @_;

  my $obj = $transcript || $gene || return '';

  my $tid = $obj->stable_id();
  my $eid = $obj->external_name();
  my $id = $eid || $tid;

  my $Config = $self->{config};
  my $short_labels = $Config->get_parameter( 'opt_shortlabels');

  if( $Config->{'_both_names_'} eq 'yes') {
    $id .= $eid ? " ($eid)" : '';
  }
  if( ! $Config->get_parameter( 'opt_shortlabels') ){
    my $type = ( $gene->analysis ? 
                 $gene->analysis->logic_name : 
                 'Generic trans.' );
    $id .= "\n$type";
  }
  return $id;
}

sub gene_text_label {
  my ($self, $gene ) = @_;
  return $self->text_label($gene);
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

1;
