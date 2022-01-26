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

package EnsEMBL::Web::ZMenu::AlignDiff;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  my $hub = $self->hub;
  #my $pos = $hub->param('pos');
  my ($caption,$desc,@note);
  my $num = $hub->param('num');
  my $len = $hub->param('len');  
  my $span = $hub->param('span');
  my $type = $hub->param('ctype');
  if($num>1) {
    $caption = sprintf("%dbp %sed over %dbp in %d fragments",$len,$type,$span,$num);
    $caption =~ s/deleteed/deleted/g;
    $desc = sprintf("Cluster of nearby %ss (x%d) totalling %dbp within %dbp of sequence: zoom to resolve.",$type,$num,$len,$span);
  } else {
    $caption = sprintf("Single %dbp %s",$len,$type);
    $desc = sprintf("Single %s of %dbp",$type,$len);
  }
  my $col = { 'insert' => 'Green', 'delete' => 'Red' }->{$type};
  if($hub->param('rel') or $hub->param('lel')) {
    push @note,"$col bar is <em>smaller</em> than true $type length due to edge of image";
  } elsif($hub->param('midel')) {
    push @note,"$col bar is <em>smaller</em> than true $type length due to image scale";
  } elsif($hub->param('plumped')) {
    push @note,"$col bar is <em>larger</em> than true $type length due to image scale";
  } else {
    push @note,"$col bar is approximately true length of $type";
  }
  $self->caption($caption);
  $self->add_entry({
    type  => 'Ref. Range',
    label => $hub->param('zoom'),
    order => 1,
  });
  warn ">>> ZOOMING HERE with action ".$self->hub->action;
  $self->add_entry({
    type  => 'Zoom',
    label => "zoom here",
    link => $self->hub->url({
      r => $hub->param('zoom_r'),
      action => $hub->param('parent_action'),
    }),
    order => 2,
  });
  $self->add_entry({
    type  => 'Description',
    label_html => $desc,
    order => 3,
  });
  if(@note) {
    $self->add_entry({
      type  => 'Note',
      label_html => join(". ",@note).".",
      order => 4,
    });
  }
  $self->add_entry({
    type  => 'CIGAR fragment',
    label_html => $hub->param('cigar'),
    order => 5,
  });
}

1;
