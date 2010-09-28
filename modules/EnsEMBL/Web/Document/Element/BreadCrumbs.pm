# $Id$

package EnsEMBL::Web::Document::Element::BreadCrumbs;

use strict;

use base qw(EnsEMBL::Web::Document::Element);

# Package to generate breadcrumb links (currently incorporated into masthead)
# Limited to three levels in order to keep masthead neat :)

sub title {
  my $self = shift;
  $self->{'title'} = shift if @_;
  return $self->{'title'};
}

sub content {
  my $self = shift;
  my $path = $ENV{'SCRIPT_NAME'};
  my $html = $path eq '/index.html' ? 'Home' : '<a href="/">Home</a>';

  if ($path =~ /^\/info\//) {
    $html .= ' &gt; ';
    
    # Level 2 link
    if ($path eq '/info/' || $path eq '/info/index.html') {
      $html .= 'Docs &amp; FAQs';
    } else {
      $html .= '<a href="/info/">Docs &amp; FAQs</a>';
    }
    
    $html .= ' &gt; ' . $self->title if $self->title;
  }
  
  return qq{<div class="breadcrumbs print_hide">$html</div>};
}

sub init {
  my ($self, $controller) = @_;
  $self->title($controller->content =~ /<title>(.*?)<\/title>/sm ? $1 : 'Untitled: ' . $controller->r->uri) if $controller->request eq 'ssi';
}

1;
