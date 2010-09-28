# $Id$

package EnsEMBL::Web::Document::Element::BodyJavascript;

use strict;

use base qw(EnsEMBL::Web::Document::Element);

sub new {
  return shift->SUPER::new({
    %{$_[0]},
    scripts => '',
    sources => {},
    debug   => 0
  });
}

sub debug {
  my $self = shift;
  $self->{'debug'} = shift if @_;
  return $self->{'debug'};
}

sub add_source { 
  my ($self, $src) = @_;
  
  return unless $src;
  return if $self->{'sources'}->{$src};
  
  $self->{'sources'}->{$src} = 1;
  $self->{'scripts'} .= qq{  <script type="text/javascript" src="$src"></script>\n};
}

sub add_script {
  return unless $_[1];
  $_[0]->{'scripts'} .= qq{  <script type="text/javascript">\n$_[1]</script>\n};
}

sub content {
  my $self    = shift;
  my $content = qq{
    $self->{'scripts'}
    <div id="uploadframe_div" style="display: none"><iframe name="uploadframe"></iframe></div>
  };
  
  $content .= '<div id="debug"></div>' if $self->debug;
  
  return $content;
} 

sub init {
  my $self         = shift;
  my $controller   = shift;
  my $species_defs = $self->species_defs;
  
  if ($controller->input->param('debug') eq 'js') {
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


