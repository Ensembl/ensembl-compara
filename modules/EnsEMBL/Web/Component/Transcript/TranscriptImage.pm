package EnsEMBL::Web::Component::Transcript::TranscriptImage;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);
use CGI qw(escapeHTML);
our @ISA = qw( EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}


sub content {
  my $self = shift;
  my $transcript = $self->object;
  my $transcript_slice = $transcript->Obj->feature_Slice;
     $transcript_slice = $transcript_slice->invert if $transcript_slice->strand < 1; ## Put back onto correct strand!
  my $wuc = $transcript->get_imageconfig( 'single_transcript' );
     $wuc->set_parameters({
       'container_width'   => $transcript_slice->length,
       'image_width',      => $self->image_width || 800,
       'slice_number',     => '1|1',
     });

## Now we need to turn on the transcript we wish to draw...


  $wuc->modify_configs( ## Turn on track associated with this db/logic name
    [$wuc->get_track_key( 'transcript', $transcript )],
    {qw(display on show_labels off)}  ## also turn off the transcript labels...
  );

  $wuc->modify_configs( ## Show the ruler only on the same strand as the transcript...
    ['ruler'],
    { 'strand', $transcript->Obj->strand > 0 ? 'f' : 'r' }
  );

  $wuc->set_parameter( 'single_Transcript' => $transcript->Obj->stable_id );
  $wuc->set_parameter( 'single_Gene'       => $transcript->gene->stable_id ) if $transcript->gene;

  $wuc->tree->dump("Tree", '[[caption]]' );

  my $image    = $transcript->new_image( $transcript_slice, $wuc, [] );
     $image->imagemap = 'yes';
     $image->{'panel_number'} = 'transcript';
     $image->set_button( 'drag', 'title' => 'Drag to select region' );

  return $image->render;
}

1;

