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
  my $wuc = $transcript->get_userconfig( 'geneview' );
     $wuc->set_parameters({
       'container_width'   => $transcript_slice->length,
       'image_width',      => $self->image_width || 800,
       'slice_number',     => '1|1',
     });

## Now we need to turn on the transcript we wish to draw...

     my $logic_name = $transcript->analysis->logic_name;
     my $db         = $transcript->get_db();
     my $db_key     = $db eq 'core' ? 'ENSEMBL_DB' : 'ENSEMBL_'.uc($db);
     my $key        = $transcript->species_defs->databases->{$db_key}{'tables'}{'gene'}{'analyses'}{$logic_name}{'web'}{'key'} || $logic_name;
     my $track_to_turn_on = 'transcript_'.$db.'_'.$key;

     $wuc->{'_no_label'} = 'true';

     $wuc->get_node( $track_to_turn_on )->set('on','on'); 
     $wuc->get_node( 'ruler' )->set( 'strand', $transcript->Obj->strand > 0 ? 'f' : 'r' );
     $wuc->set_parameter( 'single_Transcript' => $transcript->Obj->stable_id );

     $wuc->tree->dump("Tree", '[[caption]]' );

  my $image    = $transcript->new_image( $transcript_slice, $wuc, [] );
     $image->imagemap = 'yes';
     $image->{'panel_number'} = 'transcript';
     $image->set_button( 'drag', 'title' => 'Drag to select region' );

  return $image->render;
}

1;

