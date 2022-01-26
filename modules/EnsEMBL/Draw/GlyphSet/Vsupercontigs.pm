=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::Vsupercontigs;

### Draws supercontig track on single chromosome - no longer used?

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

sub _init {

  my ($self)      = @_;
  my $Config      = $self->{'config'};
  my $chr         = $self->{'extras'}->{'chr'} || $self->{'container'}->{'chr'};

  my $chr_slice   = $self->{'container'}->{'sa'}->fetch_by_region('chromosome', $chr); 
  my $ctgs        = $chr_slice->get_all_MiscFeatures('superctgs' );
  my ($w,$h)      = $Config->texthelper->Vpx2bp('Tiny');
  
  my $chr_length  = $chr_slice->length || 1;
  my $max_len     = $Config->container_width(); 

  my $v_offset    = $Config->container_width() - $chr_length;
  my $bpperpx     = $Config->container_width()/$self->get_parameter('image_height');

  my $padding     = $self->my_config('padding') || 6;
  my $wid         = $self->my_config('width');
  my $h_wid       = int($wid/2);
  
  my $style       = $self->my_config('style'); 

  my $h_offset;

  # get text labels in correct place!
  if ($style eq 'text') {
      $h_offset = $padding;
  }
  else {
      # max width of band label is 6 characters
      $h_offset    = int($self->my_config('totalwidth')
       - $wid
       - ($self->{'config'}->{'_ctg_labels'} eq 'on' ? ($w * 6 + 4) : 0 )
       )/2; 
  }
  my @decorations;
  
  if($padding) {
      # make sure that there is a blank image behind the chromosome so that the
      # glyphset doesn't get "horizontally" squashed.
      
      my $gpadding = $self->Space({
    'x'         => 0,
    'y'         => $h_offset - $padding,
    'width'     => 10000,
    'height'    => $padding * 2 + $wid,
    'absolutey' => 1,
      });
      $self->push($gpadding);
  }
  
  
  my @ctgs =  sort{$a->seq_region_start <=> $b->seq_region_start } @$ctgs;


  my $include_labelling = $self->my_config('include_labelling');
  if( @ctgs ) {
    foreach my $ctg(@ctgs){
    
      my $ctgname       = $ctg->get_scalar_attribute('name');
      my $vc_ctg_start  = $ctg->seq_region_start() + $v_offset;
      my $vc_ctg_end    = $ctg->seq_region_end()   + $v_offset;
      
      my $c = $ctg->slice->seq_region_name; 
      my $region = "$c:$vc_ctg_start-$vc_ctg_end";
      my $href = $self->_url ({'type' => 'Location', 'action' => 'Supercontig', 'r' => $region, 'ctg' => $ctgname });
      ##$HREF =  "/@{[$self->{container}{web_species}]}/cytoview?chr=$chr;vc_start=$vc_ctg_start;vc_end=$vc_ctg_end"
    
      $self->{'_colour_flag'} = $self->{'_colour_flag'}==1 ? 2 : 1;
     
     
      my $ctg_col  = $self->my_colour("col_ctgs$self->{'_colour_flag'}");
    
      my $g_x = $self->Rect({
        'x'         => $vc_ctg_start,
        'y'         => $h_offset+ int($wid/4),
        'width'     => $vc_ctg_end - $vc_ctg_start,
        'height'    => $h_wid,
        'colour'    => $ctg_col,
        'absolutey' => 1,
        'href'     => $href
      });
      push @decorations, $g_x;
    
      next unless $include_labelling; 
#warn "ADDING LABEL";
    
      ## label
      my $labely;
      $labely = $h_offset+$wid+4;
  #    if( $self->{'_colour_flag'}==1 ) {
  #      $labely = $h_offset+$wid+4;
  #    } else { 
  #     # $labely = ($h_offset) -  ($w * length($ctgname));
  #    }
   
      my $tglyph = $self->Text({
        'x'                => ($vc_ctg_end + $vc_ctg_start - $h)/2,
        'y'                => $labely,
        'width'            => $h,
        'height'           => $w * length($ctgname),
        'font'             => 'Tiny',
        'colour'           => $ctg_col,
        'text'             => $ctgname,
        'absolutey'        => 1,
        ##'href'             => $HREF
      });
      $self->push($tglyph);
    }
      
  }
  
  foreach( @decorations ) {  $self->push($_); }
  
  return();

}



1;
