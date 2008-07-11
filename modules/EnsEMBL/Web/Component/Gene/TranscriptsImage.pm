package EnsEMBL::Web::Component::Gene::TranscriptsImage;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);

sub _init { 
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub caption {
  my $html = 'Transcripts';
  return $html;
}

sub content {
  my $self = shift;
  my $gene = $self->object;

  my @trans = sort { $a->stable_id cmp $b->stable_id } @{$gene->get_all_transcripts()};
  my $gene_slice = $gene->Obj->feature_Slice->expand( 10e3, 10e3 );
     $gene_slice = $gene_slice->invert if $gene->seq_region_strand < 0;
    ## Get the web_user_config
  my $wuc        = $gene->user_config_hash( 'altsplice' );
    ## We now need to select the correct track to turn on....
    ## We need to do the turn on turn off for the checkboxes here!!
  foreach( $trans[0]->default_track_by_gene ) {
    $wuc->set( $_,'on','on');
  }
  # $wuc->{'_no_label'}   = 'true';
  $wuc->{'_add_labels'} = 'true';
  $wuc->set( '_settings', 'width',  $gene->param('image_width') );
  $wuc->{'slice_number'} = '1|1';

  my  $image  = $gene->new_image( $gene_slice, $wuc, [$gene->Obj->stable_id] );
      $image->imagemap           = 'yes';
      $image->set_extra( $gene );
      $image->{'panel_number'} = 'top';
      $image->set_button( 'drag', 'title' => 'Drag to select region' );


  return $image->render;
}

1;
