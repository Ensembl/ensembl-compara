# $Id$

package EnsEMBL::Web::Document::Element::BodyJavascript;

use strict;

use base qw(EnsEMBL::Web::Document::Element);

sub new {
  my $self = shift->SUPER::new({
    %{$_[0]},
    scripts => '',
    sources => {},
  });
  
  $self->debug = $self->hub->param('debug') eq 'js';
  
  return $self;
}

sub debug :lvalue { $_[0]{'debug'}; }

sub add_source { 
  my ($self, $src) = @_;
  
  return unless $src;
  return if $self->{'sources'}->{$src};
  
  $self->{'sources'}->{$src} = 1;
  $self->{'scripts'} .= sprintf qq{  <script type="text/javascript" src="%s%s"></script>\n}, $self->static_server, $src;
}

sub add_script {
  return unless $_[1];
  $_[0]->{'scripts'} .= qq{  <script type="text/javascript">\n$_[1]</script>\n};
}

sub content {
  my $self = shift;
  
  return qq{
    $self->{'scripts'}
    <div id="uploadframe_div" style="display: none"><iframe name="uploadframe"></iframe></div>
  };
} 

sub init {
  my $self         = shift;
  my $species_defs = $self->species_defs;
  
  if ($self->debug) {
    foreach my $root (reverse @{$species_defs->ENSEMBL_HTDOCS_DIRS}) {
      my $dir = "$root/components";

      if (-e $dir && -d $dir) {
        opendir DH, $dir;
        my @files = readdir DH;
        closedir DH;

        $self->add_source("/components/$_") for sort grep { /^\d/ && -f "$dir/$_" && /\.js$/ } @files;
      }
    }
  } else {
    $self->add_source(sprintf '/%s/%s.js', $species_defs->ENSEMBL_JSCSS_TYPE, $species_defs->ENSEMBL_JS_NAME);
  }
}

1;


