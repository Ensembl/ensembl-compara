# $Id$

package EnsEMBL::Web::Command::UserData::FviewRedirect;

### Redirects from the 'FeatureView' form to Location/Genome

use strict;
use warnings;

use URI::Escape qw(uri_escape);

use EnsEMBL::Web::Builder;

use base qw(EnsEMBL::Web::Command::UserData);

sub process {
  my $self      = shift;
  my $hub       = $self->hub;
  my $site_type = $hub->species_defs->ENSEMBL_SITETYPE;
  my $ftype     = $hub->param('ftype');
  my $builder   = EnsEMBL::Web::Builder->new({ hub => $hub });
  my $object    = $builder->create_objects('Feature', 'lazy');
  my $features  = $object && $object->can('convert_to_drawing_parameters') ? $object->convert_to_drawing_parameters : {};
  my $desc      = $hub->param('name') || "Selected ${ftype}s";
  my $content   = sprintf qq{track name=%s description="%s" useScore=1 color=%s style=%s\n}, $ftype, $desc, $hub->param('colour'), $hub->param('style');
  
  ## Write out features as GFF file
  while (my ($type, $feat) = each %$features) {
    foreach my $f (@{$feat->[0] || []}) {
      my $strand = $f->{'strand'} == 1 ? '+' : '-';
      my @attribs;
      
      if ($ftype eq 'Gene') {
        @attribs = (
          'ID='          . $f->{'gene_id'}[0],
          'extname='     . $f->{'extname'}, 
          'description=' . uri_escape($f->{'extra'}{'description'})
        );
      }  else {
        @attribs = (
          'length='  . $f->{'length'},
          'label='   . uri_escape($f->{'label'}),
          'align='   . $f->{'extra'}{'align'},
          'ori='     . $f->{'extra'}{'ori'},
          'id='      . $f->{'extra'}{'id'},
          'score='   . $f->{'extra'}{'score'},
          'p-value=' . $f->{'extra'}{'p-value'},
        );
      }
      
      $content .= join "\t", $f->{'region'}, $site_type, $ftype, $f->{'start'}, $f->{'end'}, '.', $strand, '.', join('; ', @attribs);
      $content .= "\n";
    }
  }
  
  $hub->param('text',   $content);
  $hub->param('format', 'GFF');
  $hub->param('name',   $desc);
  
  my $upload = $self->upload('text'); ## Upload munged data
  my $url    = $hub->url({ species => $hub->param('species'), type => 'Location', action => 'Genome', function => undef, __clear => 1 });
  my $params = { Vkaryotype => "upload_$upload->{'code'}=on" };
  
  $self->ajax_redirect($url, $params, undef, 'page'); 
}

1;
