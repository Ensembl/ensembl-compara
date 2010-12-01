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
  my $self        = shift;
  my $path        = $ENV{'SCRIPT_NAME'};
  my @breadcrumbs = $path eq '/index.html' ? () : '<a class="home" href="/">Home</a>';

  if ($path =~ /^\/info\//) {
    # Level 2 link
    if ($path eq '/info/' || $path eq '/info/index.html') {
      push @breadcrumbs, 'Docs &amp; FAQs';
    } else {
      push @breadcrumbs, '<a href="/info/">Docs &amp; FAQs</a>';
      push @breadcrumbs, $self->title if $self->title;
    }
    
    return unless @breadcrumbs;
    
    my $last = pop @breadcrumbs;
    
    return sprintf qq{<ul class="breadcrumbs print_hide">%s<li class="last">$last</li></ul>}, join '', map "<li>$_</li>", @breadcrumbs;
  }
}

sub init {
  my ($self, $controller) = @_;
  $self->title($controller->content =~ /<title>(.*?)<\/title>/sm ? $1 : 'Untitled: ' . $controller->r->uri) if $controller->request eq 'ssi';
}

1;
