package Bio::EnsEMBL::GlyphSet::_repeat;

use strict;
use base qw( Bio::EnsEMBL::GlyphSet_simple );

sub features {
  my $self = shift;
## Need to add code to restrict by logic_name and by db!

  my $types      = $self->my_config( 'types'      );
  my $logicnames = $self->my_config( 'logicnames' );

  my @repeats = sort { $a->seq_region_start <=> $b->seq_region_end }
                 map { my $t = $_; map { @{ $self->{'container'}->get_all_RepeatFeatures( $t, $_ ) } } @$types }
                @$logicnames;
  
  return \@repeats;
}

sub colour_key {
  my( $self, $f ) = @_;
  return 'repeat';
}

sub image_label {
  my( $self, $f ) = @_;
  return '', 'invisible';
}

sub title {
  my( $self, $f ) = @_;
  my($start,$end) = $self->slice2sr( $f->start(), $f->end() );
  my $len   = $end - $start + 1;
  return sprintf "%s; bp: %s; length: %s",
    $f->repeat_consensus()->name(),
    "$start-$end",
    $len;
}

sub tag {
  return;
}

sub export_feature {
  my $self = shift;
  my ($feature) = @_;
  
  my $id = "repeat:$feature->{'dbID'}";
  
  return if $self->{'export_cache'}->{$id};
  $self->{'export_cache'}->{$id} = 1;
  
  return $self->_render_text($feature, 'Repeat', undef, { 'source' => $feature->display_id });
}

1 ;
