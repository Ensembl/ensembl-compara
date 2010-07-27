package EnsEMBL::Web::Document::HTML::BreadCrumbs;

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

# Package to generate breadcrumb links (currently incorporated into masthead)
# Limited to three levels in order to keep masthead neat :)

sub new {
  my $class = shift;
  my $self  = $class->SUPER::new('title' => undef );
  return $self;
}

sub title {
  my $self = shift;
  $self->{'title'} = shift if @_;
  return $self->{'title'};
}

sub render {
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
  
  $self->print(qq{<div class="breadcrumbs print_hide">$html</div>});
}

1;

